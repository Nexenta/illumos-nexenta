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
 * Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 * Copyright 2014 Nexenta Systems, Inc.  All rights reserved.
 */

#ifndef _KERNEL
#include <strings.h>
#include <limits.h>
#include <assert.h>
#include <security/cryptoki.h>
#endif

#include <sys/types.h>
#include <modes/modes.h>
#include <sys/crypto/common.h>
#include <sys/crypto/impl.h>
#include <aes/aes_impl.h>

/* This is the CMAC Rb constant for 128-bit keys */
#define	const_Rb	0x87

/*
 * Algorithm independent CBC functions.
 */
int
cbc_encrypt_contiguous_blocks(cbc_ctx_t *ctx, char *data, size_t length,
    crypto_data_t *out, size_t block_size,
    int (*encrypt)(const void *, const uint8_t *, uint8_t *),
    void (*copy_block)(uint8_t *, uint8_t *),
    void (*xor_block)(uint8_t *, uint8_t *))
{
	size_t remainder = length;
	size_t need;
	uint8_t *datap = (uint8_t *)data;
	uint8_t *blockp;
	uint8_t *lastp;

	if (length + ctx->cbc_remainder_len < ctx->max_remain) {
		/* accumulate bytes here and return */
		bcopy(datap,
		    (uint8_t *)ctx->cbc_remainder + ctx->cbc_remainder_len,
		    length);
		ctx->cbc_remainder_len += length;
		ctx->cbc_copy_to = datap;
		return (CRYPTO_SUCCESS);
	}

	lastp = (uint8_t *)ctx->cbc_iv;

	do {
		/* Unprocessed data from last call. */
		if (ctx->cbc_remainder_len > 0) {
			need = block_size - ctx->cbc_remainder_len;

			if (need > remainder)
				return (CRYPTO_DATA_LEN_RANGE);

			bcopy(datap, &((uint8_t *)ctx->cbc_remainder)
			    [ctx->cbc_remainder_len], need);

			blockp = (uint8_t *)ctx->cbc_remainder;
		} else {
			blockp = datap;
		}

		if (out == NULL) {
			/*
			 * XOR the previous cipher block or IV with the
			 * current clear block.
			 */
			xor_block(lastp, blockp);
			encrypt(ctx->cbc_keysched, blockp, blockp);

			ctx->cbc_lastp = blockp;
			lastp = blockp;

			if ((ctx->cbc_flags & CMAC_MODE) == 0 &&
			    ctx->cbc_remainder_len > 0) {
				bcopy(blockp, ctx->cbc_copy_to,
				    ctx->cbc_remainder_len);
				bcopy(blockp + ctx->cbc_remainder_len, datap,
				    need);
			}
		} else {
			/*
			 * XOR the previous cipher block or IV with the
			 * current clear block.
			 */
			xor_block(blockp, lastp);
			encrypt(ctx->cbc_keysched, lastp, lastp);

			/*
			 * CMAC doesn't output until encrypt_final
			 */
			if ((ctx->cbc_flags & CMAC_MODE) == 0) {
				(void) crypto_put_output_data(lastp, out,
				    block_size);
				/* update offset */
				out->cd_offset += block_size;
			}
		}

		/* Update pointer to next block of data to be processed. */
		if (ctx->cbc_remainder_len != 0) {
			datap += need;
			ctx->cbc_remainder_len = 0;
		} else {
			datap += block_size;
		}

		remainder = (size_t)&data[length] - (size_t)datap;

		/* Incomplete last block. */
		if (remainder > 0 && remainder < ctx->max_remain) {
			bcopy(datap, ctx->cbc_remainder, remainder);
			ctx->cbc_remainder_len = remainder;
			ctx->cbc_copy_to = datap;
			goto out;
		}
		ctx->cbc_copy_to = NULL;

	} while (remainder > 0);

out:
	/*
	 * Save the last encrypted block in the context.
	 */
	if (ctx->cbc_lastp != NULL) {
		copy_block((uint8_t *)ctx->cbc_lastp, (uint8_t *)ctx->cbc_iv);
		ctx->cbc_lastp = (uint8_t *)ctx->cbc_iv;
	}

	return (CRYPTO_SUCCESS);
}

