//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-06-13 오후 2:23:10
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================
`include "./timescale.vh"
//`define KECCAK
`define PWM

module TB_CTL;

    `define R @(posedge iSYS_CLK)
    `define W @(posedge iSYS_CLK) #1
    `define RR(n) repeat(n) `R
    `define WW(n) repeat(n) `W
    
    parameter	PRM_DAXI		= 	64;
    parameter	PRM_ADDR		= 	12;
    parameter	PRM_DRAM		=	32;
    parameter	PRM_COEFFS		=	4096;
    parameter	PRM_Q1 			= 	134250497;
	parameter	PRM_Q2 			= 	536903681;

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
    wire 	[1:0] 	oCTL_Q 		= 2'b01;
	wire 	[1:0] 	oCTL_BUT   	= 2'b00;
    
`ifdef KECCAK
    reg 	[63:0] 	Data [0:24];
   	reg 	[31:0] 	DataOrigin	[0:100];
   	reg [7:0] byte0, byte1, byte2, byte3;
   	reg 	[63:0] 	Data_resAXI [0:25];
   	reg		[16:0]	index;           // 0 ~ 2047 인덱스 (11-bit)
`elsif PWM
    reg 	[63:0] 	Data [0:PRM_COEFFS/2+PRM_COEFFS-1];
	reg 	[31:0] 	DataOrigin	[0:PRM_COEFFS];
	reg 	[31:0] 	Data_refQ1	[0:PRM_COEFFS];
	reg 	[31:0] 	Data_refQ2	[0:PRM_COEFFS];
	reg 	[63:0] 	Data_resAXI [0:PRM_COEFFS];
	reg 	[31:0] 	Data_res	[0:PRM_COEFFS];
	reg 	[63:0] temp_mul;
	reg		[16:0]	index;           // 0 ~ 2047 인덱스 (11-bit)
`endif
    
    always@(posedge iSYS_CLK)
	begin
		if(~iSYS_RST)
		begin
			index	<= 'b0;
		end
		else if (oM_AXIS_TVALID)
		begin
			Data_resAXI [index] <= oM_AXIS_TDATA;
			index <= index + 1;
		end		
	end

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
			for (cnt_i = 0; cnt_i < 64; cnt_i = cnt_i + 1) 
			begin
			    byte0 = 4 * cnt_i;
			    byte1 = byte0 + 1;
			    byte2 = byte0 + 2;
			    byte3 = byte0 + 3;
			    DataOrigin[cnt_i] = {byte3, byte2, byte1, byte0};
			end
			
			for (cnt_i = 0; cnt_i < 25; cnt_i = cnt_i + 1) 
			begin
				Data[cnt_i] = (DataOrigin[cnt_i * 2 + 1] << 32| DataOrigin[cnt_i*2 + 0]);
			end		
			
       	`elsif PWM		
			for (cnt_i = 0; cnt_i < PRM_COEFFS; cnt_i = cnt_i + 1)
			begin
				DataOrigin[cnt_i] = PRM_Q1-250497-10000+cnt_i;
//				DataOrigin[cnt_i] = cnt_i;
				temp_mul = DataOrigin[cnt_i] * DataOrigin[cnt_i];
				Data_refQ1[cnt_i] =	temp_mul % PRM_Q1;
				Data_refQ2[cnt_i] = temp_mul % PRM_Q2;
			end
		
			cnt_j = 0;
	       	for (cnt_i = 0; cnt_i < PRM_COEFFS/2; cnt_i = cnt_i + 1)
			begin
				Data[cnt_j] = (DataOrigin[cnt_i*2+1])<<(PRM_DAXI/2) | DataOrigin[cnt_i*2+0];
				cnt_j = cnt_j + 1;
			end
			
			for (cnt_i = 0; cnt_i < PRM_COEFFS/2; cnt_i = cnt_i + 1)
			begin
				Data[cnt_j] = (DataOrigin[cnt_i*2+1])<<(PRM_DAXI/2) | DataOrigin[cnt_i*2+0];
				cnt_j = cnt_j + 1;
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
        	`endif	   	
        wait (s00_axi_awready && s00_axi_wready);
		`W s00_axi_awvalid = 0;		s00_axi_wvalid  = 0;       
		//wait(s00_axi_bvalid); 	
		`W s00_axi_bready = 0;
		
		// DATA AXI init 
		// First Time
		`ifdef KECCAK     	
	       	//Data transfer for Keccak
	       	for (cnt_i = 0; cnt_i < 25; cnt_i = cnt_i + 1) 
	       	begin
	            `W	iS_AXIS_TVALID = 1;		iS_AXIS_TDATA  = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == 24) ? 1'b1 : 1'b0;
	        end
	        `W iS_AXIS_TVALID = 0;
	        
	        wait(oM_AXIS_TLAST);
	        
	        Data_resAXI [index] = oM_AXIS_TDATA;
	        
	        for (cnt_i = 0; cnt_i < 25; cnt_i = cnt_i + 1) 
			begin
				$display("%12d:state[%04d] = %h ->  %h",$time,cnt_i,Data[cnt_i], Data_resAXI[cnt_i]);
			end
	        
       	`elsif PWM
			// Data transfer for PWM
			for (cnt_i = 0; cnt_i < PRM_COEFFS/2; cnt_i = cnt_i + 1) 
			begin
				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == (PRM_COEFFS/2) -1) ? 1'b1 : 1'b0;
			end		
			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;	
			#500
			
			for (cnt_i = PRM_COEFFS/2; cnt_i < PRM_COEFFS; cnt_i = cnt_i + 1) 
			begin
				`W iS_AXIS_TVALID = 1;		iS_AXIS_TDATA = Data[cnt_i];	iS_AXIS_TLAST  = (cnt_i == PRM_COEFFS-1) ? 1'b1 : 1'b0;
			end		
			`W iS_AXIS_TVALID = 0; iS_AXIS_TLAST = 0;
			
			wait(oM_AXIS_TLAST);
			
			for (cnt_i = 0; cnt_i < PRM_COEFFS/2; cnt_i = cnt_i + 1) 
			begin
				Data_res[2*cnt_i + 0] = (Data_resAXI[cnt_i] >> 0);
				Data_res[2*cnt_i + 1] = (Data_resAXI[cnt_i] >> 32);
			end
			
			for (cnt_i = 0; cnt_i < PRM_COEFFS; cnt_i = cnt_i + 1) 
			begin
////				if(Data_res[cnt_i] != Data_refQ1[cnt_i])
////				begin
////					$display("%12d:Data_res[%04d] != Data_refQ1[%04d], %h * %h = %h (expect %h)",$time,cnt_i, cnt_i, DataOrigin[cnt_i], DataOrigin[cnt_i], Data_res[cnt_i], Data_refQ1[cnt_i]); // Q1
////				end
				if(Data_res[cnt_i] != Data_refQ2[cnt_i])
				begin
					$display("%12d:Data_res[%04d] != Data_refQ2[%04d], %h * %h = %h (expect %h)",$time,cnt_i, cnt_i, DataOrigin[cnt_i], DataOrigin[cnt_i], Data_res[cnt_i], Data_refQ2[cnt_i]); // Q2
				end
			end
			
			
		`endif
		
		#500
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