//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :
//  HISTORY     :  2025-08-15 ?? 9:13:06
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================
//! time definition
`include "./timescale.vh"
module MDL_MODMUL
#(
	parameter D	 = 30,
	parameter PRM_Q1 = 134250497,	// 28-bit PRM_Q1 : 134250497 = 0x8008001 = 2^{27} + 2^{15} + 1
	parameter PRM_Q2 = 536903681	// 30-bit PRM_Q2 : 536903681 = 0x20008001 = 2^{29} + 2^{15} + 1
)
(
	input				iSYS_CLK		,
	input				iSYS_RST		,
	     	        	
	input	[1:0]		iFSM_START		,   // 01: Q1, 10: Q2
	input	[D-1:0]		iA				,
	input	[D-1:0]		iB				,
	
	output	[D-1:0]		oR					// oR = iA x iB mod iQ
);
// pipeline 1-stage
reg			[14:0]	ah;
reg			[14:0]	al;
reg			[14:0]	bh;
reg			[14:0]	bl;
always@(negedge iSYS_RST or posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		ah	<= `A 'b0;
		al	<= `A 'b0;
		bh	<= `A 'b0;
		bl	<= `A 'b0;
	end		
	else if (iFSM_START)
	begin		
		ah	<= `A (iFSM_START == 2'b01) ? iA[27:14] : (iFSM_START == 2'b10) ? iA[29:15] : 'b0;
		al	<= `A (iFSM_START == 2'b01) ? iA[13:0]  : (iFSM_START == 2'b10) ? iA[14:0]  : 'b0;			
		bh	<= `A (iFSM_START == 2'b01) ? iB[27:14] : (iFSM_START == 2'b10) ? iB[29:15] : 'b0;
		bl	<= `A (iFSM_START == 2'b01) ? iB[13:0]  : (iFSM_START == 2'b10) ? iB[14:0]  : 'b0;
	end	
end
// pipeline 2-stage
wire	[D-1:0]		albl;
wire	[D-1:0]		albh;
wire	[D-1:0]		ahbl;
wire	[D-1:0]		ahbh;
assign	albl = al * bl;
assign	albh = al * bh;
assign	ahbl = ah * bl;
assign	ahbh = ah * bh;
reg			[59:0]		c;
reg			[30:0]		d;
always@(negedge iSYS_RST or posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		c	<= `A 'b0;
		d	<= `A 'b0;
	end		
	else if (iFSM_START)
	begin		
		c	<= `A	(iFSM_START == 2'b01) ? {ahbh[27:0], albl[27:0]} :
					(iFSM_START == 2'b10) ? {ahbh, albl} : 'b0;				
		d	<= `A 	albh + ahbl;
	end	
end
// pipeline 3-stage
reg			[29:0]		q1x1;		// [26+3:0]
reg			[28:0]		q1y1;		// [26+2:0]
reg			[27:0]		q1x2;		// [26+1:0]
reg			[27:0]		q1y2;		// [26+1:0]
reg			[30:0]		q2x1;		// [28+2:0]
reg			[30:0]		q2y1;		// [28+2:0]
reg			[29:0]		q2x2;		// [28+1:0]
reg			[29:0]		q2y2;		// [28+1:0]
reg			[59:0]		tc;
reg			[30:0]		td;
always@(negedge iSYS_RST or posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		q1x1	<= `A 'b0;
		q1y1	<= `A 'b0;
		q1x2	<= `A 'b0;
		q1y2	<= `A 'b0;
		q2x1	<= `A 'b0;
		q2y1	<= `A 'b0;
		q2x2	<= `A 'b0;
		q2y2	<= `A 'b0;
		tc		<= `A 'b0;
		td		<= `A 'b0;
		
	end		
	else if (iFSM_START)
	begin
		// ---Pipelined reg
		tc		<= `A c;
		td		<= `A d;		
		//	---Reduction with 2^{26} \equiv - 2{15} - 1 mod Q1
		q1x1	<= `A (c[50:39] << 15) + c[55:39] + (c[55:54] << 15) + c[55:54];
		q1y1	<= `A (c[38:27] << 15) + c[53:27] + (c[55:51] << 15) + c[55:51];
		q1x2	<= `A (d[12:0] << 14) + (d[28:25] << 15);
		q1y2	<= `A (d[24:13] << 15) + d[28:13];		
		//	---Reduction with 2^{29} \equiv - 2{15} - 1 mod Q2
		q2x1	<= `A (c[56:43] << 15) + c[59:43] + c[59:58] + (c[59:58] << 15);
		q2y1	<= `A (c[57:29] + (c[42:29] << 15) + (c[59:57] << 15) + c[59:57]);
		q2x2	<= `A (d[13:0] << 15) + (d[30:28] << 15);
		q2y2	<= `A (d[27:14] << 15) + d[30:14];
	end	
end
// pipeline 4-stage
reg signed [30:0]		q1rd1;		// [30:0] <- x1-y1
reg signed [28:0]		q1rd2;		// [30:0] <- x2-y2
reg signed [31:0]		q2rd1;		// [31:0] <- x1-y1
reg signed [30:0]		q2rd2;		// [30:0] <- x2-y2
always@(negedge iSYS_RST or posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		q1rd1	<= `A 'b0;
		q1rd2	<= `A 'b0;
		q2rd1	<= `A 'b0;
		q2rd2	<= `A 'b0;
		
	end		
	else if (iFSM_START)
	begin
		q1rd1	<= `A q1x1 - q1y1 + tc[26:0];
		q1rd2	<= `A q1x2 - q1y2 + td[28:25];
		q2rd1	<= `A q2x1 - q2y1 + tc[28:0];
		q2rd2	<= `A q2x2 - q2y2 + td[30:28];
	end	
end
// pipeline 5-stage
reg  signed [31:0]		q1sum;	// [31:0] <- rd1+rd2
reg  signed [32:0]		q2sum;	// [31:0] <- rd1+rd2
always@(negedge iSYS_RST or posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		q1sum	<= `A 'b0;
		q2sum	<= `A 'b0;
	end		
	else if (iFSM_START)
	begin
		q1sum	<= `A {q1rd1[30],q1rd1} + {{3{q1rd2[28]}},q1rd2};
		q2sum	<= `A {q2rd1[31],q2rd1} + {{2{q2rd2[30]}},q2rd2};
	end	
end
// pipeline 6-stage
wire signed [27:0]		q1sum0	=	{1'b0,q1sum[26:0]};
wire signed [4:0]		q1sum1	=	q1sum[31:27];
wire signed [29:0]		q2sum0	=	{1'b0,q2sum[28:0]};
wire signed [3:0]		q2sum1	=	q2sum[32:29];
wire signed [28:0]		tq1rd;
wire signed [30:0]		tq2rd;
assign	tq1rd	= (q1sum0 - q1sum1 - (q1sum1 << 15));
assign	tq2rd	= (q2sum0 - q2sum1 - (q2sum1 << 15));
reg signed [28:0]		q1rd;
reg signed [28:0]		q1;
reg signed [30:0]		q2rd;
reg signed [30:0]		q2;
always@(negedge iSYS_RST or posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		q1rd	<= `A 'b0;
		q1		<= `A 'b0;
		q2rd	<= `A 'b0;
		q2		<= `A 'b0;
	end		
	else if (iFSM_START)
	begin
		//	---Final Reduction q1
		q1rd	<= `A (tq1rd);
		q1		<= `A (tq1rd[28]) ? PRM_Q1 : -PRM_Q1;
		//	---Final Reduction q2
		q2rd	<= `A (tq2rd);
		q2		<= `A (tq2rd[30]) ? PRM_Q2 : -PRM_Q2;
	end	
end
// pipeline 7-stage
wire signed [28:0]		q1addq	=	q1rd + q1;
wire signed [30:0]		q2addq	=	q2rd + q2;
reg  [D-1:0]		q1res;
reg  [D-1:0]		q2res;
always@(negedge iSYS_RST or posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		q1res	<= `A 'b0;
		q2res	<= `A 'b0;
	end		
	else if (iFSM_START)
	begin
		q1res	<= `A (q1addq[28]) ? q1rd : q1addq;
		q2res	<= `A (q2addq[30]) ? q2rd : q2addq;
	end	
end
assign	oR		=	(iFSM_START == 2'b01) ? q1res : (iFSM_START == 2'b10) ? q2res : 'b0;
endmodule