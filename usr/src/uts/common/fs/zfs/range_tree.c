/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */
/*
 * Copyright (c) 2013, 2014 by Delphix. All rights reserved.
 */

#include <sys/zfs_context.h>
#include <sys/spa.h>
#include <sys/dmu.h>
#include <sys/dnode.h>
#include <sys/zio.h>
#include <sys/range_tree.h>

/*
 * Range trees are tree-based data structures that can be used to
 * track free space or generally any space allocation information.
 * A range tree keeps track of individual segments and automatically
 * provides facilities such as adjacent extent merging and extent
 * splitting in response to range add/remove requests.
 *
 * A range tree starts out completely empty, with no segments in it.
 * Adding an allocation via range_tree_add to the range tree can either:
 * 1) create a new extent
 * 2) extend an adjacent extent
 * 3) merge two adjacent extents
 * Conversely, removing an allocation via range_tree_add can:
 * 1) completely remove an extent
 * 2) shorten an extent (if the allocation was near one of its ends)
 * 3) split an extent into two extents, in effect punching a hole
 *
 * A range tree is also capable of 'bridging' gaps when adding
 * allocations. This is useful for cases when close proximity of
 * allocations is an important detail that needs to be represented
 * in the range tree. See range_tree_set_gap(). The default behavior
 * is not to bridge gaps (i.e. the maximum allowed gap size is 0).
 *
 * In order to traverse a range tree, use either the range_tree_walk
 * or range_tree_vacate functions.
 *
 * To obtain more accurate information on individual segment
 * operations that the range tree performs "under the hood", you can
 * specify a set of callbacks by passing a range_tree_ops_t structure
 * to the range_tree_create and range_tree_create_custom functions.
 * Any callbacks that are non-NULL are then called at the appropriate
 * times.
 *
 * It is possible to store additional custom information with each
 * segment. This is typically useful when using one or more of the
 * operation callbacks mentioned above. To do so, use the
 * range_tree_create_custom function to create your range tree and
 * pass a custom kmem cache allocator. This allocator must allocate
 * objects of at least sizeof (range_seg_t). The range tree will use
 * the start of that object as a range_seg_t to keep its internal
 * data structures and you can use the remainder of the object to
 * store arbitrary additional fields as necessary.
 */

kmem_cache_t *range_seg_cache;

void
range_tree_init(void)
{
	ASSERT(range_seg_cache == NULL);
	range_seg_cache = kmem_cache_create("range_seg_cache",
	    sizeof (range_seg_t), 0, NULL, NULL, NULL, NULL, NULL, 0);
}

void
range_tree_fini(void)
{
	kmem_cache_destroy(range_seg_cache);
	range_seg_cache = NULL;
}

void
range_tree_stat_verify(range_tree_t *rt)
{
	range_seg_t *rs;
	uint64_t hist[RANGE_TREE_HISTOGRAM_SIZE] = { 0 };
	int i;

	for (rs = avl_first(&rt->rt_root); rs != NULL;
	    rs = AVL_NEXT(&rt->rt_root, rs)) {
		uint64_t size = rs->rs_end - rs->rs_start;
		int idx	= highbit64(size) - 1;

		hist[idx]++;
		ASSERT3U(hist[idx], !=, 0);
	}

	for (i = 0; i < RANGE_TREE_HISTOGRAM_SIZE; i++) {
		if (hist[i] != rt->rt_histogram[i]) {
			zfs_dbgmsg("i=%d, hist=%p, hist=%llu, rt_hist=%llu",
			    i, hist, hist[i], rt->rt_histogram[i]);
		}
		VERIFY3U(hist[i], ==, rt->rt_histogram[i]);
	}
}

/*
 * Sets the inter-segment gap. Subsequent adding of segments will examine
 * if an adjacent segment is less than or equal to `gap' apart. If it is,
 * the segments will be joined together, in effect 'bridging' the gap.
 */
void
range_tree_set_gap(range_tree_t *rt, uint64_t gap)
{
	ASSERT(MUTEX_HELD(rt->rt_lock));
	rt->rt_gap = gap;
}

static void
range_tree_stat_incr(range_tree_t *rt, range_seg_t *rs)
{
	uint64_t size = rs->rs_end - rs->rs_start;
	int idx = highbit64(size) - 1;

	ASSERT(size != 0);
	ASSERT3U(idx, <,
	    sizeof (rt->rt_histogram) / sizeof (*rt->rt_histogram));

	ASSERT(MUTEX_HELD(rt->rt_lock));
	rt->rt_histogram[idx]++;
	ASSERT3U(rt->rt_histogram[idx], !=, 0);
}

