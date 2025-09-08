//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-06-13 ?삤?썑 2:23:10
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================
`include "./timescale.vh"
//`define KECCAK
//`define PWM
`define NTT

module TB_CTL;

    `define R @(posedge iSYS_CLK)
    `define W @(posedge iSYS_CLK) #1
    `define RR(n) repeat(n) `R
    `define WW(n) repeat(n) `W
    
    parameter	PRM_DAXI		= 	64;
    parameter	PRM_ADDR		= 	12;
    parameter	PRM_DRAM		=	32;
    parameter	PRM_PWM			=	4096;
    parameter 	PRM_NTT			=	4096;

    reg         		iSYS_CLK = 1'b0;
    reg         		iSYS_RST = 1'b1;  
    reg  [4:0]  		s00_axi_awaddr   = 5'd0;
    reg  [2:0]  		s00_axi_awprot   = 3'b000;
    reg         		s00_axi_awvalid  = 1'b0;
    wire        		s00_axi_awready;
    reg  [31:0] 		s00_axi_wdata    = 32'd0;
    reg  [3:0]  		s00_axi_wstrb    = 4'b1111;
    reg         		s00_axi_wvalid   = 1'b0;
    wire        		s00_axi_wready;
    wire [1:0]  		s00_axi_bresp;
    wire        		s00_axi_bvalid;
    reg         		s00_axi_bready   = 1'b0;
    reg  [4:0]  		s00_axi_araddr   = 5'd0;
    reg  [2:0]  		s00_axi_arprot   = 3'b000;
    reg         		s00_axi_arvalid  = 1'b0;
    wire        		s00_axi_arready;
    wire [31:0] 		s00_axi_rdata;
    wire [1:0]  		s00_axi_rresp;
    wire        		s00_axi_rvalid;
    reg         		s00_axi_rready   = 1'b1;
    reg         		iS_AXIS_TVALID   = 1'b0;
    wire        		oS_AXIS_TREADY;
    reg  [PRM_DAXI-1:0] iS_AXIS_TDATA    = 64'd0;
    reg  [7:0]  		iS_AXIS_TKEEP    = 8'hFF;
    reg         		iS_AXIS_TLAST    = 1'b0;
    wire        		oM_AXIS_TVALID;
    reg         		iM_AXIS_TREADY   = 1'b1;
    wire [PRM_DAXI-1:0] oM_AXIS_TDATA;
    wire [7:0]  		oM_AXIS_TKEEP;
    wire        		oM_AXIS_TLAST;

    integer cnt_i, cnt_j;
    integer index;
    reg 	[1:0] 	oCTL_Q 				= 2'b00;
	//wire 	[1:0] 	oCTL_BUT   			= 2'b01;
	reg 	[3:0] 	oCTL_NTTDepth   	= 4'd12;
	
	`ifdef KECCAK
    	//reg 	[1:0] 	oCTL_BUT   			= 2'b01;
    `elsif PWM
    	reg 	[1:0] 	oCTL_BUT   			= 2'b00;
    `elsif NTT
    	reg 	[1:0] 	oCTL_BUT   			= 2'b01;
    `endif
    
    `ifdef KECCAK
    	reg 	[63:0] 	Data [0:24];
    `elsif PWM
    	reg 	[63:0] 	Data [0:PRM_PWM/2+PRM_PWM-1];
    `elsif NTT
    	reg 	[63:0] 	Data [0:PRM_NTT/2-1];
    	reg 	[31:0] 	Data_origin [0:PRM_NTT];
    `endif

//	always @(posedge iSYS_CLK) begin
//	  	if ($urandom_range(0,9) == 0) iM_AXIS_TREADY <= 0;
//	  	else                           iM_AXIS_TREADY <= 1;
//	end

    initial 
	begin
		while(1) #5 iSYS_CLK = ~iSYS_CLK; // #5 means 100 MHz clock period	
	end

    initial begin
    	#100 iSYS_RST = 0;
		#100 iSYS_RST = 1;
		
		// DATA INPUT
		`ifdef KECCAK
			//keccak Data initialize
	       	for (cnt_i = 1; cnt_i < 25+1; cnt_i = cnt_i + 1) 
			begin
				Data[cnt_i-1] = cnt_i<<(PRM_DAXI/2) | cnt_i;
			end		        
       	`elsif PWM
	       	//PWM Data initialize
//	       	for (cnt_i = 1; cnt_i < PRM_PWM+1; cnt_i = cnt_i + 1) 
//			begin
//				Data[cnt_i-1] = cnt_i<<(PRM_DAXI/2) | cnt_i;
//			end	
			cnt_j = 0;
	       	for (cnt_i = 0; cnt_i < PRM_PWM; cnt_i = cnt_i + 2)
			begin
				Data[cnt_j] = (cnt_i+1)<<(PRM_DAXI/2) | (cnt_i+1) + 1;
				cnt_j = cnt_j + 1;
			end
			
			for (cnt_i = 0; cnt_i < PRM_PWM; cnt_i = cnt_i + 2)
			begin
				Data[cnt_j] = (cnt_i+1)<<(PRM_DAXI/2) | (cnt_i+1) + 1;
				cnt_j = cnt_j + 1;
			end
//		`elsif NTT
//	       	//NTT Data initialize
//	       	for (cnt_i = 1; cnt_i < PRM_NTT/2+1; cnt_i = cnt_i + 1) 
//			begin
//				Data[cnt_i-1] = (cnt_i*2-1)|((cnt_i*2)<<(PRM_DAXI/2));
////				Data[cnt_i-1] = (cnt_i*2)|((cnt_i*2-1)<<(PRM_DAXI/2));
//			end	
//		`endif
        `elsif NTT
            // NTT Data initialize with negative values
//            index = -1;
//            for (cnt_i = 0; cnt_i < PRM_NTT; cnt_i = cnt_i + 1) 
//            begin
//                Data_origin[cnt_i] = index;
//                index = index - 1;
//            end
           
//            for (cnt_i = 0; cnt_i < PRM_NTT/2; cnt_i = cnt_i + 1) 
//            begin
//                Data[cnt_i] = (Data_origin[cnt_i * 2 + 1] << 32) | (Data_origin[cnt_i * 2 + 0]);                
//            end
            index = 1;
            for (cnt_i = 0; cnt_i < PRM_NTT; cnt_i = cnt_i + 1) 
            begin
                Data_origin[cnt_i] = index;
                index = index + 1;
            end
           
            for (cnt_i = 0; cnt_i < PRM_NTT/2; cnt_i = cnt_i + 1) 
            begin
                Data[cnt_i] = (Data_origin[cnt_i * 2 + 1] << 32) | (Data_origin[cnt_i * 2 + 0]);                
            end
        `endif
		
		// 5 ready/valid Handshake on AXI Lite
        // AW 	(Address Write) 			v
        // W	(Write) 					v
        // b	(write response channel)	v
        // AR	(Address Read)				x
        // R	(Read)						x
        
		// Control AXI Lite - Use Write related channels only
        `W	s00_axi_awvalid = 1;	s00_axi_wvalid  = 1;		s00_axi_bready  = 1;
        	`ifdef KECCAK 
        		s00_axi_awaddr  = 5'd0;		
        		s00_axi_wdata   = 32'd1;	//iCTL_MODE
        	`elsif PWM
        		s00_axi_awaddr  = 5'd0;		 
		        s00_axi_wdata   = 32'd2;	//iCTL_MODE 
				wait (s00_axi_awready && s00_axi_wready);
		        `W s00_axi_awaddr  = 5'd4;	s00_axi_wdata = {28'd0, oCTL_Q, oCTL_BUT};	 
		    `elsif NTT
		      s00_axi_awaddr  = 5'd4;	s00_axi_wdata = {24'd0, oCTL_NTTDepth, oCTL_Q, oCTL_BUT};
        		
				wait (s00_axi_awready && s00_axi_wready);
		        `W s00_axi_awaddr  = 5'd0;	s00_axi_wdata   = 32'd2;	//iCTL_MODE  	 
        	`endif	   	
        wait (s00_axi_awready && s00_axi_wready);
		`W s00_axi_awvalid = 0;		s00_axi_wvalid  = 0;       
		//wait(s00_axi_bvalid); 	
		`W s00_axi_bready = 0;
		
		
		#100
		
		// DATA AXI init 
		// First Time
		`ifdef KECCAK     	
	       	//Data transfer for Keccak
	       	for (cnt_i = 0; cnt_i < 25; cnt_i = cnt_i + 1) 
	       	begin
	            `W	iS_AXIS_TVALID = 1;		iS_AXIS_TDATA  = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == 24) ? 1'b1 : 1'b0;
	        end
	        `W iS_AXIS_TVALID = 0;
	        
       	`elsif PWM
			//Data transfer for PWM
			
			//origin------------------------------------------------
//			for (cnt_i = 0; cnt_i < PRM_PWM; cnt_i = cnt_i + 1) 
//			begin
//				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == PRM_PWM-1) ? 1'b1 : 1'b0;
//			end		
//			`W iS_AXIS_TVALID = 0;
			
			//new ------------------------------------------------
			for (cnt_i = 0; cnt_i < PRM_PWM/2; cnt_i = cnt_i + 1) 
			begin
				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == (PRM_PWM/2) -1) ? 1'b1 : 1'b0;
			end		
			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;	
			#500
			for (cnt_i = PRM_PWM/2; cnt_i < PRM_PWM; cnt_i = cnt_i + 1) 
			begin
				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == PRM_PWM-1) ? 1'b1 : 1'b0;
			end		
			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;
			
			`elsif NTT
			//Data transfer for NTT
			for (cnt_i = 0; cnt_i < PRM_NTT/2; cnt_i = cnt_i + 1) 
			begin
				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == PRM_NTT/2-1) ? 1'b1 : 1'b0;
			end		
			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;
		`endif
		
		wait(oM_AXIS_TLAST);
		#100
		
		
