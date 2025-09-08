#include <stdint.h>
#include "params.h"
#include "sign.h"
#include "packing.h"
#include "poly.h"
#include "randombytes.h"
#include "symmetric.h"
#include "fips202.h"
#include "stdio.h"
#include "HWACC.h"
#include <stdlib.h>

#define NTT 1
poly cp, mat, z, t0, t1;


int crypto_sign_keypair(uint8_t *pk, uint8_t *sk) {
	uint8_t zeta[SEEDBYTES];
	uint8_t seedbuf[3 * SEEDBYTES];
	uint8_t tr[SEEDBYTES];
	const uint8_t *xi_1, *xi_2, *key;

	poly mat, s1, s1hat, s2, t0,mt_q1, mt_q2;

	randombytes(zeta, SEEDBYTES);
	randombytes(seedbuf, SEEDBYTES);
	shake256(seedbuf, 3 * SEEDBYTES, seedbuf, SEEDBYTES);
	xi_1 = seedbuf;
	xi_2 = seedbuf + SEEDBYTES;
	key = seedbuf + 2 * SEEDBYTES;

	poly_uniform(&mat, zeta, 0);
	poly_uniform_eta(&s1, xi_1, 0);
	poly_uniform_eta(&s2, xi_2, 0);

	s1hat = s1;
	invntt_tomont_pre(mat.coeffs,mat.coeffs);
	poly_mul_NTT_multi_q1(&mt_q1,&s1hat,&mat);
  	poly_mul_NTT_multi_q2(&mt_q2,&s1hat,&mat);
  	ntt_crt(&t1,&mt_q1,&mt_q2);
	poly_caddq(&t1);

	poly_add(&t1, &t1, &s2);
	poly_caddq(&t1);

	poly_power2round(&t1, &t0, &t1);

	pack_pk(pk, zeta, &t1);

	shake256(tr, SEEDBYTES, pk, CRYPTO_PUBLICKEYBYTES);

	pack_sk(sk, zeta, tr, key, &t0, &s1, &s2);

	return 0;
}

uint32_t hw_matq1[N_NTT] __attribute__((aligned(DMA_ALIGN)));
uint32_t hw_matq2[N_NTT] __attribute__((aligned(DMA_ALIGN)));
uint32_t hw_cp[N_NTT] __attribute__((aligned(DMA_ALIGN)));
uint32_t hw_t[N_NTT] __attribute__((aligned(DMA_ALIGN)));

