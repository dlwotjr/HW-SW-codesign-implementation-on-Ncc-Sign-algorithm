//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :
//  HISTORY     :  2025-04-30 ¿ÀÈÄ 8:04:00
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module MDL_BDY_BUT #
(
    parameter	PRM_DAXI	= 	64,
    parameter	PRM_ADDR	= 	12,
    parameter	PRM_DRAM	=	32,
    parameter	PRM_COEFFS	=	4096,
    parameter	D    		=	30
)
(
    input						iSYS_CLK,
    input						iSYS_RST,

	input						iFSM_START,
    input		[1:0]			iCTL_BUT,	// 0 : PWM(sel = 0), 1: NTT(sel = 0) , 2 : INTT(sel = 1)
    input		[1:0]			iCTL_Q,		//	0 : Q1, 1: Q2
    input		[3:0]			iCTL_NTTDepth,
    output 						oFSM_DONE,
    
    input						iRs_Tvalid,
    output						oRs_Tready,
    input		[PRM_DAXI-1:0]	iRs_Tdata,
    input						iRs_Tlast,
    
    output						oWm_Tvalid,
    input						iWm_Tready,
    output		[PRM_DAXI-1:0]	oWm_Tdata,
    output						oWm_Tlast
);

localparam			Q1			= 134250497;
localparam			D1			= 28;
localparam			Q2			= 536903681;
localparam			D2			= 30;
localparam			PRM_CNT		= PRM_ADDR+1;

// PWM fsm
localparam			[1:0]	PRM_IDLE	= 2'b00;  
localparam			[1:0]	PRM_READ 	= 2'b01;  
localparam			[1:0]	PRM_COMPUTE	= 2'b10;  
localparam			[1:0]	PRM_WRITE	= 2'b11;  

reg					[1:0]	fsm;
reg							CON_READ_S;
//reg							CON_READ_S_p1;
//reg							CON_READ_S_p2;
reg							CON_COMP_S;
reg							CON_WRT_S; 
wire						CON_READ_W 	= fsm == PRM_READ;
wire						CON_COMP_W 	= fsm == PRM_COMPUTE;
wire						CON_WRT_W 	= fsm == PRM_WRITE;
wire						CON_READ_D;
wire						CON_COMP_D;
wire						CON_WRT_D; 

