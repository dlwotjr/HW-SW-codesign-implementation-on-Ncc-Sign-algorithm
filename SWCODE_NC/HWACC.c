#include "HWACC.h"

XAxiDma axidma;
XScuGic intc;
volatile int tx_done;
volatile int rx_done;
volatile int error;

void transmission_initialization()
{
	int status;
	XAxiDma_Config* config;

	config = XAxiDma_LookupConfig(DMA_DEV_ID);
	if (!config)	xil_printf("No config found for %d\r\n", DMA_DEV_ID);

	status = XAxiDma_CfgInitialize(&axidma, config);
	if (status != XST_SUCCESS)	xil_printf("Initialization failed %d\r\n", status);

	if (XAxiDma_HasSg(&axidma))	xil_printf("Device configured as SG mode \r\n");

	/* Disable interrupts, we use polling mode*/
	XAxiDma_IntrDisable(&axidma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrDisable(&axidma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
}

void hw_KeccakF1600_StatePermute(uint64_t state[25])
{
	int status;
	My_DMA_Ctrl_0 = 1;
	My_DMA_Ctrl_1 = 0b0000;

	Xil_DCacheFlushRange((UINTPTR)state, 200);

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)state, 200,XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) {printf("Shake256 Write ERROR\n");}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)state, 200,XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("Shake256 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DEVICE_TO_DMA)) ||(XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}//printf("wating hw_KeccakF1600_StatePermute\n");}
}

void hw_point_wise_mul_q1(uint32_t* c, const uint32_t* a, const uint32_t* b)
{
	int status;
	My_DMA_Ctrl_0 = 2;
	My_DMA_Ctrl_1 = 0b0000;

	Xil_DCacheFlushRange((UINTPTR)a, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)b, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)c, 4096 * 4);

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)c, 4096 * 4,XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) {printf("PWMKQ2 Write ERROR\n");}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)a, 4096 * 4,XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("PWMK1Q2 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)b, 4096 * 4,XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("PWMK2Q2 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DEVICE_TO_DMA)) ||(XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}//printf("wating hw_point_wise_mul_Q1\n");}
}

void hw_point_wise_mul_q2(uint32_t* c, const uint32_t* a, const uint32_t* b)
{
	int status;
	My_DMA_Ctrl_0 = 2;
	My_DMA_Ctrl_1 = 0b0100;

	Xil_DCacheFlushRange((UINTPTR)a, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)b, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)c, 4096 * 4);

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)c, 4096 * 4,XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) {printf("PWMKQ1 Write ERROR\n");}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)a, 4096 * 4,XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("PWMK1Q1 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)b, 4096 * 4,XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("PWMK2Q1 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DEVICE_TO_DMA)) ||(XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}//printf("wating hw_point_wise_mul_Q2\n");}
}

void hw_ntt_multi_q1(uint32_t* r, uint32_t* a)
{
	int status;
	My_DMA_Ctrl_1 = 0b11000001;
	My_DMA_Ctrl_0 = 2;

	Xil_DCacheFlushRange((UINTPTR)a, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)r, 4096 * 4);

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)r, 4096 * 4, XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) {printf("NTTQ1 Write ERROR\n");}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)a, 4096 * 4, XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("NTTQ1 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DEVICE_TO_DMA)) ||(XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}//printf("wating hw_ntt_multi_q1\n");}
}

void hw_intt_multi_q1(uint32_t* r, uint32_t* a)
{
	int status;
	My_DMA_Ctrl_1 = 0b11000010;
	My_DMA_Ctrl_0 = 2;

	Xil_DCacheFlushRange((UINTPTR)a, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)r, 4096 * 4);

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)r, 4096 * 4, XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) {printf("iNTTQ1 Write ERROR\n");}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)a, 4096 * 4, XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("iNTTQ1 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DEVICE_TO_DMA)) ||(XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}//printf("wating hw_intt_multi_q1\n");}
}

void hw_ntt_multi_q2(uint32_t* r, uint32_t* a)
{
	int status;
	My_DMA_Ctrl_1 = 0b11000101;
	My_DMA_Ctrl_0 = 2;

	Xil_DCacheFlushRange((UINTPTR)a, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)r, 4096 * 4);

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)r, 4096 * 4, XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) {printf("NTTQ2 Write ERROR\n");}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)a, 4096 * 4, XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("NTTQ2 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DEVICE_TO_DMA)) ||(XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}//printf("wating hw_ntt_multi_q2\n");}
}

void hw_intt_multi_q2(uint32_t* r, uint32_t* a)
{
	int status;
	My_DMA_Ctrl_1 = 0b11000110;
	My_DMA_Ctrl_0 = 2;

	Xil_DCacheFlushRange((UINTPTR)a, 4096 * 4);
	Xil_DCacheFlushRange((UINTPTR)r, 4096 * 4);

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)r, 4096 * 4, XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) {printf("iNTTQ2 Write ERROR\n");}

	status = XAxiDma_SimpleTransfer(&axidma, (UINTPTR)a, 4096 * 4, XAXIDMA_DMA_TO_DEVICE);
	if (status != XST_SUCCESS) {printf("iNTTQ2 Read ERROR\n");}
	while ((XAxiDma_Busy(&axidma, XAXIDMA_DEVICE_TO_DMA)) ||(XAxiDma_Busy(&axidma, XAXIDMA_DMA_TO_DEVICE))) {}//printf("wating hw_intt_multi_q2\n");}
}
