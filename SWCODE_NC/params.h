#ifndef PARAMS_H
#define PARAMS_H

#include "config.h"

#define SEEDBYTES 32
#define CRHBYTES 64


#if NIMS_MODE == 2
#define N 1201
#define P 1201
#define NR 1216
#define Q 17279291
 
#define D 12
#define ETA 2
#define TAU 32
#define BETA 128
#define GAMMA1 (1 << 19)
#define GAMMA2 ((Q-1)/70)
#define OMEGA 80
#define R2_mont 634515 //R2.. 2^64 mod Q

#elif NIMS_MODE == 3
#define N 1607
#define P 1607
#define NR 1664
#define Q 17305741
#define D 13
#define ETA 2
#define TAU 32
#define BETA 128
#define GAMMA1 (1 << 19)
#define GAMMA2 ((Q-1)/60)
#define OMEGA 80
#define R2_mont 17118374 //R2.. 2^64 mod Q

#elif NIMS_MODE == 5
#define N 2039
#define P 2039
#define NR 2048
#define Q 17287423
#define D 13
#define ETA 2
#define TAU 32
#define BETA 128
#define GAMMA1 (1 << 19)
#define GAMMA2 ((Q-1)/58)
#define OMEGA 80
#define R2_mont 6791437 //R2.. 2^64 mod Q

#endif

//packing bytes define

#define POLYT1_PACKEDBYTES      (((N*(25-D)+7)/8))
#define POLYT0_PACKEDBYTES      (((N*D)+7)/8)
#define POLYH_PACKEDBYTES       ((N+7)/8)
#define POLYZ_PACKEDBYTES       (((N*20)+7)/8)
#if (N==1201)
#define POLYW1_PACKEDBYTES      (((N*6)+7)/8)
#else
#define POLYW1_PACKEDBYTES      (((N*5)+7)/8)
#endif
#define POLYETA_PACKEDBYTES     (((N*3)+7)/8)
#define CRYPTO_PUBLICKEYBYTES   (SEEDBYTES + POLYT1_PACKEDBYTES)
#define CRYPTO_SECRETKEYBYTES   (3*SEEDBYTES\
                                + 2*POLYETA_PACKEDBYTES\
                                + POLYT0_PACKEDBYTES)
#define CRYPTO_BYTES            (SEEDBYTES + POLYZ_PACKEDBYTES + POLYH_PACKEDBYTES)


//! CRT Param

#define Q1_MONT   -1048608
#define MONT_PINV   -32
#define CRT_U   178967883
#define CRT_U_PINV   349515
#endif