//		//assign input signals
//		`W oCTL_BUT = 2'b01;
//		`W oCTL_NTTDepth = 4'd12;
//		`W oCTL_Q = 2'd0;
		
//		// 5 ready/valid Handshake on AXI Lite
//        // AW 	(Address Write) 			v
//        // W	(Write) 					v
//        // b	(write response channel)	v
//        // AR	(Address Read)				x
//        // R	(Read)						x
        
//		// Control AXI Lite - Use Write related channels only
//        `W	s00_axi_awvalid = 1;	s00_axi_wvalid  = 1;		s00_axi_bready  = 1;
//        	`ifdef KECCAK 
//        		s00_axi_awaddr  = 5'd0;		
//        		s00_axi_wdata   = 32'd1;	//iCTL_MODE
//        	`elsif PWM
//        		s00_axi_awaddr  = 5'd0;		 
//		        s00_axi_wdata   = 32'd2;	//iCTL_MODE 
//				wait (s00_axi_awready && s00_axi_wready);
//		        `W s00_axi_awaddr  = 5'd4;	s00_axi_wdata = {28'd0, oCTL_Q, oCTL_BUT};	 
//		    `elsif NTT
//		      s00_axi_awaddr  = 5'd4;	s00_axi_wdata = {24'd0, oCTL_NTTDepth, oCTL_Q, oCTL_BUT};
        		
