	//============================================================================
	//
	//  AUTHOR      : YoungBeom Kim
	//  SPEC        :
	//  HISTORY     : 2024-11-13 오후 8:14:22
	//
	//      Copyright (c) 2024 Crypto & Security Engineering Laboratory. MIT license
	//
	//============================================================================

	//! time definition
	`include "./timescale.vh"
	module TB_BUT_ALL_Q1;

	//`define DFN_MODMULQ1_WIRE
	//`define DFN_MODMULQ2_WIRE

	//`define DFN_BUF_CT
	//`define DFN_BUF_GS
	`define DFN_BUF_PWM
	
	parameter	D	= 28;
	parameter	Q	= 134250497;

	// CT 모드: oR1 = (a + b·z) % q, oR2 = (a – b·z) % q
	task TSK_BUT_CT(
		output reg [D-1:0] oR1,
		output reg [D-1:0] oR2,
		input  [D-1:0]     iA,
		input  [D-1:0]     iB,
		input  [D-1:0]     iZ,
		input  [D-1:0]     iQ
	);
		reg [2*D-1:0] imm;
		reg [D-1:0]   res;
		reg [D:0]     tmp;
		begin
			// b·z mod q
			imm  = iB * iZ;
			res  = imm % iQ;
			// oR1 = (a + res) mod q
			tmp  = iA + res;
			oR1  = tmp % iQ;
			// oR2 = (a – res) mod q  (음수 방지 위해 +iQ)
			oR2  = (iA + iQ - res) % iQ;
		end
	endtask

	// GS 모드: oR1 = ((a + b)/2) % q, oR2 = (((a – b)·z)/2) % q
	task TSK_BUT_GS(
		output reg [D-1:0] oR1,
		output reg [D-1:0] oR2,
		input  [D-1:0]     iA,
		input  [D-1:0]     iB,
		input  [D-1:0]     iZ,
		input  [D-1:0]     iQ
	);
		reg [D:0]     sum_ab;
		reg signed[D:0] diff_ab;
		reg [2*D-1:0] imm;
		reg [D:0]     half_sum;
		reg [D:0]     half_prod;
		begin
			// (a + b) / 2 mod q
			sum_ab   = iA + iB;
			half_sum = sum_ab >> 1;
			// 홀수인 경우 모듈러 보정을 하고 싶으면 아래처럼 추가
			if (sum_ab[0]) half_sum = (half_sum + ((iQ+1)>>1)) % iQ;
			oR1      = half_sum % iQ;

			// ((a - b) * z) / 2 mod q
			// 음수 처리: diff_ab = a - b + q
			diff_ab  = iA + iQ - iB;
			imm      = (diff_ab * iZ)%iQ;
			half_prod= imm >> 1;
			if (imm[0]) half_prod = (half_prod + ((iQ+1)>>1)) % iQ;
			oR2      = half_prod % iQ;
		end
	endtask

	// Point‑wise Mul 모드: oR = (b·z) % q
	task TSK_BUT_PWM(
		output reg [D-1:0] oR,
		input  [D-1:0]     iB,
		input  [D-1:0]     iZ,
		input  [D-1:0]     iQ
	);
		reg [2*D-1:0] imm;
		begin
			imm = iB * iZ;
			oR  = imm % iQ;
		end
	endtask

	// clock definition & gen clock (100 MHz, freq = 10 ns)
	reg					iSYS_CLK    = 1'b0;
	reg					iSYS_RST    = 1'b1;		    
	    	     
	initial 
	begin
		#100 iSYS_RST = 0;
		#100 iSYS_RST = 1;
		#100
		while(1) #5 iSYS_CLK = ~iSYS_CLK; // #5 means 100 MHz clock period
	end

	`define R @(posedge iSYS_CLK)
	`define W @(posedge iSYS_CLK) #1
	`define RR(n) repeat(n) `R
	`define WW(n) repeat(n) `W

	// control-signal definition
	reg      			iFSM_START_CT  = 1'b0,
				        iFSM_START_GS  = 1'b0,
				        iFSM_START_PWM = 1'b0;

	reg 				sel 		= 'b0;
	reg    				iCTL_Q		= 'b0;
	
	reg [2*D-1:0] tmp_int;

	// data input
	reg		[D-1:0]	iQ1			= 'b0;	
	reg		[D-1:0]	iA1			= 'b0;
	reg		[D-1:0]	iB1			= 'b0;
	reg		[D-1:0]	iW1			= 'b0;	
	reg		[D-1:0]	iA_CT [64:0];
	reg		[D-1:0]	iB_CT [64:0];
	reg		[D-1:0]	iW_CT [64:0];
	reg		[D-1:0]	iA_GS [64:0];
	reg		[D-1:0]	iB_GS [64:0];
	reg		[D-1:0]	iW_GS [64:0];
	reg		[D-1:0]	iB_PWM [64:0];
	reg		[D-1:0]	iW_PWM [64:0];
	
	// data output	
	wire 	[D-1:0]	oA_CT;
	wire 	[D-1:0]	oB_CT;
	wire 	[D-1:0]	oA_GS;
	wire 	[D-1:0]	oB_GS;
	wire 	[D-1:0]	oA_PWM;
	
	reg		[D-1:0]	oTSK32_A		= 'b0;   	
	reg		[D-1:0]	oTSK32_B		= 'b0;   	
	
	// other params definition
	integer cnt_i, cnt_j, start_iA, start_iB, end_iA, end_iB, offset;  

	initial begin
	    for (cnt_i = 0; cnt_i < 64; cnt_i = cnt_i + 1) begin
	        iA_CT[cnt_i] = 'b0;
	        iB_CT[cnt_i] = 'b0;
	        iW_CT[cnt_i] = 'b0;
	        iA_GS[cnt_i] = 'b0;
	        iB_GS[cnt_i] = 'b0;
	        iW_GS[cnt_i] = 'b0;
	        iB_PWM[cnt_i] = 'b0;
	        iW_PWM[cnt_i] = 'b0;
	    end
	end
	                        
	initial
	begin
		#500;	
		// test start	    
	    begin $display("%12d:OOO: TEST START-------------------------------------",$time); end	    	  

	`ifdef DFN_BUF_CT
		//	[28x28-bit Modular multiplication for Q1 (no pipeline)]==================================================================================================
		start_iA = 5; end_iA = 70;    
	    for (cnt_i = start_iA; cnt_i < end_iA; cnt_i = cnt_i + 1) begin
	        // _1) cnt_i * Q 을 넉넉히 계산
	        tmp_int        = cnt_i * Q;          
	        // _2) 나눗셈(32) → 모듈로(Q) → 28비트로 잘라서 저장
	        iA_CT[cnt_i]   = (tmp_int / 32) % Q;

	        tmp_int        = cnt_i * Q;
	        iB_CT[cnt_i]   = (tmp_int / 28) % Q;

	        tmp_int        = cnt_i * Q;
	        iW_CT[cnt_i]   = (tmp_int / 24) % Q;
	    end
	    
	    `W sel = 1'b0; iFSM_START_CT = 1'b1; iQ1 = Q;
	    for(cnt_i = start_iA; cnt_i < end_iA; cnt_i=cnt_i + 1)
		begin
			TSK_BUT_CT(oTSK32_A, oTSK32_B, iA_CT[cnt_i-5], iB_CT[cnt_i-5], iW_CT[cnt_i-5], iQ1);
			`W iA1 = iA_CT[cnt_i]; iB1 = iB_CT[cnt_i]; iW1 = iW_CT[cnt_i];
			if	(oA_CT !== oTSK32_A || oB_CT !== oTSK32_B) begin $display("%12d:XXX: input = (iA : %h, iB : %h, iW : %h , Q : %h)CT result = (%h, %h) answer :  (%h, %h)------", $time,iA_CT[cnt_i-5], iB_CT[cnt_i-5],iW_CT[cnt_i-5],iQ1, oA_CT, oB_CT, oTSK32_A, oTSK32_B); end	
		end		
		$display("%12d:OOO:CT WIRE Test--------------------------",$time);
		$stop;
	`endif

	`ifdef DFN_BUF_GS
		//	[28x28-bit Modular multiplication for Q2 (no pipeline)]==================================================================================================
		
		start_iA = 5; end_iA = 70;    
	    for (cnt_i = start_iA; cnt_i < end_iA; cnt_i = cnt_i + 1) begin
	        // _1) cnt_i * Q 을 넉넉히 계산
	        tmp_int        = cnt_i * Q;          
	        // _2) 나눗셈(32) → 모듈로(Q) → 28비트로 잘라서 저장
	        iA_GS[cnt_i]   = (tmp_int / 32) % Q;

	        tmp_int        = cnt_i * Q;
	        iB_GS[cnt_i]   = (tmp_int / 28) % Q;

	        tmp_int        = cnt_i * Q;
	        iW_GS[cnt_i]   = (tmp_int / 24) % Q;
	    end   
	    
	    `W sel = 1'b1; iFSM_START_GS = 1'b1; iQ1 = Q;
	    for(cnt_i = start_iA; cnt_i < end_iA; cnt_i=cnt_i + 1)
		begin
			TSK_BUT_GS(oTSK32_A, oTSK32_B, iA_GS[cnt_i-5], iB_GS[cnt_i-5], iW_GS[cnt_i-5], iQ1);
			`W iA1 = iA_GS[cnt_i]; iB1 = iB_GS[cnt_i]; iW1 = iW_GS[cnt_i];
			if	(oA_GS !== oTSK32_A || oB_GS !== oTSK32_B) begin $display("%12d:XXX: input = (iA : %h, iB : %h, iW : %h , Q : %h)CT result = (%h, %h) answer :  (%h, %h)------", $time,iA_GS[cnt_i-5], iB_GS[cnt_i-5],iW_GS[cnt_i-5],iQ1, oA_GS, oB_GS, oTSK32_A, oTSK32_B); end	
		end	
		$display("%12d:OOO:GS WIRE Test--------------------------",$time);
		$stop;
	`endif

	`ifdef DFN_BUF_PWM
		//	[28x28-bit Modular multiplication for Q1 (with pipeline, 3 cycles)]==================================================================================================
		start_iA = 5; end_iA = 70;    
	    for (cnt_i = start_iA; cnt_i < end_iA; cnt_i = cnt_i + 1) begin
	        tmp_int        = cnt_i * Q;
	        iB_PWM[cnt_i]   = (tmp_int / 28) % Q;

	        tmp_int        = cnt_i * Q;
	        iW_PWM[cnt_i]   = (tmp_int / 24) % Q;
	    end 
	    
	    `W sel = 1'b0; iFSM_START_PWM = 1'b1; iQ1 = Q;
	    for(cnt_i = start_iA; cnt_i < end_iA; cnt_i=cnt_i + 1)
		begin
			TSK_BUT_PWM(oTSK32_A, iB_PWM[cnt_i-5], iW_PWM[cnt_i-5], iQ1);
			`W iB1 = iB_PWM[cnt_i]; iW1 = iW_PWM[cnt_i];
			if	(oA_PWM !== oTSK32_A) begin $display("%12d:XXX:PWM PIPE = %h = %h * %h (expect %h) ------", $time, oA_PWM, iB_PWM[cnt_i-5], iW_PWM[cnt_i-5], oTSK32_A); end	
		end		
		
		$display("%12d:OOO:MDL_MODMULQ1 PIPE Test--------------------------",$time);
		$stop;
	`endif

		#500;
		$display("%12d:====================================================",$time);
		$display("%12d:OOO:ALL TEST OK & FINISH----------------------------",$time);
		$stop;

	end
	
	// DUT BUF CT mode
    MDL_pipe_BUF #(
    	.PARAM_Q(Q), 
    	.D(D)
    )
    uut_CT 
    (
        .iSYS_CLK	(iSYS_CLK		),
        .iSYS_RST	(iSYS_RST		),
        .iFSM_sel	(sel			),
        .iCTL_Q		(iCTL_Q			),
        .iFSM_START	(iFSM_START_CT	),
        .iA			(iA1			),
        .iB			(iB1			),
        .iW			(iW1			),
        .oA			(oA_CT			),
        .oB			(oB_CT			)
    );
    
    // DUT BUF GS mode
    MDL_pipe_BUF #(
    	.PARAM_Q(Q), 
    	.D(D)
    )
    uut_GS 
    (
        .iSYS_CLK	(iSYS_CLK		),
        .iSYS_RST	(iSYS_RST		),
        .iFSM_sel	(sel			),
        .iCTL_Q		(iCTL_Q			),
        .iFSM_START	(iFSM_START_GS	),
        .iA			(iA1			),
        .iB			(iB1			),
        .iW			(iW1			),
        .oA			(oA_GS			),
        .oB			(oB_GS			)
    );
    
    // DUT BUF PWM mode
    MDL_pipe_BUF #(
    	.PARAM_Q(Q), 
    	.D(D)
    )
    uut_PWM 
    (
        .iSYS_CLK	(iSYS_CLK		),
        .iSYS_RST	(iSYS_RST		),
        .iFSM_sel	(sel			),
        .iCTL_Q		(iCTL_Q			),
        .iFSM_START	(iFSM_START_PWM	),
        .iA			('b0			),
        .iB			(iB1			),
        .iW			(iW1			),
        .oA			(oA_PWM			)
    );
    
endmodule

