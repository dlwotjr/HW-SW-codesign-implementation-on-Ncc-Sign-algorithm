//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-02-09 오후 4:09:05
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module TB_BDY_PWM_4c;

	`define R @(posedge iSYS_CLK)
	`define W @(posedge iSYS_CLK) #1
	`define RR(n) repeat(n) `R
	`define WW(n) repeat(n) `W

	parameter	PRM_DAXI		= 	64;
    parameter	PRM_ADDR		= 	12;
    parameter	PRM_DRAM		=	32;
    parameter	PRM_COEFFS		=	4096;
    
// [CLOCK] definition
	reg iSYS_CLK = 1'b0;
	reg iSYS_RST = 1'b1;  // active low reset

// [CLOCK] gen clock (100 MHz, freq = 10 ns)
initial 
begin
	while(1) #5 iSYS_CLK = ~iSYS_CLK; // #5 means 100 MHz clock period	
end

    reg			[2:0]			iFSM_MODE;	// 0 : PWM(sel = 0), 1: NTT(sel = 0) , 2 : INTT(sel = 1)
    reg							iFSM_START;
    reg			[1:0]			iCTL_Q;		//	0 : Q1, 1: Q2
    reg			[2:0]			iCTL_MODE;	
     reg		[1:0]			iCTL_BUT;	
    reg			[4:0]			iCTL_NTT_Depth;
    
    reg				iS_AXIS_TVALID = 1'b0;
    wire			oS_AXIS_TREADY;
    reg		[63:0]	iS_AXIS_TDATA  = 64'd0;
    reg		[7:0]	iS_AXIS_TKEEP  = 8'hFF;
    reg				iS_AXIS_TLAST  = 1'b0;
    
	// AXI master signal
    wire			oM_AXIS_TVALID;
    
    reg				iM_AXIS_TREADY = 1'b1;
    wire	[63:0]	oM_AXIS_TDATA;
    wire	[7:0]	oM_AXIS_TKEEP;
    wire			oM_AXIS_TLAST;
    
    // test params
    integer cnt_i;
	
	reg [63:0] DATA1 [0:PRM_COEFFS];

// [TEST] 
initial
begin
	#100 iSYS_RST = 0;
	#100 iSYS_RST = 1;
    
    for (cnt_i = 1; cnt_i < PRM_COEFFS+1; cnt_i = cnt_i + 1) 
	begin
		DATA1[cnt_i-1] = cnt_i<<(PRM_DAXI/2) | cnt_i;
	end	
    
	#500;	
	// test start
	begin $display("%12d:OOO: [TEST]: START----------------------------------",$time); end
	begin $display("%12d:OOO: [TEST]: trasfer--------------------------------",$time); end
	`W iCTL_MODE = 'b0;
	`W iS_AXIS_TVALID = 1'b0;
	`W iS_AXIS_TDATA  = 64'd0;
	`W iS_AXIS_TKEEP  = 8'hFF;
	`W iS_AXIS_TLAST  = 1'b0;
	`W iM_AXIS_TREADY = 1'b1; //always ready because of simulation
	`W iCTL_Q		  = 1'b1; 
			
	// transfer start
	begin $display("%12d:OOO: [TEST]: trasfer start--------------------------",$time); end
	for (cnt_i = 0; cnt_i < PRM_COEFFS; cnt_i = cnt_i + 1) 
	begin
		`W iS_AXIS_TVALID = 1; 	iS_AXIS_TDATA = DATA1[cnt_i];  iS_AXIS_TKEEP  = 8'hFF;          
		if (cnt_i == PRM_COEFFS-1)		iS_AXIS_TLAST = 1;
		else										iS_AXIS_TLAST = 0;
	end	
	
	`W iCTL_MODE = 3'd3; iS_AXIS_TLAST = 0; 	iS_AXIS_TDATA = 64'd0; iS_AXIS_TVALID = 0; iCTL_BUT = 2'b0;
	`W iCTL_MODE = 3'd0;
		
	// transfer end
	begin $display("%12d:OOO: [TEST]: trasfer end----------------------------",$time); end
	`W iS_AXIS_TVALID = 0; 		iS_AXIS_TDATA = 64'd0;
	
     
    // test end
	#50000;
	$display("%12d:====================================================",$time);
	$display("%12d:OOO:ALL TEST OK & FINISH----------------------------",$time);
	$stop;

end

	MDL_BDY uut_bdy
	(
		.iSYS_CLK			(iSYS_CLK			),
		.iSYS_RST			(iSYS_RST			),
		
		.iCTL_MODE			(iCTL_MODE			),
		.iCTL_BUT			(iCTL_BUT			),
		.iCTL_Q				(iCTL_Q				),
		
		.iS_AXIS_TVALID		(iS_AXIS_TVALID		),
		.oS_AXIS_TREADY		(oS_AXIS_TREADY		),
		.iS_AXIS_TDATA		(iS_AXIS_TDATA		),
		.iS_AXIS_TKEEP		(iS_AXIS_TKEEP		),
		.iS_AXIS_TLAST		(iS_AXIS_TLAST		),
		
		.oM_AXIS_TVALID		(oM_AXIS_TVALID		),
		.iM_AXIS_TREADY		(iM_AXIS_TREADY		),
		.oM_AXIS_TDATA		(oM_AXIS_TDATA		),
		.oM_AXIS_TKEEP		(oM_AXIS_TKEEP		),
		.oM_AXIS_TLAST		(oM_AXIS_TLAST		)
	);
    
    
endmodule