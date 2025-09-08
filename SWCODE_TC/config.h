#ifndef CONFIG_H
#define CONFIG_H

#define HW_MODE
#define SW_MODE

#ifndef NIMS_TRI_NTT_MODE
#define NIMS_TRI_NTT_MODE 55
#endif

#if NIMS_TRI_NTT_MODE == 1
#define CRYPTO_ALGNAME "NCC-Sign1"
#elif NIMS_TRI_NTT_MODE == 3
#define CRYPTO_ALGNAME "NCC-Sign3"
#elif NIMS_TRI_NTT_MODE == 55
#define CRYPTO_ALGNAME "NCC-Sign5prime"
#endif

#endif