int crypto_sign_signature(uint8_t *sig,
                        	size_t *siglen,
                        	const uint8_t *m,
                        	size_t mlen,
                        	const uint8_t *sk)
{
	unsigned int n;
	uint8_t seedbuf[3 * SEEDBYTES + 2 * CRHBYTES];
	uint8_t *zeta, *tr, *key, *mu, *rho;
	uint16_t nonce = 0;
	poly s1, y, s2, w1, w0, h, tmp_q1, tmp_q2;
	keccak_state state;

	zeta = seedbuf;
	tr = zeta + SEEDBYTES;
	key = tr + SEEDBYTES;
	mu = key + SEEDBYTES;
	rho = mu + CRHBYTES;
	unpack_sk(zeta, tr, key, &t0, &s1, &s2, sk);

	shake256_init(&state);
	shake256_absorb(&state, tr, SEEDBYTES);
	shake256_absorb(&state, m, mlen);
	shake256_finalize(&state);
	shake256_squeeze(mu, CRHBYTES, &state);

	shake256(rho, CRHBYTES, key, SEEDBYTES + CRHBYTES);
	poly_uniform(&mat, zeta, 0);
	invntt_tomont_pre(mat.coeffs,mat.coeffs);

	memcpy(hw_t, mat.coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q1(hw_matq1, hw_t);

	memcpy(hw_t, mat.coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q2(hw_matq2, hw_t);

rej:
	poly_uniform_gamma1(&y, rho, nonce++);
	z = y;

	poly_mul_NTT_multi_q1_pre(&tmp_q1,hw_matq1,&z);
  	poly_mul_NTT_multi_q2_pre(&tmp_q2,hw_matq2,&z);
  	ntt_crt(&w1,&tmp_q1,&tmp_q2);
	poly_caddq(&w1);
	poly_decompose(&w1, &w0, &w1);
	polyw1_pack(sig, &w1);

	shake256_init(&state);
	shake256_absorb(&state, mu, CRHBYTES);
	shake256_absorb(&state, sig, POLYW1_PACKEDBYTES);
	shake256_finalize(&state);
	shake256_squeeze(sig, SEEDBYTES, &state);
	poly_challenge(&cp, sig);

	memcpy(hw_t, cp.coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q1(hw_cp, hw_t);

	poly_mul_NTT_multi_q1_pre(&z,hw_cp,&s1);
	poly_add(&z, &z, &y);
  	poly_reduce(&z);
	if (poly_chknorm(&z, GAMMA1 - BETA))
	{
		goto rej;
	}

	poly_mul_NTT_multi_q1_pre(&h,hw_cp,&s2);
	poly_sub(&w0, &w0, &h);
  	poly_reduce(&w0);
	if (poly_chknorm(&w0, GAMMA2 - BETA))
	{
		goto rej;
	}

	poly_mul_NTT_multi_q1_pre(&h,hw_cp,&t0);
  	poly_reduce(&h);
	if (poly_chknorm(&h, GAMMA2))
	{
		goto rej;
	}

	poly_add(&w0, &w0, &h);
	n = poly_make_hint(&h, &w0, &w1);
	if (n > OMEGA)
	{
		goto rej;
	}

	pack_sig(sig, sig, &z, &h);
	*siglen = CRYPTO_BYTES;
	return 0;
}

int crypto_sign(uint8_t *sm,
              	size_t *smlen,
              	const uint8_t *m,
              	size_t mlen,
              	const uint8_t *sk)
{
	size_t i;

	for (i = 0; i < mlen; ++i)
		sm[CRYPTO_BYTES + mlen - 1 - i] = m[mlen - 1 - i];
	crypto_sign_signature(sm, smlen, sm + CRYPTO_BYTES, mlen, sk);
	*smlen += mlen;
	return 0;
}

int crypto_sign_verify(const uint8_t *sig,
                       size_t siglen,
                       const uint8_t *m,
                       size_t mlen,
                       const uint8_t *pk)
{
	unsigned int i;
	uint8_t buf[POLYW1_PACKEDBYTES];
	uint8_t zeta[SEEDBYTES];
	uint8_t mu[CRHBYTES];
	uint8_t c[SEEDBYTES];
	uint8_t c2[SEEDBYTES];

	poly w1, h;
	keccak_state state;

	if (siglen != CRYPTO_BYTES)
		return -1;
	unpack_pk(zeta, &t1, pk);

	if (unpack_sig(c, &z, &h, sig))
		return -1;

	if (poly_chknorm(&z, GAMMA1 - BETA))
		return -1;

	shake256(mu, SEEDBYTES, pk, CRYPTO_PUBLICKEYBYTES);
	shake256_init(&state);
	shake256_absorb(&state, mu, SEEDBYTES);
	shake256_absorb(&state, m, mlen);
	shake256_finalize(&state);
	shake256_squeeze(mu, CRHBYTES, &state);
	poly_challenge(&cp, c);

	poly_uniform(&mat, zeta, 0);
	invntt_tomont_pre(mat.coeffs,mat.coeffs);

	poly_shiftl(&t1);

	poly_mul_NTT_ayz_verify(&w1,&z,&mat,&cp,&t1);
	poly_caddq(&w1);

	poly_use_hint(&w1, &w1, &h);
	polyw1_pack(buf, &w1);

	shake256_init(&state);
	shake256_absorb(&state, mu, CRHBYTES);
	shake256_absorb(&state, buf, POLYW1_PACKEDBYTES);
	shake256_finalize(&state);
	shake256_squeeze(c2, SEEDBYTES, &state);

	for (i = 0; i < SEEDBYTES; ++i)
		if (c[i] != c2[i])
			return -1;

	return 0;
}

int crypto_sign_open(uint8_t *m,
                     size_t *mlen,
                     const uint8_t *sm,
                     size_t smlen,
                     const uint8_t *pk)
{
	size_t i;

	if (smlen < CRYPTO_BYTES)
		goto badsig;

	*mlen = smlen - CRYPTO_BYTES;
	if (crypto_sign_verify(sm, CRYPTO_BYTES, sm + CRYPTO_BYTES, *mlen, pk))
		goto badsig;
	else {
		for (i = 0; i < *mlen; ++i)
			m[i] = sm[CRYPTO_BYTES + i];
		return 0;
	}

badsig:
	/* Signature verification failed */
	*mlen = -1;
	for (i = 0; i < smlen; ++i)
		m[i] = 0;

	return -1;
}