static void
range_tree_stat_decr(range_tree_t *rt, range_seg_t *rs)
{
	uint64_t size = rs->rs_end - rs->rs_start;
	int idx = highbit64(size) - 1;

	ASSERT(size != 0);
	ASSERT3U(idx, <,
	    sizeof (rt->rt_histogram) / sizeof (*rt->rt_histogram));

	ASSERT(MUTEX_HELD(rt->rt_lock));
	ASSERT3U(rt->rt_histogram[idx], !=, 0);
	rt->rt_histogram[idx]--;
}

/*
 * NOTE: caller is responsible for all locking.
 */
static int
range_tree_seg_compare(const void *x1, const void *x2)
{
	const range_seg_t *r1 = x1;
	const range_seg_t *r2 = x2;

	if (r1->rs_start < r2->rs_start) {
		if (r1->rs_end > r2->rs_start)
			return (0);
		return (-1);
	}
	if (r1->rs_start > r2->rs_start) {
		if (r1->rs_start < r2->rs_end)
			return (0);
		return (1);
	}
	return (0);
}

range_tree_t *
range_tree_create(range_tree_ops_t *ops, void *arg, kmutex_t *lp)
{
	return (range_tree_create_custom(ops, arg, lp, range_seg_cache));
}

/*
 * Same as range_tree_create, but allows you to pass a custom range tree
 * segment allocator. The purpose of this is that you can put additional
 * fields into the structure following a first range_seg_t field (which
 * will be used by the range tree itself), allowing you to store arbitrary
 * additional information with each range tree segment.
 */
range_tree_t *
range_tree_create_custom(range_tree_ops_t *ops, void *arg, kmutex_t *lp,
    kmem_cache_t *seg_cache)
{
	range_tree_t *rt;

	ASSERT3U(kmem_cache_bufsize(seg_cache), >=, sizeof (range_seg_t));

	rt = kmem_zalloc(sizeof (range_tree_t), KM_SLEEP);

	avl_create(&rt->rt_root, range_tree_seg_compare,
	    sizeof (range_seg_t), offsetof(range_seg_t, rs_node));

	rt->rt_lock = lp;
	rt->rt_ops = ops;
	rt->rt_arg = arg;
	rt->rt_seg_cache = seg_cache;

	if (rt->rt_ops != NULL && rt->rt_ops->rtop_create != NULL)
		rt->rt_ops->rtop_create(rt, rt->rt_arg);

	return (rt);
}

void
range_tree_destroy(range_tree_t *rt)
{
	VERIFY0(rt->rt_space);

	if (rt->rt_ops != NULL && rt->rt_ops->rtop_destroy != NULL)
		rt->rt_ops->rtop_destroy(rt, rt->rt_arg);

	avl_destroy(&rt->rt_root);
	kmem_free(rt, sizeof (*rt));
}

void
range_tree_add(void *arg, uint64_t start, uint64_t size)
{
	range_tree_t *rt = arg;
	avl_index_t where;
	range_seg_t rsearch, *rs_before, *rs_after, *rs;
	uint64_t end = start + size, gap_extra = 0;
	boolean_t merge_before, merge_after;

	ASSERT(MUTEX_HELD(rt->rt_lock));
	VERIFY(size != 0);

	rsearch.rs_start = start;
	rsearch.rs_end = end;
	rs = avl_find(&rt->rt_root, &rsearch, &where);

	if (rs != NULL && rs->rs_start <= start && rs->rs_end >= end &&
	    rt->rt_gap == 0) {
		zfs_panic_recover("zfs: allocating allocated segment"
		    "(offset=%llu size=%llu)\n",
		    (longlong_t)start, (longlong_t)size);
		return;
	}

	if (rt->rt_gap != 0) {
		if (rs != NULL) {
			if (rs->rs_start <= start && rs->rs_end >= end) {
				if (rt->rt_ops != NULL &&
				    rt->rt_ops->rtop_add != NULL) {
					rt->rt_ops->rtop_add(rt, rs,
					    rt->rt_arg);
				}
				return;
			}
			if (rs->rs_start < start)
				range_tree_add(rt, rs->rs_end, end);
			else
				range_tree_add(rt, start, rs->rs_start);
			return;
		}
	} else {
		/* Make sure we don't overlap with either of our neighbors */
		VERIFY(rs == NULL);
	}

	rs_before = avl_nearest(&rt->rt_root, where, AVL_BEFORE);
	rs_after = avl_nearest(&rt->rt_root, where, AVL_AFTER);

	merge_before = (rs_before != NULL &&
	    start - rs_before->rs_end <= rt->rt_gap);
	merge_after = (rs_after != NULL &&
	    rs_after->rs_start - end <= rt->rt_gap);
	if (rt->rt_gap != 0) {
		if (merge_before)
			gap_extra += start - rs_before->rs_end;
		if (merge_after)
			gap_extra += rs_after->rs_start - end;
	}

	if (merge_before && merge_after) {
		avl_remove(&rt->rt_root, rs_before);
		if (rt->rt_ops != NULL && rt->rt_ops->rtop_remove != NULL) {
			rt->rt_ops->rtop_remove(rt, rs_before, rt->rt_arg);
			rt->rt_ops->rtop_remove(rt, rs_after, rt->rt_arg);
		}

		range_tree_stat_decr(rt, rs_before);
		range_tree_stat_decr(rt, rs_after);

		rs_after->rs_start = rs_before->rs_start;
		kmem_cache_free(rt->rt_seg_cache, rs_before);
		rs = rs_after;
	} else if (merge_before) {
		if (rt->rt_ops != NULL && rt->rt_ops->rtop_remove != NULL)
			rt->rt_ops->rtop_remove(rt, rs_before, rt->rt_arg);

		range_tree_stat_decr(rt, rs_before);

		rs_before->rs_end = end;
		rs = rs_before;
	} else if (merge_after) {
		if (rt->rt_ops != NULL && rt->rt_ops->rtop_remove != NULL)
			rt->rt_ops->rtop_remove(rt, rs_after, rt->rt_arg);

		range_tree_stat_decr(rt, rs_after);

		rs_after->rs_start = start;
		rs = rs_after;
	} else {
		rs = kmem_cache_alloc(rt->rt_seg_cache, KM_SLEEP);
		bzero(rs, kmem_cache_bufsize(rt->rt_seg_cache));
		rs->rs_start = start;
		rs->rs_end = end;
		avl_insert(&rt->rt_root, rs, where);
	}

	if (rt->rt_ops != NULL && rt->rt_ops->rtop_add != NULL)
		rt->rt_ops->rtop_add(rt, rs, rt->rt_arg);

	range_tree_stat_incr(rt, rs);
	rt->rt_space += size + gap_extra;
}