#define	OTHER(a, ctx) \
	(((a) == (ctx)->cbc_lastblock) ? (ctx)->cbc_iv : (ctx)->cbc_lastblock)

/* ARGSUSED */
int
cbc_decrypt_contiguous_blocks(cbc_ctx_t *ctx, char *data, size_t length,
    crypto_data_t *out, size_t block_size,
    int (*decrypt)(const void *, const uint8_t *, uint8_t *),
    void (*copy_block)(uint8_t *, uint8_t *),
    void (*xor_block)(uint8_t *, uint8_t *))
{
	size_t remainder = length;
	size_t need;
	uint8_t *datap = (uint8_t *)data;
	uint8_t *blockp;
	uint8_t *lastp;

	if (length + ctx->cbc_remainder_len < block_size) {
		/* accumulate bytes here and return */
		bcopy(datap,
		    (uint8_t *)ctx->cbc_remainder + ctx->cbc_remainder_len,
		    length);
		ctx->cbc_remainder_len += length;
		ctx->cbc_copy_to = datap;
		return (CRYPTO_SUCCESS);
	}

	lastp = ctx->cbc_lastp;

	do {
		/* Unprocessed data from last call. */
		if (ctx->cbc_remainder_len > 0) {
			need = block_size - ctx->cbc_remainder_len;

			if (need > remainder)
				return (CRYPTO_ENCRYPTED_DATA_LEN_RANGE);

			bcopy(datap, &((uint8_t *)ctx->cbc_remainder)
			    [ctx->cbc_remainder_len], need);

			blockp = (uint8_t *)ctx->cbc_remainder;
		} else {
			blockp = datap;
		}

		/* LINTED: pointer alignment */
		copy_block(blockp, (uint8_t *)OTHER((uint64_t *)lastp, ctx));

		if (out != NULL) {
			decrypt(ctx->cbc_keysched, blockp,
			    (uint8_t *)ctx->cbc_remainder);
			blockp = (uint8_t *)ctx->cbc_remainder;
		} else {
			decrypt(ctx->cbc_keysched, blockp, blockp);
		}

		/*
		 * XOR the previous cipher block or IV with the
		 * currently decrypted block.
		 */
		xor_block(lastp, blockp);

		/* LINTED: pointer alignment */
		lastp = (uint8_t *)OTHER((uint64_t *)lastp, ctx);

		if (out != NULL) {
			(void) crypto_put_output_data(blockp, out, block_size);
			/* update offset */
			out->cd_offset += block_size;

		} else if (ctx->cbc_remainder_len > 0) {
			/* copy temporary block to where it belongs */
			bcopy(blockp, ctx->cbc_copy_to, ctx->cbc_remainder_len);
			bcopy(blockp + ctx->cbc_remainder_len, datap, need);
		}

		/* Update pointer to next block of data to be processed. */
		if (ctx->cbc_remainder_len != 0) {
			datap += need;
			ctx->cbc_remainder_len = 0;
		} else {
			datap += block_size;
		}

		remainder = (size_t)&data[length] - (size_t)datap;

		/* Incomplete last block. */
		if (remainder > 0 && remainder < block_size) {
			bcopy(datap, ctx->cbc_remainder, remainder);
			ctx->cbc_remainder_len = remainder;
			ctx->cbc_lastp = lastp;
			ctx->cbc_copy_to = datap;
			return (CRYPTO_SUCCESS);
		}
		ctx->cbc_copy_to = NULL;

	} while (remainder > 0);

	ctx->cbc_lastp = lastp;
	return (CRYPTO_SUCCESS);
}

