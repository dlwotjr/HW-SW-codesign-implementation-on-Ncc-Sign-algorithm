//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-04-10 오후 3:25:24
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module MDL_BDY#
(
    parameter	PRM_ADDR	= 	12,
    parameter	PRM_COEFFS	=	4096
)
(
	input	wire        	iSYS_CLK,
	input	wire        	iSYS_RST,

	// Control Signal
	input	wire	[2:0]	iCTL_MODE,
	//user control signal
	input	wire	[1:0]	iCTL_BUT,
	input	wire	[1:0]	iCTL_Q,
	input	wire	[3:0]	iCTL_NTTDepth,

	// DMA write read_data to slave port
	input	wire        	iS_AXIS_TVALID,
	output	wire        	oS_AXIS_TREADY,
	input	wire	[63:0] 	iS_AXIS_TDATA,
	input	wire	[7:0]  	iS_AXIS_TKEEP,
	input	wire        	iS_AXIS_TLAST,

	// Send computed data to DMA via master port
	output	wire        	oM_AXIS_TVALID,
	
	input	wire        	iM_AXIS_TREADY,
	output	wire	[63:0] 	oM_AXIS_TDATA,
	output	wire	[7:0]  	oM_AXIS_TKEEP,
	output	wire        	oM_AXIS_TLAST
);

localparam	PRM_DAXI		=	64;
localparam	PRM_DRAM		=	32;
//localparam	PRM_DEPTH		=	30;		//todo testdepth
localparam	PRM_DKEEP		=	8;
localparam	PRM_KEEP		=	8'hFF;
//localparam 	PRM_KDEPTH		=	5;


// [params]--fsm------------------------------------------------------------------
wire		FSM_BUT;		// PWMQ1 start and working signal
wire		FSM_BUT_done; // PWMQ1 done signal
wire 		FSM_KECCAK;		// Keccak start and working signal
wire		FSM_KECCAK_done;// Keccak done signal

//wire		FSM_START;		// Module Start signal
wire					FSM_BUT_START;
wire					FSM_KECCAK_START;

// [params]--two fifos-------------------------------------------------------------
wire        			Rm_Tvalid, 	Ws_Tvalid,	Rm_Tready,	Ws_Tready;
wire	[PRM_DAXI-1:0]	Rm_Tdata,	Ws_Tdata;
wire	[PRM_DKEEP-1:0]	Rm_Tkeep,	Ws_Tkeep;
wire        			Rm_Tlast,	Ws_Tlast;
assign	Rm_Tkeep	=	PRM_KEEP; // always
assign	Ws_Tkeep	=	PRM_KEEP; // always

// [params]--two brams-------------------------------------------------------------
wire					B1_enA,		B1_enB,		B1_weA,		B1_weB;
wire	[PRM_ADDR-1:0]	B1_addrA,	B1_addrB; 
wire	[PRM_DRAM-1:0]	B1_dinA,	B1_dinB,	B1_doutA,	B1_doutB;