//				wait (s00_axi_awready && s00_axi_wready);
//		        `W s00_axi_awaddr  = 5'd0;	s00_axi_wdata   = 32'd2;	//iCTL_MODE  	 
//        	`endif	   	
//        wait (s00_axi_awready && s00_axi_wready);
//		`W s00_axi_awvalid = 0;		s00_axi_wvalid  = 0;       
//		//wait(s00_axi_bvalid); 	
//		`W s00_axi_bready = 0;
		
		
//		#100
		
//		// DATA AXI init 
//		// First Time
//		`ifdef KECCAK     	
//	       	//Data transfer for Keccak
//	       	for (cnt_i = 0; cnt_i < 25; cnt_i = cnt_i + 1) 
//	       	begin
//	            `W	iS_AXIS_TVALID = 1;		iS_AXIS_TDATA  = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == 24) ? 1'b1 : 1'b0;
//	        end
//	        `W iS_AXIS_TVALID = 0;
	        
//       	`elsif PWM
//			//Data transfer for PWM
			
//			//origin------------------------------------------------
////			for (cnt_i = 0; cnt_i < PRM_PWM; cnt_i = cnt_i + 1) 
////			begin
////				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == PRM_PWM-1) ? 1'b1 : 1'b0;
////			end		
////			`W iS_AXIS_TVALID = 0;
			
