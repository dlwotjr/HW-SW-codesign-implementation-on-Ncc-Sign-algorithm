//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-02-09 오후 4:09:05
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module TB_XXX_PWM_READ;

	`define R @(posedge iSYS_CLK)
	`define W @(posedge iSYS_CLK) #1
	`define RR(n) repeat(n) `R
	`define WW(n) repeat(n) `W

	parameter	PRM_DAXI		= 	64;
    parameter	PRM_ADDR		= 	12;
    parameter	PRM_DRAM		=	32;
    parameter	PRM_COEFFS		=	10;
    
// [CLOCK] definition
	reg iSYS_CLK = 1'b0;
	reg iSYS_RST = 1'b1;  // active low reset

// [CLOCK] gen clock (100 MHz, freq = 10 ns)
initial 
begin
	#100 iSYS_RST = 0;
	#100 iSYS_RST = 1;
	#100
	while(1) #5 iSYS_CLK = ~iSYS_CLK; // #5 means 100 MHz clock period	
end
    reg						iFSM_START;
    wire					oFSM_DONE;
    reg						iRs_Tvalid;
    reg		[PRM_DAXI-1:0]	iRs_Tdata;
    wire					oRs_Tready;
    			         
    wire					oB1_enA;
    wire					oB1_weA; 
    wire	[PRM_ADDR-1:0]	oB1_addrA;
    wire	[PRM_DRAM-1:0]	oB1_dinA;
    wire					oB1_enB; 
    wire					oB1_weB; 
    wire	[PRM_ADDR-1:0]	oB1_addrB;
    wire	[PRM_DRAM-1:0]	oB1_dinB;
    
    // test params
    integer cnt_i;
	
	reg [63:0] DATA1 [0:2048];

// [TEST] 
initial
begin
    
    for (cnt_i = 0; cnt_i < 2048; cnt_i = cnt_i + 1) 
	begin
		DATA1[cnt_i] = cnt_i<<32 | cnt_i;
	end	
    
	#500;	
	// test start
	begin $display("%12d:OOO: [TEST]: START----------------------------------",$time); end
	begin $display("%12d:OOO: [TEST]: trasfer--------------------------------",$time); end
	`W iRs_Tvalid = 1'b0;
	`W iRs_Tdata  = 64'd0;
	`W iFSM_START  = 1'b0;
	`W iFSM_START  = 1'b1;
			
	// transfer start
	begin $display("%12d:OOO: [TEST]: trasfer start--------------------------",$time); end
	for (cnt_i = 0; cnt_i < 2048; cnt_i = cnt_i + 1) 
	begin
		`W iFSM_START  = 1'b0; iRs_Tvalid = 1; 	iRs_Tdata = DATA1[cnt_i];
	end		
		
	// transfer end
	begin $display("%12d:OOO: [TEST]: trasfer end----------------------------",$time); end
	`W iRs_Tvalid = 0; 		iRs_Tdata = 64'd0;
     
    // test end
	#2000;
	$display("%12d:====================================================",$time);
	$display("%12d:OOO:ALL TEST OK & FINISH----------------------------",$time);
	$display("sadfasdfasdf");
	$stop;

end

	MDL_XXX_PWM_READ uut_PWM_READ
	(
		.iSYS_CLK			(iSYS_CLK		),
		.iSYS_RST			(iSYS_RST		),
		
		.iFSM_START			(iFSM_START		),
		.oFSM_DONE			(oFSM_DONE		),
		
		.iRs_Tvalid			(iRs_Tvalid		),
		.iRs_Tdata			(iRs_Tdata		),
		.oRs_Tready			(oRs_Tready		),
		
		.oB1_enA			(oB1_enA		),
		.oB1_weA			(oB1_weA		),
		.oB1_addrA			(oB1_addrA		),
		.oB1_dinA			(oB1_dinA		),  
		.oB1_enB			(oB1_enB		),
		.oB1_weB			(oB1_weB		),
		.oB1_addrB			(oB1_addrB		),
		.oB1_dinB			(oB1_dinB		)
	);
    
endmodule