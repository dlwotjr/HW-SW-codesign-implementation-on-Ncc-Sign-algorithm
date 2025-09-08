#include "fips202.h"
#include "platform.h"
#include "randombytes.h"
#include "sign.h"
#include "xil_printf.h"
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "platform.h"
#include "xaxidma.h"
#include "xaxidma_hw.h"
#include "xil_exception.h"
#include "xparameters.h"
#include "xscugic.h"

#define PRM_Q1 (uint32_t)134250497
#define PRM_Q2 (uint32_t)536903681
#define inv2Q1 (uint32_t)67125249
#define inv2Q2 (uint32_t)268451841
#define MLEN 32
#define NTESTS 1

#define DMA_DEV_ID 0
#define RX_INTR_ID XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_VEC_ID
#define TX_INTR_ID XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_VEC_ID
#define INTC_DEVICE_ID XPAR_SCUGIC_SINGLE_DEVICE_ID
#define RESET_TIMEOUT_COUNTER 1000 // reset time
#define XAXIDMA_ENABLE_INTR

#define My_DMA_Ctrl_0 (*(volatile unsigned int *)(XPAR_MDL_0_BASEADDR))
#define My_DMA_Ctrl_1 (*(volatile unsigned int *)(XPAR_MDL_0_BASEADDR + 4))

void transmission_initialization();

void hw_KeccakF1600_StatePermute(uint64_t state[25]);

void hw_ntt_multi_q1(uint32_t* r, uint32_t* a);
void hw_ntt_multi_q2(uint32_t* r, uint32_t* a);

void hw_point_wise_mul_q1(uint32_t *c, const uint32_t *a, const uint32_t *b);
void hw_point_wise_mul_q2(uint32_t *c, const uint32_t *a, const uint32_t *b);

void hw_intt_multi_q1(uint32_t* r, uint32_t* a);
void hw_intt_multi_q2(uint32_t* r, uint32_t* a);