// wire for PWM
wire 						isNTT 				= (iCTL_BUT != 2'b00);
wire 						isPWM 				= (iCTL_BUT == 2'b00);
reg							BUT_START;	
reg							p1_BUT_START;
reg							p2_BUT_START;
reg							p3_BUT_START;
reg							p4_BUT_START;	
wire 						read_Tready;
wire						READ_oRs_Tready;	
reg 	[15:0] 				buf_start_cnt;
wire 						SEL_keep;
wire   						BUT_sel        	 	= iCTL_BUT[1];           // 0 : PWM(sel = 0), 1: NTT(sel = 0) , 2 : INTT(sel = 1)
wire 	[D-1:0] 			BUT1_iA, BUT1_iB, BUT1_iW;
wire 	[D-1:0] 			BUT2_iA, BUT2_iB, BUT2_iW;
reg 	[D-1:0] 			BUT1_iA_PWM, BUT1_iB_PWM, BUT1_iW_PWM;
reg 	[D-1:0] 			BUT2_iA_PWM, BUT2_iB_PWM, BUT2_iW_PWM;
wire 	[D-1:0] 			BUT1_oA, BUT1_oB;
wire 	[D-1:0] 			BUT2_oA, BUT2_oB;
reg 	[PRM_DAXI-1:0] 		reg_oWm_Tdata;
reg 						reg_oRs_Tready;
wire						oRs_Tready_w;
wire						oWm_Tvalid_w;
wire	[PRM_DAXI-1:0]		oWm_Tdata_w;

// Need reg / wire for PWM
reg 		[63:0]			reg_iRs_Tdata;
reg 						p1_oRs_Tready;
reg 						p2_oRs_Tready;
reg 						p3_oRs_Tready;
reg 						p4_oRs_Tready;
reg 						p5_oRs_Tready;
reg 						p6_oRs_Tready;
reg 						p7_oRs_Tready;
reg 						p8_oRs_Tready;
reg 						p9_oRs_Tready;
reg 						p10_oRs_Tready;
reg 						p11_oRs_Tready;
reg 						p12_oRs_Tready;
reg 		[PRM_CNT:0]		cnt;
reg 		[PRM_CNT:0]		cnt2;
reg 		[PRM_CNT:0]		p_cnt2;
reg 						read_iFSM_START;

wire 					READ_B1_enA 	,		READ_B1_enB 	,	COMP_B1_enA 	,		COMP_B1_enB 	,	COMP_B2_enA 	,		COMP_B2_enB 	,	WRT_B1_enA 	,		WRT_B2_enA 	,		WRT_B1_enB 	,		WRT_B2_enB 	;
wire 					READ_B1_weA 	,		READ_B1_weB 	,	COMP_B1_weA 	,		COMP_B1_weB 	,	COMP_B2_weA 	,		COMP_B2_weB 	,	WRT_B1_weA 	,		WRT_B2_weA 	,		WRT_B1_weB 	,		WRT_B2_weB 	;
wire 	[PRM_ADDR-1:0]	READ_B1_addrA	,		READ_B1_addrB	,	COMP_B1_addrA	,		COMP_B1_addrB	,	COMP_B2_addrA	,		COMP_B2_addrB	,	WRT_B1_addrA,		WRT_B2_addrA,		WRT_B1_addrB,		WRT_B2_addrB;
wire 	[PRM_DRAM-1:0]	READ_B1_dinA 	,		READ_B1_dinB 	,	COMP_B1_dinA 	,		COMP_B1_dinB 	,	COMP_B2_dinA 	,		COMP_B2_dinB 	;	      
wire 	[PRM_DRAM-1:0]	B1_doutA		, 		B1_doutB		,	B2_doutA		, 		B2_doutB;

wire 					B1_enA 				= (CON_READ_W)? READ_B1_enA 	: (CON_WRT_W)? WRT_B1_enA		: (CON_COMP_W)? (isNTT ? COMP_B1_enA		:	reg_oRs_Tready)	:0;
wire 					B1_weA 				= (CON_READ_W)? READ_B1_weA 	: (CON_WRT_W)? WRT_B1_weA	 	: (CON_COMP_W)? (isNTT ? COMP_B1_weA		:	1'b0)		:0;
wire 	[PRM_ADDR-1:0]	B1_addrA 			= (CON_READ_W)? READ_B1_addrA 	: (CON_WRT_W)? WRT_B1_addrA	 	: (CON_COMP_W)? (isNTT ? COMP_B1_addrA 	: 	cnt*2-2)		:0;
wire 	[PRM_DRAM-1:0]	B1_dinA 			= (CON_READ_W)? READ_B1_dinA 	: 								  (CON_COMP_W)? (isNTT ? COMP_B1_dinA	:	0)			:0;
 	
wire 					B1_enB 				= (CON_READ_W)? READ_B1_enB 	: (CON_WRT_W)? WRT_B1_enB 		: (CON_COMP_W)? (isNTT ? COMP_B1_enB		:	reg_oRs_Tready)	:0;
wire 					B1_weB 				= (CON_READ_W)? READ_B1_weB 	: (CON_WRT_W)? WRT_B1_weB 		: (CON_COMP_W)? (isNTT ? COMP_B1_weB		:	1'b0)		:0;
wire 	[PRM_ADDR-1:0]	B1_addrB 			= (CON_READ_W)? READ_B1_addrB 	: (CON_WRT_W)? WRT_B1_addrB 	: (CON_COMP_W)? (isNTT ? COMP_B1_addrB	: 	cnt*2-1)		:0;
wire 	[PRM_DRAM-1:0]	B1_dinB 			= (CON_READ_W)? READ_B1_dinB 	: 								  (CON_COMP_W)? (isNTT ? COMP_B1_dinB	:	0)			:0;
 	
wire 					B2_enA 				= (CON_WRT_W)? WRT_B2_enA		: (CON_COMP_W)? COMP_B2_enA		:	0;
wire 					B2_weA 				= (CON_WRT_W)? WRT_B2_weA	 	: (CON_COMP_W)? COMP_B2_weA		:	0;
wire 	[PRM_ADDR-1:0]	B2_addrA 			= (CON_WRT_W)? WRT_B2_addrA	 	: (CON_COMP_W)? COMP_B2_addrA 	: 	0;
wire 	[PRM_DRAM-1:0]	B2_dinA 			= 								  (CON_COMP_W)? COMP_B2_dinA	:	0;
 	 
wire 					B2_enB 				= (CON_WRT_W)? WRT_B2_enB 		: (CON_COMP_W)? COMP_B2_enB		:	0;
wire 					B2_weB 				= (CON_WRT_W)? WRT_B2_weB 		: (CON_COMP_W)? COMP_B2_weB		:	0;
wire 	[PRM_ADDR-1:0]	B2_addrB 			= (CON_WRT_W)? WRT_B2_addrB 	: (CON_COMP_W)? COMP_B2_addrB	:	0;
wire 	[PRM_DRAM-1:0]	B2_dinB 			= 								  (CON_COMP_W)? COMP_B2_dinB	:	0;

wire					zeta_B_en,		zeta_Q2_en,		zeta_Q1_en;
wire	[12-1:0]		zeta_B_addr,	zeta_Q1_addr,	zeta_Q2_addr;
wire	[30-1:0]  		zeta_B_dout,	zeta_Q2_dout,   zeta_Q1_dout;
assign					zeta_Q1_en			= (iCTL_Q)?		1'b0			:	zeta_B_en;
assign					zeta_Q2_en			= (iCTL_Q)?		zeta_B_en		:	1'b0;
assign					zeta_Q1_addr		= (iCTL_Q)?		'b0				:	zeta_B_addr;
assign					zeta_Q2_addr		= (iCTL_Q)?		zeta_B_addr		:	'b0;
assign					zeta_B_dout			= (iCTL_Q)? 	zeta_Q2_dout	:	zeta_Q1_dout; 
assign					zeta_Q2_en			= (iCTL_Q)?		zeta_B_en		:	1'b0;
assign					zeta_Q1_en			= (iCTL_Q)?		1'b0			:	zeta_B_en;
assign					zeta_Q2_addr		= (iCTL_Q)?		zeta_B_addr		:	'b0;
assign					zeta_Q1_addr		= (iCTL_Q)?		'b0				:	zeta_B_addr;

// iCTL_NTTDepth[0] - if 1 : B2 / else if 0 : B1
wire 	[PRM_DRAM-1:0] 	WRT_B_doutA 		= iCTL_NTTDepth[0] ? B2_doutA : B1_doutA;
wire 	[PRM_DRAM-1:0] 	WRT_B_doutB 		= iCTL_NTTDepth[0] ? B2_doutB : B1_doutB;
wire	[PRM_ADDR-1:0]	WRT_B_addrA;		//= iCTL_NTTDepth[0] ? B2_addrA : B1_addrA;
wire	[PRM_ADDR-1:0]	WRT_B_addrB;		//= iCTL_NTTDepth[0] ? B2_addrB : B1_addrB;
wire					WRT_B_enA;			//= iCTL_NTTDepth[0] ? B2_enA   : B1_enA;
wire					WRT_B_enB;			//= iCTL_NTTDepth[0] ? B2_enB   : B1_enB;
wire					WRT_B_weA;			//= iCTL_NTTDepth[0] ? B2_weA   : B1_weA;
wire					WRT_B_weB;			//= iCTL_NTTDepth[0] ? B2_weB   : B1_weB;

assign					WRT_B1_enA			= iCTL_NTTDepth[0] ? 1'b0 		: WRT_B_enA;
assign					WRT_B2_enA			= iCTL_NTTDepth[0] ? WRT_B_enA 	: 1'b0;
assign					WRT_B1_weA			= iCTL_NTTDepth[0] ? 1'b0 		: WRT_B_weA;
assign					WRT_B2_weA			= iCTL_NTTDepth[0] ? WRT_B_weA 	: 1'b0;
assign					WRT_B1_addrA		= iCTL_NTTDepth[0] ? 'b0 		: WRT_B_addrA;
assign					WRT_B2_addrA		= iCTL_NTTDepth[0] ? WRT_B_addrA: 'b0;
assign					WRT_B1_enB			= iCTL_NTTDepth[0] ? 1'b0 		: WRT_B_enB;
assign					WRT_B2_enB			= iCTL_NTTDepth[0] ? WRT_B_enB 	: 1'b0;
assign					WRT_B1_weB			= iCTL_NTTDepth[0] ? 1'b0 		: WRT_B_weB;
assign					WRT_B2_weB			= iCTL_NTTDepth[0] ? WRT_B_weB 	: 1'b0;
assign					WRT_B1_addrB		= iCTL_NTTDepth[0] ? 'b0 		: WRT_B_addrB;
assign					WRT_B2_addrB		= iCTL_NTTDepth[0] ? WRT_B_addrB: 'b0;



assign      			oRs_Tready      	= isNTT ? oRs_Tready_w : reg_oRs_Tready;
assign      			oWm_Tvalid			= isNTT ? oWm_Tvalid_w : p11_oRs_Tready & (cnt>11);
assign      			oWm_Tdata      		= isNTT ? oWm_Tdata_w : reg_oWm_Tdata;
assign					oFSM_DONE 			= isNTT ? CON_WRT_D : ((fsm == PRM_COMPUTE) ? ((p_cnt2==PRM_COEFFS/2+8) ? 1'b1 : 1'b0):1'b0);
assign 					oWm_Tlast 			= isNTT ? CON_WRT_D : ((fsm == PRM_COMPUTE) ? ((p_cnt2==PRM_COEFFS/2+8) ? 1'b1 : 1'b0):1'b0);

always@(posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		fsm			<=	`A PRM_IDLE;
		
		//NTT regs
		CON_READ_S 	<= 	`A 1'b0;
		CON_COMP_S 	<= 	`A 1'b0;
		CON_WRT_S 	<= 	`A 1'b0;
		
		//PWM regs
		reg_oRs_Tready <= `A 1'b0;
		cnt <= `A 0;
		BUT_START <= `A 0;
		p1_oRs_Tready   <= `A 1'b0;
		p2_oRs_Tready   <= `A 1'b0;
		p3_oRs_Tready   <= `A 1'b0;
		p4_oRs_Tready   <= `A 1'b0;
		p5_oRs_Tready   <= `A 1'b0;
		p6_oRs_Tready   <= `A 1'b0;
		p7_oRs_Tready   <= `A 1'b0;
		p8_oRs_Tready   <= `A 1'b0;
		p9_oRs_Tready   <= `A 1'b0;
		p10_oRs_Tready   <= `A 1'b0;
		p11_oRs_Tready   <= `A 1'b0;
		p12_oRs_Tready   <= `A 1'b0;
		p1_BUT_START	<= `A 1'b0;
		p2_BUT_START	<= `A 1'b0;
		p3_BUT_START	<= `A 1'b0;
		reg_iRs_Tdata	<= `A {PRM_DAXI{1'b0}};
		BUT1_iA_PWM			<= `A {D{1'b0}};
		BUT1_iB_PWM       	<= `A {D{1'b0}};
		BUT1_iW_PWM       	<= `A {D{1'b0}};
		BUT2_iA_PWM       	<= `A {D{1'b0}};
		BUT2_iB_PWM       	<= `A {D{1'b0}};
		BUT2_iW_PWM       	<= `A {D{1'b0}};
		cnt2 <= `A 'b0;
		buf_start_cnt <= 0;
		p_cnt2 <= `A 1'b0;
	end		
	else
	begin		
		if(isNTT) begin
			case(fsm)		
				PRM_IDLE:
				if(iFSM_START==1'b1) begin
					fsm 		<= `A PRM_READ;
					CON_READ_S 	<= `A 1'b1;
				end
				else begin
					fsm 		<= `A PRM_IDLE;
					CON_READ_S 	<= `A 1'b0;
				end
				PRM_READ: 
				if(CON_READ_D==1'b1) begin
					fsm 		<= `A PRM_COMPUTE;
					CON_COMP_S 	<= `A 1'b1;
				end
				else begin
					fsm 		<= `A PRM_READ;
					CON_READ_S 	<= `A 1'b0;
				end
				PRM_COMPUTE: 
				if(CON_COMP_D==1'b1) begin
					fsm 		<= `A PRM_WRITE;
					CON_WRT_S 	<= `A 1'b1;
				end
				else begin
					fsm 		<= `A PRM_COMPUTE;
					CON_COMP_S 	<= `A 1'b0;
				end
				PRM_WRITE :
				if(CON_WRT_D==1'b1)
					fsm 		<= `A PRM_IDLE;
				else begin
					fsm 		<= `A PRM_WRITE;
					CON_WRT_S 	<= `A 1'b0;
				end
			endcase
		end
		else if (isPWM) begin
			p1_oRs_Tready	<= `A reg_oRs_Tready;
		p2_oRs_Tready	<= `A p1_oRs_Tready;
		p3_oRs_Tready	<= `A p2_oRs_Tready;
		p4_oRs_Tready	<= `A p3_oRs_Tready;
		p5_oRs_Tready	<= `A p4_oRs_Tready;
		p6_oRs_Tready	<= `A p5_oRs_Tready;
		p7_oRs_Tready	<= `A p6_oRs_Tready;
		p8_oRs_Tready	<= `A p7_oRs_Tready;
		p9_oRs_Tready	<= `A p8_oRs_Tready;
		p10_oRs_Tready	<= `A p9_oRs_Tready;
		p11_oRs_Tready	<= `A p10_oRs_Tready;
		p12_oRs_Tready	<= `A p11_oRs_Tready;
		
		p1_BUT_START	<= `A BUT_START;
		p2_BUT_START	<= `A p1_BUT_START;
		p3_BUT_START	<= `A p2_BUT_START;
		
		p_cnt2 <= `A cnt2;
					
		case(fsm)		
			PRM_IDLE:
			begin
				if(iFSM_START)
				begin
					fsm	<= `A PRM_READ;
					read_iFSM_START	<= `A 1'b1;
					reg_oRs_Tready <= `A oRs_Tready_w;
//					cnt <= `A 0;
//					cnt2 <= `A 0;
//					BUT_START <= `A 1'b0;
				end
				else	
					fsm	<= `A fsm;
					reg_oRs_Tready <= `A 1'b0;
					cnt <= `A 0;
					BUT_START <= `A 0;
					p1_oRs_Tready   <= `A 1'b0;
					p2_oRs_Tready   <= `A 1'b0;
					p3_oRs_Tready   <= `A 1'b0;
					p4_oRs_Tready   <= `A 1'b0;
					p5_oRs_Tready   <= `A 1'b0;
					p6_oRs_Tready   <= `A 1'b0;
					p7_oRs_Tready   <= `A 1'b0;
					p8_oRs_Tready   <= `A 1'b0;
					p1_BUT_START	<= `A 1'b0;
					p2_BUT_START	<= `A 1'b0;
					p3_BUT_START	<= `A 1'b0;
					reg_iRs_Tdata	<= `A {PRM_DAXI{1'b0}};
					BUT1_iA_PWM			<= `A {D{1'b0}};
					BUT1_iB_PWM       	<= `A {D{1'b0}};
					BUT1_iW_PWM       	<= `A {D{1'b0}};
					BUT2_iA_PWM       	<= `A {D{1'b0}};
					BUT2_iB_PWM       	<= `A {D{1'b0}};
					BUT2_iW_PWM       	<= `A {D{1'b0}};
					cnt2 <= `A 'b0;
			end
			
			PRM_READ: 
			begin
				if(CON_READ_D)
				begin
					fsm	<= `A PRM_COMPUTE;
				end
				else				
				begin
					fsm	<= `A fsm;
					read_iFSM_START	<= `A 1'b0;
					reg_oRs_Tready <= `A oRs_Tready_w;
				end
			end
			
			PRM_COMPUTE: 
			begin
				if(oWm_Tlast)	// Last compute -> out for axi 
				begin
					fsm	<= `A PRM_IDLE;
					BUT_START <= `A 1'b0;
				end
				else
				begin
					fsm <= `A fsm;
					cnt <= `A iRs_Tvalid ? cnt + 1 : cnt;
					reg_oRs_Tready <= `A ((cnt < PRM_COEFFS/2) ? 1'b1 : 1'b0) & iRs_Tvalid;
					//BUT_START <= `A ((0<cnt && cnt2 < PRM_COEFFS/2) ? 1'b1 : 1'b0);
					//BUT_START <= `A ((0<cnt) ? 1'b1 : 1'b0);
					reg_oWm_Tdata   <= `A {2'b00, BUT1_oA, 2'b00, BUT2_oA}; // completely 32bit separate nessary 
					reg_iRs_Tdata 	<= `A iRs_Tdata;
					 if (cnt == 1) begin
			          buf_start_cnt <= (PRM_COEFFS/2 + 5) - 1;
			          BUT_START     <= 1'b1;
			        end
			         else if (buf_start_cnt != 0) begin
			          buf_start_cnt <= buf_start_cnt - 1;
			          BUT_START     <= 1'b1;
			        end
				if(BUT_START)
					begin
						cnt2			<= `A cnt2 +1;
						//p4_BUT_START	<= `A p3_BUT_START;
						BUT1_iA_PWM			<= `A {D{1'b0}};
						BUT1_iB_PWM			<= `A B1_doutB;
						BUT1_iW_PWM			<= `A reg_iRs_Tdata[32+D-1:32];
						BUT2_iA_PWM			<= `A {D{1'b0}};
						BUT2_iB_PWM			<= `A B1_doutA;
						BUT2_iW_PWM			<= `A reg_iRs_Tdata[D-1:0];
					end
				end
			end
		endcase
		end
	end
end

wire BUT_FSM_start 	= isNTT ? CON_COMP_W : p1_BUT_START;
wire sel_keep_buf	= isNTT ? SEL_keep : BUT_sel;
wire read_fsm_start = isNTT ? CON_READ_S : read_iFSM_START;

wire [D-1:0]	BUT1_iA_in		= isNTT ? BUT1_iA	: BUT1_iA_PWM;
wire [D-1:0]	BUT1_iB_in		= isNTT ? BUT1_iB	: BUT1_iB_PWM;
wire [D-1:0]	BUT1_iW_in		= isNTT ? BUT1_iW	: BUT1_iW_PWM;
wire [D-1:0]	BUT2_iA_in		= BUT2_iA_PWM;
wire [D-1:0]	BUT2_iB_in		= BUT2_iB_PWM;
wire [D-1:0]	BUT2_iW_in		= BUT2_iW_PWM;

	MDL_pipe_BUT ins_BUT1 
    (
        .iSYS_CLK			(iSYS_CLK		),
        .iSYS_RST			(iSYS_RST		),
        .iCTL_SEL			(SEL_keep		),
        .iFSM_START			(BUT_FSM_start	),
        .iCTL_Q				(iCTL_Q			),
        .iA					(BUT1_iA_in		),
        .iB					(BUT1_iB_in		),
        .iW					(BUT1_iW_in		),
        .oA					(BUT1_oA		),
        .oB					(BUT1_oB		)
    );
    
    MDL_pipe_BUT ins_BUT2
    (
        .iSYS_CLK			(iSYS_CLK		),
        .iSYS_RST			(iSYS_RST		),
        .iCTL_SEL			(BUT_sel		),
        .iFSM_START			(p1_BUT_START	),
        .iCTL_Q				(iCTL_Q			),
        .iA					(BUT2_iA_in		),
        .iB					(BUT2_iB_in		),
        .iW					(BUT2_iW_in		),
        .oA					(BUT2_oA		),
        .oB					(BUT2_oB		)
    );
    
	MDL_XXX_BRAM_READ  #(
		.PRM_DAXI			(PRM_DAXI		),
    	.PRM_ADDR			(PRM_ADDR		),
    	.PRM_DRAM			(PRM_DRAM		),
    	.PRM_COEFFS			(PRM_COEFFS		)
	) ins_READ
	(
		.iSYS_CLK			(iSYS_CLK		),
		.iSYS_RST			(iSYS_RST		),
		.iFSM_START			(read_fsm_start	),
		.oFSM_DONE			(CON_READ_D		),
		
		.iRs_Tvalid			(iRs_Tvalid		),
		.iRs_Tdata			(iRs_Tdata		),
		.oRs_Tready			(oRs_Tready_w	),
		
		.iCTL_BUT			(iCTL_BUT		),
		.iCTL_Q				(iCTL_Q			),
		
		.oB1_enA			(READ_B1_enA	),
		.oB1_weA			(READ_B1_weA	),
		.oB1_addrA			(READ_B1_addrA	),
		.oB1_dinA			(READ_B1_dinA	),  
		.oB1_enB			(READ_B1_enB	),
		.oB1_weB			(READ_B1_weB	),
		.oB1_addrB			(READ_B1_addrB	),
		.oB1_dinB			(READ_B1_dinB	)
	);
	
	MDL_XXX_BRAM_WRITE  #(
		.PRM_DAXI			(PRM_DAXI		),
    	.PRM_ADDR			(PRM_ADDR		),
    	.PRM_DRAM			(PRM_DRAM		),
    	.PRM_COEFFS			(PRM_COEFFS		)
	) ins_WRITE_NTT
	(
		.iSYS_CLK			(iSYS_CLK		),
		.iSYS_RST			(iSYS_RST		),
		.iFSM_START			(CON_WRT_S		),
		.oFSM_DONE			(CON_WRT_D		),
		
		.iWm_Tready			(iWm_Tready		),
		.oWm_Tdata			(oWm_Tdata_w	),
		.oWm_Tvalid			(oWm_Tvalid_w	),
//		.oWm_Tlast			(oWm_Tlast		),
		
		.oB_enA				(WRT_B_enA		),
		.oB_weA				(WRT_B_weA		),
		.oB_addrA			(WRT_B_addrA	),
		.iB_doutA			(WRT_B_doutA	),
		.oB_enB				(WRT_B_enB		),
		.oB_weB				(WRT_B_weB		),  
		.oB_addrB			(WRT_B_addrB	),
		.iB_doutB			(WRT_B_doutB	)
	);
	
	
	MDL_XXX_ZETAS_Q1_BRAM_GEN		zeta_Q1_ins(
		.clka				(iSYS_CLK		), 
		.ena				(zeta_Q1_en		), 
		.addra				(zeta_Q1_addr	), 
		.douta				(zeta_Q1_dout	)
	);
	
	MDL_XXX_ZETAS_Q2_BRAM_GEN		zeta_Q2_ins(
		.clka				(iSYS_CLK		), 
		.ena				(zeta_Q2_en		), 
		.addra				(zeta_Q2_addr	), 
		.douta				(zeta_Q2_dout	)
	);
	
	
	MDL_XXX_BRAM #(
		.PRM_DRAM			(PRM_DRAM		), 
		.PRM_ADDR			(PRM_ADDR		), 
		.PRM_DEPTH			(PRM_COEFFS		)
	) ins_BRAM1
	(
		.iSYS_CLK			(iSYS_CLK		),
		
		.iEN_A				(B1_enA			),
		.iWE_A				(B1_weA			),
		.iADR_A				(B1_addrA		),
		.iDIN_A				(B1_dinA		),
		.oDOUT_A			(B1_doutA		),

		.iEN_B				(B1_enB			),
		.iWE_B				(B1_weB			),
		.iADR_B				(B1_addrB		),
		.iDIN_B				(B1_dinB		),
		.oDOUT_B			(B1_doutB		)
	);
	
	MDL_XXX_BRAM #(
		.PRM_DRAM			(PRM_DRAM		), 
		.PRM_ADDR			(PRM_ADDR		), 
		.PRM_DEPTH			(PRM_COEFFS		)
	) ins_BRAM2
	(
		.iSYS_CLK			(iSYS_CLK		),
		
		.iEN_A				(B2_enA			),
		.iWE_A				(B2_weA			),
		.iADR_A				(B2_addrA		),
		.iDIN_A				(B2_dinA		),
		.oDOUT_A			(B2_doutA		),

		.iEN_B				(B2_enB			),
		.iWE_B				(B2_weB			),
		.iADR_B				(B2_addrB		),
		.iDIN_B				(B2_dinB		),
		.oDOUT_B			(B2_doutB		)
	);
	
	MDL_XXX_BUT_NTT #(
    .PRM_DAXI  (PRM_DAXI),
    .PRM_ADDR  (PRM_ADDR),
    .PRM_DRAM  (PRM_DRAM),
    .PRM_COEFFS(PRM_COEFFS),
    .D         (D)
	) ntt_ins (
	    .iSYS_CLK       	(iSYS_CLK		),
	    .iSYS_RST      		(iSYS_RST		),
	    .iFSM_START     	(CON_COMP_S		),
	    .iRead_start    	(CON_READ_S     ),
	    .iComp_working  	(CON_COMP_W		),
	    .iCTL_SEL       	(BUT_sel		),
	    .iCTL_Q		    	(iCTL_Q			),
	    .iCTL_NTTDepth  	(iCTL_NTTDepth	),
	    .oFSM_DONE      	(CON_COMP_D		),
	    .oSEL_keep      	(SEL_keep		),
                        	
	    .oZeta_en       	(zeta_B_en		),
	    .oZeta_addr     	(zeta_B_addr	),
	    .iZeta_dout     	(zeta_B_dout	),
                        	
	    .oB1_enA        	(COMP_B1_enA	),
	    .oB1_weA        	(COMP_B1_weA	),
	    .oB1_addrA      	(COMP_B1_addrA	),
	    .oB1_dinA       	(COMP_B1_dinA	),
	    .iB1_doutA      	(B1_doutA		),
                        	
	    .oB1_enB        	(COMP_B1_enB	),
	    .oB1_weB        	(COMP_B1_weB	),
	    .oB1_addrB      	(COMP_B1_addrB	),
	    .oB1_dinB       	(COMP_B1_dinB	),
	    .iB1_doutB      	(B1_doutB		),
                        	
	    .oB2_enA        	(COMP_B2_enA	),
	    .oB2_weA        	(COMP_B2_weA	),
	    .oB2_addrA      	(COMP_B2_addrA	),
	    .oB2_dinA       	(COMP_B2_dinA	),
	    .iB2_doutA      	(B2_doutA		),
                        	
	    .oB2_enB        	(COMP_B2_enB	),
	    .oB2_weB        	(COMP_B2_weB	),
	    .oB2_addrB      	(COMP_B2_addrB	),
	    .oB2_dinB       	(COMP_B2_dinB	),
	    .iB2_doutB      	(B2_doutB		),
                        	
	    .oBUT_iA        	(BUT1_iA		),
	    .oBUT_iB        	(BUT1_iB		),
	    .oBUT_iW        	(BUT1_iW		),
	    .iBUT_oA        	(BUT1_oA		),
	    .iBUT_oB        	(BUT1_oB		)
	);
    
endmodule
                                                                           