static void
range_tree_remove_impl(void *arg, uint64_t start, uint64_t size,
    boolean_t partial_overlap)
{
	range_tree_t *rt = arg;
	avl_index_t where;
	range_seg_t rsearch, *rs, *newseg;
	uint64_t end = start + size;
	boolean_t left_over, right_over;

	ASSERT(MUTEX_HELD(rt->rt_lock));
	VERIFY3U(size, !=, 0);
	if (!partial_overlap) {
		VERIFY3U(size, <=, rt->rt_space);
	}

	rsearch.rs_start = start;
	rsearch.rs_end = end;

	while ((rs = avl_find(&rt->rt_root, &rsearch, &where)) != NULL ||
	    !partial_overlap) {
		uint64_t overlap_sz;

		if (partial_overlap) {
			if (rs->rs_start <= start && rs->rs_end >= end)
				overlap_sz = size;
			else if (rs->rs_start > start && rs->rs_end < end)
				overlap_sz = rs->rs_end - rs->rs_start;
			else if (rs->rs_end < end)
				overlap_sz = rs->rs_end - start;
			else	/* rs->rs_start > start */
				overlap_sz = end - rs->rs_start;
		} else {
			/* Make sure we completely overlapped with someone */
			if (rs == NULL) {
				zfs_panic_recover("zfs: freeing free segment "
				    "(offset=%llu size=%llu)",
				    (longlong_t)start, (longlong_t)size);
				return;
			}
			VERIFY3U(rs->rs_start, <=, start);
			VERIFY3U(rs->rs_end, >=, end);
			overlap_sz = size;
		}

		left_over = (rs->rs_start < start);
		right_over = (rs->rs_end > end);

		range_tree_stat_decr(rt, rs);

		if (rt->rt_ops != NULL && rt->rt_ops->rtop_remove != NULL)
			rt->rt_ops->rtop_remove(rt, rs, rt->rt_arg);

		if (left_over && right_over) {
			newseg = kmem_cache_alloc(rt->rt_seg_cache, KM_SLEEP);
			bzero(newseg, kmem_cache_bufsize(rt->rt_seg_cache));
			newseg->rs_start = end;
			newseg->rs_end = rs->rs_end;
			range_tree_stat_incr(rt, newseg);

			rs->rs_end = start;

			avl_insert_here(&rt->rt_root, newseg, rs, AVL_AFTER);
			if (rt->rt_ops != NULL && rt->rt_ops->rtop_add != NULL)
				rt->rt_ops->rtop_add(rt, newseg, rt->rt_arg);
		} else if (left_over) {
			rs->rs_end = start;
		} else if (right_over) {
			rs->rs_start = end;
		} else {
			avl_remove(&rt->rt_root, rs);
			kmem_cache_free(rt->rt_seg_cache, rs);
			rs = NULL;
		}

		if (rs != NULL) {
			range_tree_stat_incr(rt, rs);

			if (rt->rt_ops != NULL && rt->rt_ops->rtop_add != NULL)
				rt->rt_ops->rtop_add(rt, rs, rt->rt_arg);
		}

		rt->rt_space -= overlap_sz;
		if (!partial_overlap) {
			/*
			 * There can't be any more segments overlapping with
			 * us, so no sense in performing an extra search.
			 */
			break;
		}
	}
}

