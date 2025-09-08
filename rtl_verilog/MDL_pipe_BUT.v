//============================================================================
//
//  AUTHOR      : YoungBeom Kim, JaeSeok Lee and Seog Chung Seo
//  SPEC        : BFU Pipeline Implementation
//  HISTORY     : 2025-04-15 ¿ÀÈÄ 12:23:09
//
//      Copyright (c) 2025 Crypto & Security Engineering Laboratory. MIT license
//
//============================================================================

`include "./timescale.vh"

module MDL_pipe_BUT #(
	parameter D		= 30
)
(
    input  	wire          	iSYS_CLK	,
    input 	wire			iSYS_RST	,
    input	wire			iFSM_START	,
    input  	wire          	iCTL_SEL	, // 0: NTT, 1: INTT iCTL_SEL
    input	wire  [1:0]		iCTL_Q		,
    input  	wire  [D-1:0] 	iA			,
    input  	wire  [D-1:0] 	iB			,
    input  	wire  [D-1:0] 	iW			,
    output 	   	  [D-1:0] 	oA			,
    output 	      [D-1:0] 	oB		
);
	localparam 	integer		D1 			= 28;
	localparam 	[D-1:0] 	PRM_Q1 		= 30'd134250497;
	localparam 	[D-1:0] 	PRM_Q2 		= 30'd536903681;
	wire    	[D-1:0]   	PRM_Q  		= (iCTL_Q==2'd1) ? PRM_Q2 : PRM_Q1;
	//(Q+1)/2
	localparam 	[D-1:0] 	GS_VAL1 	= (PRM_Q1 + 1) >> 1;
	localparam 	[D-1:0] 	GS_VAL2 	= (PRM_Q2 + 1) >> 1;
	wire		[D-2:0]		gs_val		= iCTL_Q ? GS_VAL2 : GS_VAL1;
//	wire					iFSM_START_Q1 = iFSM_START && (iCTL_Q==0);
//	wire					iFSM_START_Q2 = iFSM_START && (iCTL_Q==1);
	
	wire 		[D1-1:0] 	mul_result1;
	wire 		[D-1:0] 	mul_result2;
	wire 		[D-1:0] 	mul_result 	= iCTL_Q ? mul_result2 : mul_result1;
	
    // Internal Wires and Registers    
    wire signed [D:0] 		itl_temp_sub;
    wire 		[D-1:0] 	itl_temp_mod;
    wire  		[D-1:0] 	itl_final;
    
    // Subtraction and Modular Reduction
    assign itl_temp_sub = iA - iB;
    assign itl_temp_mod = itl_temp_sub[D] ? (itl_temp_sub + PRM_Q) : itl_temp_sub;
    assign itl_final 	= (iCTL_SEL) ? itl_temp_mod : iB;
    
    reg 		[D-1:0]		A0;
    reg 		[D-1:0]		A1;
    reg 		[D-1:0]		A2;
    reg 		[D-1:0]		A3;
    reg 		[D-1:0]		A4;
    reg 		[D-1:0]		A5;
    reg 		[D-1:0]		A6;

    reg 		[D-1:0]		B0;
    reg 		[D-1:0]		B1;
    reg 		[D-1:0]		B2;
    reg 		[D-1:0]		B3;
    reg 		[D-1:0]		B4;
    reg 		[D-1:0]		B5;
    reg 		[D-1:0]		B6;
        
    always@(posedge iSYS_CLK)
	    if (!iSYS_RST) 
		    begin
		    	A0  			<=	`A	{D{1'b0}};
		    	A1          	<=  `A	{D{1'b0}};
		    	A2          	<=  `A 	{D{1'b0}};
		    	A3          	<=  `A 	{D{1'b0}};
		    	A4          	<=  `A 	{D{1'b0}};
		    	A5          	<=  `A 	{D{1'b0}};
		    	A6          	<=  `A 	{D{1'b0}};
		    	B0				<=	`A	{D{1'b0}};
		    	B1				<=  `A	{D{1'b0}};
		    	B2				<=  `A 	{D{1'b0}};
		    	B3				<=  `A 	{D{1'b0}};
		    	B4				<=  `A 	{D{1'b0}};
		    	B5				<=  `A 	{D{1'b0}};
		    	B6				<=  `A 	{D{1'b0}};
		    	//W0			<=	`A 	'b0;
		    end 
	    else if (iFSM_START)
		    begin
		        A0  		<=	`A	iA;
		    	A1          <=  `A	A0;
		    	A2          <=  `A 	A1;
		    	A3          <=  `A 	A2;
		    	A4          <=  `A 	A3;
		    	A5          <=  `A 	A4;
		    	A6          <=  `A 	A5;
		    	B0			<=	`A	iB;
		    	B1			<=  `A	B0;
		    	B2			<=  `A 	B1;
		    	B3          <=  `A 	B2;
		    	B4          <=  `A 	B3;
		    	B5          <=  `A 	B4;
		    	B6          <=  `A 	B5;

		    	//W0			<=	`A 	iW;
		    	//W1			<=	`A 	W0;
		    end 
    
	// Modular Multiplication    
    wire	[D-1:0]	res_modmul;
    wire	[1:0]	FSM_MODMUL;
    assign	FSM_MODMUL	=	(iFSM_START == 1 && iCTL_Q == 0) ? 2'b01	:
    						(iFSM_START == 1 && iCTL_Q == 1) ? 2'b10	: 0;
    
    MDL_MODMUL modmul_ins
    (
        .iSYS_CLK	(iSYS_CLK		),
        .iSYS_RST	(iSYS_RST		),
        .iFSM_START	(FSM_MODMUL		),
        .iA			(itl_final		), 
        .iB			(iW				),
        .oR			(res_modmul		)
    );
    
    assign	mul_result1 = res_modmul[D1-1:0];
	assign	mul_result2 = res_modmul;
    
    // BFU Addition and Subtractiona
    wire 		[D-1:0] 	bfu_add_temp;
    wire 		[D:0]   	bfu_add_sum;
    wire 		[D-1:0] 	bfu_add_mod;
    wire 		[D-1:0] 	bfu_add_final;    
    
    assign bfu_add_temp  = (iCTL_SEL) ? B6 : mul_result;
    assign bfu_add_sum   = A6 + bfu_add_temp;
    assign bfu_add_mod   = (bfu_add_sum >= PRM_Q) ? (bfu_add_sum - PRM_Q) : bfu_add_sum;
    assign bfu_add_final = (bfu_add_mod[0]) ? (bfu_add_mod[D-1:1] + gs_val) : bfu_add_mod[D-1:1];
    
    wire signed [D:0] 		bfu_sub_diff;
    wire 		[D-1:0] 	bfu_sub_mod;
    wire 		[D-1:0] 	bfu_sub_final;
    
    assign bfu_sub_diff  = (iCTL_SEL) ? mul_result : A6 - mul_result;
    
    assign bfu_sub_mod   = bfu_sub_diff[D] 	? (bfu_sub_diff + PRM_Q) : bfu_sub_diff;
    // process of divide 2
    // if even number : just shift
    // if  odd number : shift number + gs_val
    assign bfu_sub_final = bfu_sub_mod[0]	? (bfu_sub_mod[D-1:1] + gs_val) : bfu_sub_mod[D-1:1]; 
    
    // Final Computation and Output Assignment
    
    reg   [D-1:0] 	res_oA;
    reg   [D-1:0] 	res_oB;	
    always@(posedge iSYS_CLK)
	    if (!iSYS_RST) 
		    begin
		    	//itl_final	<= 	`A	'b0;
		    	res_oA		<= 	`A	{D{1'b0}};
		    	res_oB		<= 	`A 	{D{1'b0}};
		    end 
	    else if (iFSM_START)
		    begin
		        //itl_final 	<=  `A 	(iCTL_SEL) ? itl_temp_mod : iB;
		        res_oA      <=  `A 	(iCTL_SEL) ? bfu_add_final : bfu_add_mod;
		        res_oB      <=  `A 	(iCTL_SEL) ? bfu_sub_final : bfu_sub_mod;
		    end 
		    
	assign oA = res_oA;
	assign oB = res_oB;
	
endmodule