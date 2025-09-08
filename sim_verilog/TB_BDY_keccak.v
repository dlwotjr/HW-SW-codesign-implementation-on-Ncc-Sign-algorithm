//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-02-09 오후 4:09:05
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module TB_BDY_KECCAK;

	`define R @(posedge iSYS_CLK)
	`define W @(posedge iSYS_CLK) #1
	`define RR(n) repeat(n) `R
	`define WW(n) repeat(n) `W

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

// [PARMAS] definition for simulation
	// control signal
    reg		[2:0]	iCTL_MODE = 3'b0;
    
    // AXI slave signal
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
	
	reg [63:0] DATA1 [0:24];

// [TEST] 
initial
begin
//	$monitor("Time: %0t | FSM_PWMQ1: %b | FSM_PWMQ1_done: %b | FSM_KECCAK: %b | FSM_KECCAK_done: %b | Rm_Tvalid: %b | Rm_Tready: %b | Rm_Tdata: %h | Ws_Tvalid: %b | Ws_Tready: %b | Ws_Tdata: %h", 
//        $time, 
//        uut_bdy.FSM_PWMQ1, uut_bdy.FSM_PWMQ1_done, 
//        uut_bdy.FSM_KECCAK, uut_bdy.FSM_KECCAK_done, 
//        uut_bdy.Rm_Tvalid, uut_bdy.Rm_Tready, uut_bdy.Rm_Tdata, 
//        uut_bdy.Ws_Tvalid, uut_bdy.Ws_Tready, uut_bdy.Ws_Tdata
//    );
    
//    $monitor("Time=%0t | ins_keccak fsm=%h | keccak_in_reg=%h | keccak_start=%b | read_done=%h | compute_done=%b | keccak_out=%h", 
//        $time,
//        uut_bdy.ins_keccak.fsm,      // ins_keccak의 oFSM_DONE
//        uut_bdy.ins_keccak.keccak_in_reg,     // ins_keccak의 iFSM_START
//        uut_bdy.ins_keccak.keccak_start,             // keccak 입력 데이터
//        uut_bdy.ins_keccak.read_done,             // keccak 출력 데이터
//        uut_bdy.ins_keccak.compute_done,       // 연산 완료 신호
//        uut_bdy.ins_keccak.keccak_out 
//    );
    DATA1[0]  = 64'h00000000_00000000;
    DATA1[1]  = 64'h00000000_00000000;
    DATA1[2]  = 64'h00000000_00000000;
    DATA1[3]  = 64'h00000000_00000000;
    DATA1[4]  = 64'h00000000_00000000;
    DATA1[5]  = 64'h00000000_00000000;
    DATA1[6]  = 64'h00000000_00000000;
    DATA1[7]  = 64'h00000000_00000000;
    DATA1[8]  = 64'h00000000_00000080;
    DATA1[9]  = 64'h00000000_00000000;
    DATA1[10] = 64'h00000000_00000000;
    DATA1[11] = 64'h00000000_00000000;
    DATA1[12] = 64'h00000000_00000000;
    DATA1[13] = 64'h00000000_00000000;
    DATA1[14] = 64'h00000000_00000000;
    DATA1[15] = 64'h00000000_00000000;
    DATA1[16] = 64'h00000000_00000000;
    DATA1[17] = 64'h00000000_00000000;
    DATA1[18] = 64'h00000000_00000000;
    DATA1[19] = 64'h00000000_00000000;
    DATA1[20] = 64'h00000000_00000000;
    DATA1[21] = 64'h00000000_00000000;
    DATA1[22] = 64'h00000000_00000000;
    DATA1[23] = 64'h00000000_00000000;
    DATA1[24] = 64'h06000000_00000000;
    
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
			
	// transfer start
	begin $display("%12d:OOO: [TEST]: trasfer start--------------------------",$time); end
	for (cnt_i = 0; cnt_i < 25; cnt_i = cnt_i + 1) 
	begin
		`W iS_AXIS_TVALID = 1; 	iS_AXIS_TDATA = DATA1[cnt_i];  iS_AXIS_TKEEP  = 8'hFF;          
		if (cnt_i == 24)		iS_AXIS_TLAST = 1;
		else					iS_AXIS_TLAST = 0;
	end		
	
	`W iCTL_MODE = 3'd7; iS_AXIS_TLAST = 0; 	iS_AXIS_TDATA = 64'd0; iS_AXIS_TVALID = 0;
	`W iCTL_MODE = 3'd0;
	
	// transfer end
	begin $display("%12d:OOO: [TEST]: trasfer end----------------------------",$time); end
	`W iS_AXIS_TVALID = 0; 		iS_AXIS_TLAST = 0; 	iS_AXIS_TDATA = 64'd0;
     
    // test end
	#2000;
	$display("%12d:====================================================",$time);
	$display("%12d:OOO:ALL TEST OK & FINISH----------------------------",$time);
	$display("sadfasdfasdf");
	$stop;

end

	MDL_BDY uut_bdy
	(
		.iSYS_CLK			(iSYS_CLK			),
		.iSYS_RST			(iSYS_RST			),
		
		.iCTL_MODE			(iCTL_MODE			),
		
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