wire					B2_enA,		B2_enB,		B2_weA,		B2_weB;
wire	[PRM_ADDR-1:0]	B2_addrA,	B2_addrB; 
wire	[PRM_DRAM-1:0]	B2_dinA,	B2_dinB,	B2_doutA,	B2_doutB;
//   
// [params]
//    assign	Ws_Tvalid = (state == STATE_TRANSFER) ? Rm_Tvalid : 1'b0;
//    assign	Ws_Tdata = Rm_Tdata;    
//    assign	Ws_Tlast = Rm_Tlast;
//    assign	Rm_Tready = (state == STATE_TRANSFER);

	MDL_FSM ins_FSM
	(
		.iSYS_CLK				(iSYS_CLK			),
		.iSYS_RST				(iSYS_RST			),                       
		.iFSM_MODE				(iCTL_MODE			),
		.iFSM_KECCAK_DONE		(FSM_KECCAK_done	),
		.iFSM_BUT_DONE			(FSM_BUT_done		),
//		.oFSM_BUT				(FSM_BUT			),
//		.oFSM_KECCAK			(FSM_KECCAK			),
		.oFSM_BUT_START			(FSM_BUT_START		),
		.oFSM_KECCAK_START		(FSM_KECCAK_START	)
	);
	 
	MDL_XXX_FIFO ins_READ_FIFO 
	(
		.s_axis_aclk			(iSYS_CLK			),
		.s_axis_aresetn			(iSYS_RST			),
		
		.s_axis_tvalid			(iS_AXIS_TVALID		),
		.s_axis_tready			(oS_AXIS_TREADY		),
		.s_axis_tdata			(iS_AXIS_TDATA		),
		.s_axis_tkeep			(iS_AXIS_TKEEP		),   
		.s_axis_tlast			(iS_AXIS_TLAST		),
		
		.m_axis_tvalid			(Rm_Tvalid			),		
		.m_axis_tready			(Rm_Tready			),
		.m_axis_tdata			(Rm_Tdata			),
		.m_axis_tkeep			(Rm_Tkeep			),
		.m_axis_tlast			(Rm_Tlast			)
		
	);
	
	reg 						k_comp;
	
	always@(posedge iSYS_CLK)
	begin
		if(~iSYS_CLK) begin
			k_comp <= 1'b0;
		end
		else if(iCTL_MODE==3'b001) begin
			k_comp <= 1'b1;
		end
		else if(iCTL_MODE==3'b010) begin
			k_comp <= 1'b0;
		end
		else begin
			k_comp <= k_comp;
		end
	end	             
	wire	                    Rm_Tready_k,    Rm_Tready_b,		Ws_Tlast_b,	    	Ws_Tlast_k;
	wire	 [PRM_DAXI-1:0]     Ws_Tdata_k,     Ws_Tdata_b;	
	wire	                    Ws_Tvalid_k,    Ws_Tvalid_b;	
	
	assign 						Rm_Tready = k_comp? Rm_Tready_k : Rm_Tready_b;
	assign 						Ws_Tdata  = k_comp? Ws_Tdata_k  : Ws_Tdata_b;
	assign 						Ws_Tvalid = k_comp? Ws_Tvalid_k : Ws_Tvalid_b;
	assign 						Ws_Tlast  = k_comp? Ws_Tlast_k  : Ws_Tlast_b;
	             
	MDL_BDY_KECCAK  ins_keccak
	(
	    .iSYS_CLK				(iSYS_CLK			),
	    .iSYS_RST				(iSYS_RST			),
        
	    .iFSM_START				(FSM_KECCAK_START	),
	    .oFSM_DONE				(FSM_KECCAK_done	),
	    
	    .iRs_Tvalid				(Rm_Tvalid			),
	    .oRs_Tready				(Rm_Tready_k		),
	    .iRs_Tdata				(Rm_Tdata			),
	    .iRs_Tlast				(Rm_Tlast			),
	    
	    .oWm_Tvalid				(Ws_Tvalid_k		),
	    .iWm_Tready				(Ws_Tready			),
	    .oWm_Tdata				(Ws_Tdata_k			),
	    .oWm_Tlast				(Ws_Tlast_k			)
	);


	MDL_BDY_BUT	#(PRM_DAXI, PRM_ADDR, PRM_DRAM, PRM_COEFFS
	) ins_BUT
	(
		.iSYS_CLK				(iSYS_CLK			),
		.iSYS_RST				(iSYS_RST			),
		
		.iFSM_START				(FSM_BUT_START		),
		.iCTL_Q					(iCTL_Q				),
		.iCTL_BUT				(iCTL_BUT			),
		.iCTL_NTTDepth			(iCTL_NTTDepth		),
		.oFSM_DONE				(FSM_BUT_done		),
		
		.iRs_Tvalid				(Rm_Tvalid			),
		.oRs_Tready				(Rm_Tready_b		),
		.iRs_Tdata				(Rm_Tdata			),
		.iRs_Tlast				(Rm_Tlast			),
		
		.oWm_Tvalid				(Ws_Tvalid_b		),
		.iWm_Tready				(Ws_Tready			),
		.oWm_Tdata				(Ws_Tdata_b			),
		.oWm_Tlast				(Ws_Tlast_b			)
	);
		

//	MDL_XXX_FIFO  ins_WRITE_FIFO
//	(
//		.s_axis_aclk			(iSYS_CLK			),
//		.s_axis_aresetn			(iSYS_RST			),
//		                    
//		.s_axis_tvalid			(Ws_Tvalid			),
//		.s_axis_tready			(Ws_Tready			),
//		.s_axis_tdata			(Ws_Tdata			),
//		.s_axis_tkeep			(Ws_Tkeep			),
//		.s_axis_tlast			(Ws_Tlast			),
//			
//		.m_axis_tvalid			(oM_AXIS_TVALID		),		
//		.m_axis_tready			(iM_AXIS_TREADY		),
//		.m_axis_tdata			(oM_AXIS_TDATA		),
//		.m_axis_tkeep			(oM_AXIS_TKEEP		),
//		.m_axis_tlast			(oM_AXIS_TLAST		)
//		
//	);
	//FOR TESTBENCH
		MDL_XXX_FIFO  ins_WRITE_FIFO
	(
		.s_axis_aclk			(iSYS_CLK			),
		.s_axis_aresetn			(iSYS_RST			),
		                    
		.s_axis_tvalid			(Ws_Tvalid			),
		.s_axis_tready			(Ws_Tready			),
		.s_axis_tdata			(Ws_Tdata			),
		.s_axis_tkeep			(Ws_Tkeep			),
		.s_axis_tlast			(Ws_Tlast			),
			
		.m_axis_tvalid			(oM_AXIS_TVALID		),		
		.m_axis_tready			(iM_AXIS_TREADY		),
		.m_axis_tdata			(oM_AXIS_TDATA		),
		.m_axis_tkeep			(oM_AXIS_TKEEP		),
		.m_axis_tlast			(oM_AXIS_TLAST		)
		
	);

endmodule