void
range_tree_remove(void *arg, uint64_t start, uint64_t size)
{
	range_tree_remove_impl(arg, start, size, B_FALSE);
}

void
range_tree_remove_overlap(void *arg, uint64_t start, uint64_t size)
{
	range_tree_remove_impl(arg, start, size, B_TRUE);
}

static range_seg_t *
range_tree_find_impl(range_tree_t *rt, uint64_t start, uint64_t size)
{
	avl_index_t where;
	range_seg_t rsearch;
	uint64_t end = start + size;

	ASSERT(MUTEX_HELD(rt->rt_lock));
	VERIFY(size != 0);

	rsearch.rs_start = start;
	rsearch.rs_end = end;
	return (avl_find(&rt->rt_root, &rsearch, &where));
}

void *
range_tree_find(range_tree_t *rt, uint64_t start, uint64_t size)
{
	range_seg_t *rs = range_tree_find_impl(rt, start, size);
	if (rs != NULL && rs->rs_start <= start && rs->rs_end >= start + size)
		return (rs);
	return (NULL);
}

/*
 * Given an extent start offset and size, will look through the provided
 * range tree and find a suitable start offset (starting at `start') such
 * that the requested extent _doesn't_ overlap with any range segment in
 * the range tree.
 */
uint64_t
range_tree_find_gap(range_tree_t *rt, uint64_t start, uint64_t size)
{
	range_seg_t *rs;
	while ((rs = range_tree_find_impl(rt, start, size)) != NULL)
		start = rs->rs_end;
	return (start);
}

void
range_tree_verify(range_tree_t *rt, uint64_t off, uint64_t size)
{
	range_seg_t *rs;

	mutex_enter(rt->rt_lock);
	rs = range_tree_find(rt, off, size);
	if (rs != NULL)
		panic("freeing free block; rs=%p", (void *)rs);
	mutex_exit(rt->rt_lock);
}

boolean_t
range_tree_contains(range_tree_t *rt, uint64_t start, uint64_t size)
{
	return (range_tree_find(rt, start, size) != NULL);
}

/*
 * Ensure that this range is not in the tree, regardless of whether
 * it is currently in the tree.
 */
void
range_tree_clear(range_tree_t *rt, uint64_t start, uint64_t size)
{
	range_seg_t *rs;

	while ((rs = range_tree_find_impl(rt, start, size)) != NULL) {
		uint64_t free_start = MAX(rs->rs_start, start);
		uint64_t free_end = MIN(rs->rs_end, start + size);
		range_tree_remove(rt, free_start, free_end - free_start);
	}
}

void
range_tree_swap(range_tree_t **rtsrc, range_tree_t **rtdst)
{
	range_tree_t *rt;

	ASSERT(MUTEX_HELD((*rtsrc)->rt_lock));
	ASSERT0(range_tree_space(*rtdst));
	ASSERT0(avl_numnodes(&(*rtdst)->rt_root));

	rt = *rtsrc;
	*rtsrc = *rtdst;
	*rtdst = rt;
}

void
range_tree_vacate(range_tree_t *rt, range_tree_func_t *func, void *arg)
{
	range_seg_t *rs;
	void *cookie = NULL;

	ASSERT(MUTEX_HELD(rt->rt_lock));

	if (rt->rt_ops != NULL && rt->rt_ops->rtop_vacate != NULL)
		rt->rt_ops->rtop_vacate(rt, rt->rt_arg);

	while ((rs = avl_destroy_nodes(&rt->rt_root, &cookie)) != NULL) {
		if (func != NULL)
			func(arg, rs->rs_start, rs->rs_end - rs->rs_start);
		kmem_cache_free(rt->rt_seg_cache, rs);
	}

	bzero(rt->rt_histogram, sizeof (rt->rt_histogram));
	rt->rt_space = 0;
}

void
range_tree_walk(range_tree_t *rt, range_tree_func_t *func, void *arg)
{
	range_seg_t *rs;

	ASSERT(MUTEX_HELD(rt->rt_lock));

	for (rs = avl_first(&rt->rt_root); rs; rs = AVL_NEXT(&rt->rt_root, rs))
		func(arg, rs->rs_start, rs->rs_end - rs->rs_start);
}

void *
range_tree_first(range_tree_t *rt)
{
	ASSERT(MUTEX_HELD(rt->rt_lock));
	return (avl_first(&rt->rt_root));
}

uint64_t
range_tree_space(range_tree_t *rt)
{
	return (rt->rt_space);
}
