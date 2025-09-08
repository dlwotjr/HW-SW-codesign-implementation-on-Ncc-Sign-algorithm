#include "poly.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "./sign.h"
#include "packing.h"
#include "params.h"
#include "reduce.h"
#include "rounding.h"
#include "symmetric.h"
#include "HWACC.h"

#ifndef DMA_ALIGN
#define DMA_ALIGN 64
#endif

#define Q_NTT_MULTI_Q1		(uint32_t) 134250497
#define Q_NTT_MULTI_Q2		(uint32_t) 536903681
#define QINV_NTT_MULTI_Q1	(uint32_t) 939491329
#define QINV_NTT_MULTI_Q2	(uint32_t) 536838145

static int32_t unsigned2signed(uint32_t a, uint32_t q)
{
	if (a > (q >> 1)) return (int32_t)(a - q);
	return (int32_t)a;
}

void poly_mul_NTT_multi_q1(poly *res, poly *a, poly *b)
{
	int32_t hw_st[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_a[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_b[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_t[N_NTT] __attribute__((aligned(DMA_ALIGN)));

	memcpy(hw_t, a->coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q1(hw_a, hw_t);

	memcpy(hw_t, b->coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q1(hw_b, hw_t);

	hw_point_wise_mul_q1(hw_t, hw_a, hw_b);
	hw_intt_multi_q1(hw_a, hw_t);

	for (uint32_t i = 0; i < N_NTT; i++) hw_st[i] = unsigned2signed(hw_a[i], Q_NTT_MULTI_Q1);

	for (uint32_t i = N + (N >> 1) - 1; i < 2 * N - 1; i++)
	{
		hw_st[i - (N >> 1)] = (hw_st[i - (N >> 1)] + hw_st[i]);
		hw_st[i - N] = (hw_st[i - N] - hw_st[i]);
	}

	for (uint32_t i = N; i < N + (N >> 1) - 1; i++)
	{
		hw_st[i - (N >> 1)] = (hw_st[i - (N >> 1)] + hw_st[i]);
		hw_st[i - N] = (hw_st[i - N] - hw_st[i]);
	}

	for (uint32_t i = 0; i < N; i++)
	{
		res->coeffs[i] = hw_st[i];
	}
}

void poly_mul_NTT_multi_q1_pre(poly *res, uint32_t *hw_cp, poly *a)
{
	int32_t hw_st[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_a[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_t[N_NTT] __attribute__((aligned(DMA_ALIGN)));

	memcpy(hw_t, a->coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q1(hw_a, hw_t);

	hw_point_wise_mul_q1(hw_t, hw_a, hw_cp);
	hw_intt_multi_q1(hw_a, hw_t);

	for (uint32_t i = 0; i < N_NTT; i++) hw_st[i] = unsigned2signed(hw_a[i], Q_NTT_MULTI_Q1);

	for (uint32_t i = N + (N >> 1) - 1; i < 2 * N - 1; i++)
	{
		hw_st[i - (N >> 1)] = (hw_st[i - (N >> 1)] + hw_st[i]);
		hw_st[i - N] = (hw_st[i - N] - hw_st[i]);
	}

	for (uint32_t i = N; i < N + (N >> 1) - 1; i++)
	{
		hw_st[i - (N >> 1)] = (hw_st[i - (N >> 1)] + hw_st[i]);
		hw_st[i - N] = (hw_st[i - N] - hw_st[i]);
	}

	for (uint32_t i = 0; i < N; i++)
	{
		res->coeffs[i] = hw_st[i];
	}
}

void poly_mul_NTT_multi_q2(poly *res, poly *a, poly *b)
{
	uint32_t hw_a[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_b[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_t[N_NTT] __attribute__((aligned(DMA_ALIGN)));

	memcpy(hw_t, a->coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q2(hw_a, hw_t);

	memcpy(hw_t, b->coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q2(hw_b, hw_t);

	hw_point_wise_mul_q2(hw_t, hw_a, hw_b);
	hw_intt_multi_q2(hw_a, hw_t);

	for (uint32_t i = N + (N >> 1) - 1; i < 2 * N - 1; i++)
	{
		hw_a[i - (N >> 1)] = (hw_a[i - (N >> 1)] + hw_a[i]);
		hw_a[i - N] = (hw_a[i - N] - hw_a[i]);
	}

	for (uint32_t i = N; i < N + (N >> 1) - 1; i++)
	{
		hw_a[i - (N >> 1)] = (hw_a[i - (N >> 1)] + hw_a[i]);
		hw_a[i - N] = (hw_a[i - N] - hw_a[i]);
	}

	for (uint32_t i = 0; i < N; i++)
	{
		res->coeffs[i] = (int32_t) hw_a[i];
	}
}

void poly_mul_NTT_multi_q2_pre(poly *res, uint32_t *hw_cp, poly *a)
{
	int32_t hw_st[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_a[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t hw_t[N_NTT] __attribute__((aligned(DMA_ALIGN)));

	memcpy(hw_t, a->coeffs, N * sizeof(int32_t));
	memset(hw_t + N, 0, (N_NTT - N) * sizeof(uint32_t));
	hw_ntt_multi_q2(hw_a, hw_t);

	hw_point_wise_mul_q2(hw_t, hw_a, hw_cp);
	hw_intt_multi_q2(hw_a, hw_t);

	for (uint32_t i = 0; i < N_NTT; i++) hw_st[i] = unsigned2signed(hw_a[i], Q_NTT_MULTI_Q2);

	for (uint32_t i = N + (N >> 1) - 1; i < 2 * N - 1; i++)
	{
		hw_st[i - (N >> 1)] = (hw_st[i - (N >> 1)] + hw_st[i]);
		hw_st[i - N] = (hw_st[i - N] - hw_st[i]);
	}

	for (uint32_t i = N; i < N + (N >> 1) - 1; i++)
	{
		hw_st[i - (N >> 1)] = (hw_st[i - (N >> 1)] + hw_st[i]);
		hw_st[i - N] = (hw_st[i - N] - hw_st[i]);
	}

	for (uint32_t i = 0; i < N; i++)
	{
		res->coeffs[i] = hw_st[i];
	}
}

void poly_mul_NTT_ayz_verify(poly *res, poly *a, poly *b, poly *c, poly *d)
{
	uint32_t i;
	uint32_t tmp[N_NTT]  __attribute__((aligned(DMA_ALIGN)));

	uint32_t A_q1[N_NTT]  __attribute__((aligned(DMA_ALIGN)));
	uint32_t B_q1[N_NTT]  __attribute__((aligned(DMA_ALIGN)));
	uint32_t A_q2[N_NTT]  __attribute__((aligned(DMA_ALIGN)));
	uint32_t B_q2[N_NTT]  __attribute__((aligned(DMA_ALIGN)));
	uint32_t E_q1[N_NTT]  __attribute__((aligned(DMA_ALIGN)));
	uint32_t E_q2[N_NTT]  __attribute__((aligned(DMA_ALIGN)));
	uint32_t E2_q1[N_NTT] __attribute__((aligned(DMA_ALIGN)));
	uint32_t E2_q2[N_NTT] __attribute__((aligned(DMA_ALIGN)));

	poly res_q1;
	poly res_q2;

	memcpy(tmp,  a->coeffs, sizeof(uint32_t) * N);
	memset(&tmp[N],  0, sizeof(uint32_t) * (N_NTT - N));
	hw_ntt_multi_q1(A_q1, tmp);
	hw_ntt_multi_q2(A_q2, tmp);

	memcpy(tmp,  b->coeffs, sizeof(uint32_t) * N);
	memset(&tmp[N],  0, sizeof(uint32_t) * (N_NTT - N));
	hw_ntt_multi_q1(B_q1, tmp);
	hw_ntt_multi_q2(B_q2, tmp);

	hw_point_wise_mul_q1(E_q1, A_q1, B_q1);
	hw_point_wise_mul_q2(E_q2, A_q2, B_q2);

	memcpy(tmp,  c->coeffs, sizeof(uint32_t) * N);
	memset(&tmp[N],  0, sizeof(uint32_t) * (N_NTT - N));
	hw_ntt_multi_q1(A_q1, tmp);
	hw_ntt_multi_q2(A_q2, tmp);

	memcpy(tmp,  d->coeffs, sizeof(uint32_t) * N);
	memset(&tmp[N],  0, sizeof(uint32_t) * (N_NTT - N));
	hw_ntt_multi_q1(B_q1, tmp);
	hw_ntt_multi_q2(B_q2, tmp);

	hw_point_wise_mul_q1(E2_q1, A_q1, B_q1);
	hw_point_wise_mul_q2(E2_q2, A_q2, B_q2);

	for (i = 0; i < N_NTT; i++) tmp[i] = E_q1[i] -  E2_q1[i];
	hw_intt_multi_q1(E_q1, tmp);

	for (i = 0; i < N_NTT; i++) tmp[i] = E_q2[i] - E2_q2[i];
	hw_intt_multi_q2(E_q2, tmp);

	for (i = N + (N >> 1) - 1; i < 2 * N - 1; i++)
	{
		E_q1[i - (N >> 1)] = (E_q1[i - (N >> 1)] + E_q1[i]);
		E_q1[i - N] = (E_q1[i - N] - E_q1[i]);

		E_q2[i - (N >> 1)] = (E_q2[i - (N >> 1)] + E_q2[i]);
		E_q2[i - N] = (E_q2[i - N] - E_q2[i]);
		}

	for (i = N; i < N + (N >> 1) - 1; i++)
	{
		E_q1[i - (N >> 1)] = (E_q1[i - (N >> 1)] + E_q1[i]);
		E_q1[i - N] = (E_q1[i - N] - E_q1[i]);

		E_q2[i - (N >> 1)] = (E_q2[i - (N >> 1)] + E_q2[i]);
		E_q2[i - N] = (E_q2[i - N] - E_q2[i]);
	}

	for (i = 0; i < N; i++)
	{
		res_q1.coeffs[i] = (int32_t)E_q1[i];
		res_q2.coeffs[i] = (int32_t)E_q2[i];
	}

	ntt_crt(res, &res_q1, &res_q2);
}
