//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-02-09 오후 4:09:05
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module TB_BDY_BUF_PWM;

	`define R @(posedge iSYS_CLK)
	`define W @(posedge iSYS_CLK) #1
	`define RR(n) repeat(n) `R
	`define WW(n) repeat(n) `W

	parameter	PRM_DAXI		= 	64;
    parameter	PRM_ADDR		= 	12;
    parameter	PRM_DRAM		=	32;
    parameter	PRM_COEFFS		=	64;
    
// [CLOCK] definition
	reg iSYS_CLK = 1'b0;
	reg iSYS_RST = 1'b1;  // active low reset

// [CLOCK] gen clock (100 MHz, freq = 10 ns)
initial 
begin
	while(1) #5 iSYS_CLK = ~iSYS_CLK; // #5 means 100 MHz clock period	
end

    reg			[1:0]			iCTL_BUT;	// 0 : PWM(sel = 0), 1: NTT(sel = 0) , 2 : INTT(sel = 1)
    reg							iFSM_START;
    reg			[1:0]			iCTL_Q;		//	0 : Q1, 1: Q2
    //reg			[4:0]			iCTL_NTT_Depth;
    wire						oFSM_DONE;
    
    reg							iRs_Tvalid;
    wire						oRs_Tready;
    reg			[PRM_DAXI-1:0]	iRs_Tdata;
    reg							iRs_Tlast;
    
    wire						oWm_Tvalid;
    reg							iWm_Tready;
    wire		[PRM_DAXI-1:0]	oWm_Tdata;
    wire						oWm_Tlast;
    
    // test params
    integer cnt_i;
	
	reg [63:0] DATA1 [0:PRM_COEFFS/2+PRM_COEFFS-1];

// [TEST] 
initial
begin
	#100 iSYS_RST = 0;
	#100 iSYS_RST = 1;
    
    for (cnt_i = 1; cnt_i < PRM_COEFFS/2+1; cnt_i = cnt_i + 1) 
	begin
		DATA1[cnt_i-1] = cnt_i<<(PRM_DAXI/2) | cnt_i;
	end	
	for (cnt_i = PRM_COEFFS/2+1; cnt_i < PRM_COEFFS/2+PRM_COEFFS+1; cnt_i = cnt_i + 1) 
	begin
		DATA1[cnt_i-1] = cnt_i;
	end	
    
	#500;	
	// test start
	begin $display("%12d:OOO: [TEST]: START----------------------------------",$time); end
	begin $display("%12d:OOO: [TEST]: trasfer--------------------------------",$time); end
	`W iRs_Tvalid = 1'b0; iRs_Tlast  = 1'd0; iRs_Tdata  = 64'd0; iFSM_START  = 1'b0; iCTL_Q = 2'b0; iWm_Tready = 1; iCTL_BUT=0;
	`W iFSM_START  = 1'b1;
			
	// transfer start
	begin $display("%12d:OOO: [TEST]: trasfer start--------------------------",$time); end
	for (cnt_i = 0; cnt_i < PRM_COEFFS/2+PRM_COEFFS; cnt_i = cnt_i + 1) 
	begin
		`W iRs_Tvalid = 1; 	iRs_Tdata = DATA1[cnt_i];
		if (cnt_i == PRM_COEFFS/2+PRM_COEFFS-1)	iRs_Tlast = 1; 
		else				iRs_Tlast = 0;
	end		
	`W iRs_Tvalid = 0;
	
     
    // test end
	#300;
	$display("%12d:====================================================",$time);
	$display("%12d:OOO:ALL TEST OK & FINISH----------------------------",$time);
	$stop;

end

	MDL_BDY_BUT_PWM 		#(
		.PRM_DAXI			(PRM_DAXI		),
		.PRM_ADDR			(PRM_ADDR		),
		.PRM_DRAM			(PRM_DRAM		),
		.PRM_COEFFS			(PRM_COEFFS		)
	) uut_BDY_BUT_PWM
	(
		.iSYS_CLK			(iSYS_CLK		),
		.iSYS_RST			(iSYS_RST		),
		
		.iFSM_START			(iFSM_START		),
		.iCTL_BUT			(iCTL_BUT		),
		.iCTL_Q				(iCTL_Q			),
		.oFSM_DONE			(oFSM_DONE		),
		
		.iRs_Tvalid			(iRs_Tvalid		),
		.oRs_Tready			(oRs_Tready		),
		.iRs_Tdata			(iRs_Tdata		),
		.iRs_Tlast			(iRs_Tlast		),  
		.oWm_Tvalid			(oWm_Tvalid		),
		.iWm_Tready			(iWm_Tready		),
		.oWm_Tdata			(oWm_Tdata		),
		.oWm_Tlast			(oWm_Tlast		)
	);
    
endmodule