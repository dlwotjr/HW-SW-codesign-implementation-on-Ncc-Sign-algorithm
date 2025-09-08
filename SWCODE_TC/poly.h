#ifndef POLY_H
#define POLY_H

#include <stdint.h>
#include "params.h"

#ifndef DMA_ALIGN
#define DMA_ALIGN 64
#endif

typedef struct _poly
{
  int32_t coeffs[N]__attribute__((aligned(DMA_ALIGN)));
} poly;


void poly_mul_NTT_multi_q1(poly* res, poly* a, poly* b);
void poly_mul_NTT_multi_q2(poly* res, poly* a, poly* b);
void poly_mul_NTT_multi_q1_pre(poly *res, uint32_t *hw_cp, poly *a);
void poly_mul_NTT_multi_q2_pre(poly *res, uint32_t *hw_cp, poly *a);
void poly_mul_NTT_ayz_verify(poly* res, poly* a, poly* b,poly *c, poly *d);

void invntt_tomont_pre(int32_t *Out, int32_t *A);
void ntt_crt(poly *c, poly *a, poly *b);
int poly_check(poly *a, poly *b);
void poly_tomont(poly *a_mont, poly *a);
void pointwise_mul(int32_t *C, int32_t *A, int32_t *B);
void base_mul(int32_t *C, int32_t *A, int32_t *B, int32_t zeta);
void reduce_modQ(int32_t *A);

void poly_reduce(poly *a);
void poly_caddq(poly *a);

void poly_add(poly *c, const poly *a, const poly *b);
void poly_sub(poly *c, poly *a, poly *b);
void poly_shiftl(poly *a);
void poly_pointwise_montgomery(poly *c, const poly *a, const poly *b);

void poly_power2round(poly *a1, poly *a0, const poly *a);
void poly_decompose(poly *a1, poly *a0, const poly *a);
unsigned int poly_make_hint(poly *h, const poly *a0, const poly *a1);
void poly_use_hint(poly *b, const poly *a, const poly *h);

int poly_chknorm(poly *a, int32_t B);
void poly_uniform(poly *a,
                  const uint8_t seed[SEEDBYTES],
                  uint16_t nonce);
void poly_uniform_eta(poly *a,
                      const uint8_t seed[CRHBYTES],
                      uint16_t nonce);
void poly_uniform_gamma1(poly *a,
                         const uint8_t seed[CRHBYTES],
                         uint16_t nonce);
void poly_challenge(poly *c, const uint8_t seed[SEEDBYTES]);

#endif
