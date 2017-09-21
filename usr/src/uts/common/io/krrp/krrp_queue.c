/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <sys/types.h>
#include <sys/kmem.h>
#include <sys/ddi.h>
#include <sys/sunddi.h>
#include <sys/time.h>
#include <sys/sysmacros.h>
#include <sys/debug.h>

#include "krrp_queue.h"

void
krrp_queue_init(krrp_queue_t **queue, size_t obj_sz, size_t offset)
{
	krrp_queue_t *qp;

	VERIFY(queue != NULL && *queue == NULL);

	qp = kmem_zalloc(sizeof (krrp_queue_t), KM_SLEEP);

	list_create(&qp->list, obj_sz, offset);
	qp->cnt = 0;
	qp->force_return = B_FALSE;

	mutex_init(&qp->mtx, NULL, MUTEX_DEFAULT, NULL);
	cv_init(&qp->cv, NULL, CV_DEFAULT, NULL);

	*queue = qp;
}

void
krrp_queue_fini(krrp_queue_t *queue)
{
	mutex_enter(&queue->mtx);

	VERIFY(queue->cnt == 0);
	list_destroy(&queue->list);

	mutex_exit(&queue->mtx);

	cv_destroy(&queue->cv);
	mutex_destroy(&queue->mtx);

	kmem_free(queue, sizeof (krrp_queue_t));
}

size_t
krrp_queue_length(krrp_queue_t *queue)
{
	size_t length = 0;

	mutex_enter(&queue->mtx);
	length = queue->cnt;
	mutex_exit(&queue->mtx);

	return (length);
}

void
krrp_queue_set_force_return(krrp_queue_t *queue)
{
	mutex_enter(&queue->mtx);
	queue->force_return = B_TRUE;
	cv_broadcast(&queue->cv);
	mutex_exit(&queue->mtx);
}

void
krrp_queue_put(krrp_queue_t *queue, void *obj)
{
	ASSERT(obj != NULL);

	mutex_enter(&queue->mtx);
	list_insert_head(&queue->list, obj);
	queue->cnt++;
	cv_broadcast(&queue->cv);
	mutex_exit(&queue->mtx);
}

void *
krrp_queue_get(krrp_queue_t *queue)
{
	void *obj;
	clock_t time_left = 0;

	mutex_enter(&queue->mtx);

	while ((obj = list_remove_tail(&queue->list)) == NULL) {
		/*
		 * time_left < 0: timeout exceeded
		 */
		if (queue->force_return || time_left < 0) {
			mutex_exit(&queue->mtx);
			return (NULL);
		}

		time_left = cv_reltimedwait(&queue->cv, &queue->mtx,
		    MSEC_TO_TICK(10), TR_CLOCK_TICK);
	}

	queue->cnt--;
	mutex_exit(&queue->mtx);

	return (obj);
}

void *
krrp_queue_get_no_wait(krrp_queue_t *queue)
{
	void *obj;

	mutex_enter(&queue->mtx);

	obj = list_remove_tail(&queue->list);
	if (obj != NULL)
		queue->cnt--;

	mutex_exit(&queue->mtx);

	return (obj);
}
