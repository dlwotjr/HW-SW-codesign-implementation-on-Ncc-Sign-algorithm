/******************************************************************************
 * Copyright (C) 2023 Advanced Micro Devices, Inc.
 * SPDX-License-Identifier: MIT
 ******************************************************************************/
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "platform.h"
#include "xil_printf.h"

#include "xparameters.h"
#include "xaxidma.h"
#include "xaxidma_hw.h"
#include "xil_exception.h"
#include "xscugic.h"

#include "scutimer.h"
#include "HWACC.h"

#include "fips202.h"
#include "randombytes.h"
#include "sign.h"
#include "params.h"
#include "reduce.h"

#define POLY_LEN 4096
#define NRUNS    1u

static int cmp_ulu(const void *a, const void *b) {
    const unsigned long av = *(const unsigned long *)a;
    const unsigned long bv = *(const unsigned long *)b;
    return (av > bv) - (av < bv);
}

static unsigned long median_ul(const unsigned long *src, size_t n) {
    if (n == 0) return 0;
    unsigned long *tmp = malloc(n * sizeof(*tmp));
    if (!tmp) return 0;
    for (size_t i = 0; i < n; ++i) tmp[i] = src[i];
    qsort(tmp, n, sizeof(*tmp), cmp_ulu);
    unsigned long m = (n & 1) ? tmp[n/2]
                              : (tmp[n/2 - 1] + tmp[n/2]) / 2;
    free(tmp);
    return m;
}

static unsigned long average_ul(const unsigned long *t, size_t n) {
    if (n == 0) return 0;
    unsigned long long acc = 0;
    for (size_t i = 0; i < n; ++i) acc += t[i];
    return (unsigned long)(acc / n);
}

static void print_results(const char *title, const unsigned long *t, size_t n) {
    xil_printf("%s\r\n", title);
    xil_printf("  median : %lu cycles\r\n",  median_ul(t, n));
    xil_printf("  average: %lu cycles\r\n\r\n", average_ul(t, n));
}

#define TIME_BLOCK(var, stmt) do { 	\
    scutimer_start();               \
    { stmt; }                       \
    (var) = scutimer_result();      \
} while (0)

int main(void) {
    xil_printf("\r\n//////////START!//////////\r\n\n");
#if NIMS_TRI_NTT_MODE == 1
	printf("Set Security Level 1\n");
#elif NIMS_TRI_NTT_MODE == 3
	printf("Set Security Level 3\n");
#elif NIMS_TRI_NTT_MODE == 5
	printf("Set Security Level 5\n");
#elif NIMS_TRI_NTT_MODE == 55
	printf("Set Security Level 55\n");
#endif
    init_platform();
    transmission_initialization();

    unsigned long t_keygen[NRUNS] = {0};
    unsigned long t_sign  [NRUNS] = {0};
    unsigned long t_ver   [NRUNS] = {0};

    size_t mlen = 0, smlen = 0;
    uint8_t m[MLEN] = {0};
    uint8_t sm[MLEN + CRYPTO_BYTES] = {0};
    uint8_t m2[MLEN] = {0};
    uint8_t pk[CRYPTO_PUBLICKEYBYTES] = {0};
    uint8_t sk[CRYPTO_SECRETKEYBYTES] = {0};

    randombytes(m, MLEN);

    for (size_t i = 0; i < NRUNS; ++i) {
        TIME_BLOCK(t_keygen[i], crypto_sign_keypair(pk, sk));
        TIME_BLOCK(t_sign  [i], crypto_sign(sm, &smlen, m, MLEN, sk));
//        TIME_BLOCK(t_ver   [i], crypto_sign_open(m2, &mlen, sm, smlen, pk));
    }

    print_results("KeyGen HW", t_keygen, NRUNS);
    print_results("Sign HW   ", t_sign,   NRUNS);
//    print_results("Verify HW ", t_ver,    NRUNS);

    cleanup_platform();
    xil_printf("///////////END!//////////\r\n");
    return 0;
}