//			//new ------------------------------------------------
//			for (cnt_i = 0; cnt_i < PRM_PWM/2; cnt_i = cnt_i + 1) 
//			begin
//				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == (PRM_PWM/2) -1) ? 1'b1 : 1'b0;
//			end		
//			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;	
//			#500
//			for (cnt_i = PRM_PWM/2; cnt_i < PRM_PWM; cnt_i = cnt_i + 1) 
//			begin
//				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == PRM_PWM-1) ? 1'b1 : 1'b0;
//			end		
//			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;
			
//			`elsif NTT
//			//Data transfer for NTT
//			for (cnt_i = 0; cnt_i < PRM_NTT/2; cnt_i = cnt_i + 1) 
//			begin
//				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == PRM_NTT/2-1) ? 1'b1 : 1'b0;
//			end		
//			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;
//		`endif
		
//		wait(oM_AXIS_TLAST);
//		#100
		
        // test end
		$display("%12d:====================================================",$time);
		$display("%12d:OOO:ALL TEST OK & FINISH----------------------------",$time);
		$stop;
    end

MDL uut_MDL (
   	.s00_axi_aclk     	(iSYS_CLK		),
   	.s00_axi_aresetn    (iSYS_RST		),
   	.s00_axi_awaddr   	(s00_axi_awaddr	),
   	.s00_axi_awprot   	(s00_axi_awprot	),
   	.s00_axi_awvalid  	(s00_axi_awvalid),
   	.s00_axi_awready  	(s00_axi_awready),
   	.s00_axi_wdata    	(s00_axi_wdata	),
   	.s00_axi_wstrb    	(s00_axi_wstrb	),
   	.s00_axi_wvalid   	(s00_axi_wvalid	),
   	.s00_axi_wready   	(s00_axi_wready	),
   	.s00_axi_bresp    	(s00_axi_bresp	),
   	.s00_axi_bvalid   	(s00_axi_bvalid	),
   	.s00_axi_bready   	(s00_axi_bready	),
   	.s00_axi_araddr   	(s00_axi_araddr	),
   	.s00_axi_arprot   	(s00_axi_arprot	),
   	.s00_axi_arvalid  	(s00_axi_arvalid),
   	.s00_axi_arready  	(s00_axi_arready),
   	.s00_axi_rdata    	(s00_axi_rdata	),
   	.s00_axi_rresp    	(s00_axi_rresp	),
   	.s00_axi_rvalid   	(s00_axi_rvalid	),
   	.s00_axi_rready   	(s00_axi_rready	),

   	.aresetn         	(iSYS_RST		),
   	.clk             	(iSYS_CLK		),
   	
   	.s_axis_tvalid    	(iS_AXIS_TVALID	),
   	.s_axis_tready    	(oS_AXIS_TREADY	),
   	.s_axis_tdata     	(iS_AXIS_TDATA	),
   	.s_axis_tkeep     	(iS_AXIS_TKEEP	),
   	.s_axis_tlast     	(iS_AXIS_TLAST	),
   	                  	
   	.m_axis_tvalid    	(oM_AXIS_TVALID	),
   	.m_axis_tready    	(iM_AXIS_TREADY	),
   	.m_axis_tdata     	(oM_AXIS_TDATA	),
   	.m_axis_tkeep     	(oM_AXIS_TKEEP	),
   	.m_axis_tlast     	(oM_AXIS_TLAST	)
);

endmodule
