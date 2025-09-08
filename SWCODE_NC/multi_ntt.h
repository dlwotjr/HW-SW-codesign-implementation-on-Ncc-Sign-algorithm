#ifndef MULTI_NTT_H
#define MULTI_NTT_H

#include <stdint.h>
#include "params.h"
#include "poly.h"

void poly_mul_NTT_multi_q1(poly* res, poly* a, poly* b);
void poly_mul_NTT_multi_q2(poly* res, poly* a, poly* b);
void poly_mul_NTT_ayz_verify(poly* res, poly* a, poly* b, poly* c, poly* d);

#endif

