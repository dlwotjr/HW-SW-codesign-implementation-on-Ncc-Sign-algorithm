//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :
//  HISTORY     :  2025-04-10 ?˜¤?›„ 3:24:37
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

//top module for only SHAKE

module MDL#
(
    localparam 		PRM_DATA_WIDTH				= 32,
    localparam 		PRM_ADDR_WIDTH    			= 5,
    localparam 		PRM_ADDR				= 12,
    localparam 		PRM_COEFFS    			= 4096
)
(
    // Ports of Axi Slave Bus Interface S00_AXI
    input 	wire  								s00_axi_aclk,
    input 	wire  								s00_axi_aresetn,
    input 	wire	[PRM_ADDR_WIDTH-1 : 0] 		s00_axi_awaddr,
    input 	wire 	[2 : 0] 					s00_axi_awprot,
    input 	wire  								s00_axi_awvalid,
    output 	wire  								s00_axi_awready,
    input 	wire 	[PRM_DATA_WIDTH-1 : 0] 		s00_axi_wdata,
    input 	wire 	[(PRM_DATA_WIDTH/8)-1 : 0] 	s00_axi_wstrb,
    input 	wire  								s00_axi_wvalid,
    output 	wire  								s00_axi_wready,
    output 	wire 	[1 : 0] 					s00_axi_bresp,
    output 	wire  								s00_axi_bvalid,
    input 	wire  								s00_axi_bready,
    input 	wire 	[PRM_ADDR_WIDTH-1 : 0] 		s00_axi_araddr,
    input 	wire 	[2 : 0] 					s00_axi_arprot,
    input 	wire  								s00_axi_arvalid,
    output 	wire  								s00_axi_arready,
    output 	wire 	[PRM_DATA_WIDTH-1 : 0] 		s00_axi_rdata,
    output 	wire 	[1 : 0] 					s00_axi_rresp,
    output 	wire  								s00_axi_rvalid,
    input 	wire  								s00_axi_rready,
    
    //DMA write read_data to slave port
    input 	wire 								aresetn,
    input 	wire 								clk,
    input 	wire 								s_axis_tvalid,
    output 	wire 								s_axis_tready,
    input 	wire	[63:0] 						s_axis_tdata,
    input 	wire	[7:0] 						s_axis_tkeep,
    input 	wire 								s_axis_tlast,
    
    //Send computed data to DMA via master port
    output 	wire 								m_axis_tvalid,
    input 	wire 								m_axis_tready,
    output 	wire	[63:0] 						m_axis_tdata,
    output 	wire	[7:0] 						m_axis_tkeep,
    output 	wire 								m_axis_tlast
    );
    
    //control signal to operate SHAKE only
    wire			[2:0] 						CTL_MODE;
    wire			[1:0]						CTL_BUT;
    wire			[1:0]						CTL_Q;
    wire			[3:0]						CTL_NTTDepth;
//    wire			[1:0]						iHash_mode;	
//	wire			[31:0]						iHash_Rlen;	
//	wire			[9:0]						iHash_Wlen;	
//	wire										iHash_sel;	
//	wire										iHash_eta;	



    
	MDL_BDY  #(
	   .PRM_ADDR (PRM_ADDR),
	   .PRM_COEFFS (PRM_COEFFS)
	)ins_MDL_BDY(
	    .iSYS_RST     		(aresetn		),
	    .iSYS_CLK     		(clk			),
	    
	    // User Control Signal
	    .iCTL_MODE    		(CTL_MODE		),
	    .iCTL_BUT			(CTL_BUT		),
	    .iCTL_Q				(CTL_Q			),
	    .iCTL_NTTDepth		(CTL_NTTDepth	),
//	    .iHash_mode	    	(iHash_mode		),
//		.iHash_sel	    	(iHash_sel		),	
//		.iHash_eta	    	(iHash_eta		),	
//		.iHash_Wlen	    	(iHash_Wlen		),
//	    .iHash_Rlen	    	(iHash_Rlen		),
	    
	    // DMA write read_data to slave port
	    .iS_AXIS_TVALID 	(s_axis_tvalid	),
	    .oS_AXIS_TREADY 	(s_axis_tready	),
	    .iS_AXIS_TDATA  	(s_axis_tdata	),
	    .iS_AXIS_TKEEP  	(s_axis_tkeep	),
	    .iS_AXIS_TLAST  	(s_axis_tlast	),
	    
	    // Send computed data to DMA via master port
	    .oM_AXIS_TVALID 	(m_axis_tvalid	),
	    .iM_AXIS_TREADY 	(m_axis_tready	),
	    .oM_AXIS_TDATA  	(m_axis_tdata	),
	    .oM_AXIS_TKEEP  	(m_axis_tkeep	),
	    .oM_AXIS_TLAST  	(m_axis_tlast	)
	);
                            
    MDL_CTL ins_AXI_CTL 
    (
	    .oCTL_MODE			(CTL_MODE			),
	    .oCTL_BUT			(CTL_BUT			),
	    .oCTL_Q				(CTL_Q				),
	    .oCTL_NTTDepth		(CTL_NTTDepth		),
//		.oHash_mode	    	(iHash_mode			),  
//		.oHash_Rlen	    	(iHash_Rlen			),  
//		.oHash_Wlen	    	(iHash_Wlen			),  
//		.oHash_sel	    	(iHash_sel			),	
//	    .oHash_eta	    	(iHash_eta			),	
	    
	    .S_AXI_ACLK			(s00_axi_aclk		),
	    .S_AXI_ARESETN		(s00_axi_aresetn	),
	    .S_AXI_AWADDR		(s00_axi_awaddr		),
	    .S_AXI_AWPROT		(s00_axi_awprot		),
	    .S_AXI_AWVALID		(s00_axi_awvalid	),
	    .S_AXI_AWREADY		(s00_axi_awready	),
	    .S_AXI_WDATA		(s00_axi_wdata		),
	    .S_AXI_WSTRB		(s00_axi_wstrb		),
	    .S_AXI_WVALID		(s00_axi_wvalid		),
	    .S_AXI_WREADY		(s00_axi_wready		),
	    .S_AXI_BRESP		(s00_axi_bresp		),
	    .S_AXI_BVALID		(s00_axi_bvalid		),
	    .S_AXI_BREADY		(s00_axi_bready		),
	    .S_AXI_ARADDR		(s00_axi_araddr		),
	    .S_AXI_ARPROT		(s00_axi_arprot		),
	    .S_AXI_ARVALID		(s00_axi_arvalid	),
	    .S_AXI_ARREADY		(s00_axi_arready	),
	    .S_AXI_RDATA		(s00_axi_rdata		),
	    .S_AXI_RRESP		(s00_axi_rresp		),
	    .S_AXI_RVALID		(s00_axi_rvalid		),
	    .S_AXI_RREADY		(s00_axi_rready		)
	);

    
endmodule