int
cbc_init_ctx(cbc_ctx_t *cbc_ctx, char *param, size_t param_len,
    size_t block_size, void (*copy_block)(uint8_t *, uint64_t *))
{
	/*
	 * Copy IV into context.
	 *
	 * If cm_param == NULL then the IV comes from the
	 * cd_miscdata field in the crypto_data structure.
	 */
	if (param != NULL) {
#ifdef _KERNEL
		ASSERT(param_len == block_size);
#else
		assert(param_len == block_size);
#endif
		copy_block((uchar_t *)param, cbc_ctx->cbc_iv);
	}

	cbc_ctx->cbc_lastp = (uint8_t *)&cbc_ctx->cbc_iv[0];
	cbc_ctx->cbc_flags |= CBC_MODE;
	cbc_ctx->max_remain = block_size;
	return (CRYPTO_SUCCESS);
}

/* ARGSUSED */
void *
cbc_alloc_ctx(int kmflag)
{
	cbc_ctx_t *cbc_ctx;

#ifdef _KERNEL
	if ((cbc_ctx = kmem_zalloc(sizeof (cbc_ctx_t), kmflag)) == NULL)
#else
	if ((cbc_ctx = calloc(1, sizeof (cbc_ctx_t))) == NULL)
#endif
		return (NULL);

	cbc_ctx->cbc_flags = CBC_MODE;
	return (cbc_ctx);
}

/*
 * Algorithms for supporting AES-CMAC
 * NOTE: CMAC is generally just a wrapper for CBC
 */

/*
 * max_remain is different for CMAC, and we never want to initialize
 * IV to anything other than zero.
 */
int
cmac_init_ctx(cbc_ctx_t *cbc_ctx, size_t block_size)
{
	/*
	 * allocated by kmem_zalloc/calloc, so cbc_iv is 0.
	 */

	cbc_ctx->cbc_lastp = (uint8_t *)&cbc_ctx->cbc_iv[0];
	cbc_ctx->cbc_flags |= CMAC_MODE;

	cbc_ctx->max_remain = block_size + 1;
	return (CRYPTO_SUCCESS);
}

/*
 * Left shifts 16-byte blocks by one and returns the leftmost bit
 */
static uint8_t
aes_left_shift_block_by1(uint8_t *block)
{
	uint8_t carry = 0, old;
	int i;
	for (i = AES_BLOCK_LEN-1; i >= 0; i--) {
		old = carry;
		carry = (block[i] & 0x80) ? 1 : 0;
		block[i] = (block[i] << 1) | old;
	}
	return (carry);
}

/*
 * Generate subkeys to preprocess the last block according to the spec.
 * Store the final 16-byte MAC generated in 'out'.
 */
int
cmac_mode_final(aes_ctx_t *aes_ctx, crypto_data_t *out,
    int (*encrypt_block)(const void *, const uint8_t *, uint8_t *),
    void (*xor_block)(uint8_t *, uint8_t *))
{
	uint8_t buf[AES_BLOCK_LEN] = {0};
	uint8_t *M_last = (uint8_t *)aes_ctx->ac_remainder;
	size_t length = aes_ctx->ac_remainder_len;

	if (length > AES_BLOCK_LEN)
		return (CRYPTO_INVALID_CONTEXT);

	/* k_0 = E_k(0) */
	encrypt_block(aes_ctx->ac_keysched, buf, buf);

	if (aes_left_shift_block_by1(buf))
		buf[AES_BLOCK_LEN-1] ^= const_Rb;

	if (length == AES_BLOCK_LEN) {
		/* Last block complete, so m_n = k_1 + m_n' */
		xor_block(buf, M_last);
		xor_block(aes_ctx->ac_lastp, M_last);
		encrypt_block(aes_ctx->ac_keysched, M_last, M_last);
	} else {
		/* Last block incomplete, so m_n = k_2 + (m_n' | 100...0_bin) */
		if (aes_left_shift_block_by1(buf))
			buf[AES_BLOCK_LEN-1] ^= const_Rb;

		M_last[length] = 0x80;
		bzero(M_last+length+1, AES_BLOCK_LEN - length - 1);
		xor_block(buf, M_last);
		xor_block(aes_ctx->ac_lastp, M_last);
		encrypt_block(aes_ctx->ac_keysched, M_last, M_last);
	}

	/*
	 * zero out the sub-key.
	 */
	bzero(&buf, sizeof (buf));
	return (crypto_put_output_data(M_last, out, AES_BLOCK_LEN));
}
