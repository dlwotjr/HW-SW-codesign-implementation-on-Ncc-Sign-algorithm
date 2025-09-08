//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-03-24 오후 7:33:32
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

//testbench for "MDL_CTL.v"
//AXI4 LITE
//The version of "MDL_CTL.v" is 2025.03.24 - only have the signal "oCTL_MODE"

`include "./timescale.vh"

module TB_MD_CTL;

    `define R @(posedge iSYS_CLK)
    `define W @(posedge iSYS_CLK) #1

    // Clock & Reset signals
    reg iSYS_CLK = 1'b0;
    reg iSYS_RST = 1'b0;  // active low reset, start asserted

    // AXI-Lite Write channel signals
    reg [4:0]  S_AXI_AWADDR  = 5'd0;
    reg [2:0]  S_AXI_AWPROT  = 3'b000;
    reg        S_AXI_AWVALID = 1'b0;
    wire       S_AXI_AWREADY;

    reg [31:0] S_AXI_WDATA   = 32'd0;
    reg [3:0]  S_AXI_WSTRB   = 4'b1111;
    reg        S_AXI_WVALID  = 1'b0;
    wire       S_AXI_WREADY;

    wire [1:0] S_AXI_BRESP;
    wire       S_AXI_BVALID;
    reg        S_AXI_BREADY  = 1'b1;

    // AXI-Lite Read channel (unused in this testbench)
    reg [4:0]  S_AXI_ARADDR  = 5'd0;
    reg [2:0]  S_AXI_ARPROT  = 3'b000;
    reg        S_AXI_ARVALID = 1'b0;
    wire       S_AXI_ARREADY;
    wire [31:0] S_AXI_RDATA;
    wire [1:0]  S_AXI_RRESP;
    wire       S_AXI_RVALID;
    reg        S_AXI_RREADY  = 1'b1;

    // DUT output: oCTL_MODE (start_module)
    wire [2:0] oCTL_MODE;

    initial begin
	    // 1) 클록을 0ns부터 계속 토글
	    while(1) #5 iSYS_CLK = ~iSYS_CLK;
	end

	initial begin
	    // 2) active-low reset
	    // 처음 100ns 동안 0(리셋 asserted), 이후 1(해제)
	    iSYS_RST = 0;
	    #100;
	    iSYS_RST = 1;
	end


    // Test sequence: wait until reset deasserted, then apply one-cycle write transaction
    initial begin
        // Wait until reset is released
        wait(iSYS_RST == 1);
        // Wait a few clock cycles for stability
        repeat (5) `R;
        
        $display("%0t: [TEST] Starting AXI write transaction for start_module", $time);
        
        // Apply write transaction in one clock cycle:
        // - AW and W channels asserted simultaneously.
        `W begin
           S_AXI_AWADDR  = 5'd0;       // 주소 0번
           S_AXI_WDATA   = 32'd7;       // 데이터 7 (하위 3비트: 111)
           S_AXI_WSTRB   = 4'b1111;
           S_AXI_AWVALID = 1;
           S_AXI_WVALID  = 1;
        end
        
        // Hold valid signals for one additional clock cycle to ensure handshake
        `W;
        
        // Deassert valid signals
        `W begin
           S_AXI_AWVALID = 0;
           S_AXI_WVALID  = 0;
        end
        
        // Wait for write response (BVALID) to be asserted
        wait(S_AXI_BVALID == 1);
        $display("%0t: [TEST] Write response: BVALID=%b, BRESP=%b", $time, S_AXI_BVALID, S_AXI_BRESP);
        `W S_AXI_BREADY = 1;
        `W S_AXI_BREADY = 0;
        
        // At the clock cycle when handshake occurs, oCTL_MODE should be S_AXI_WDATA[2:0] i.e., 3'b111.
        $display("%0t: [TEST] oCTL_MODE = %b (expected 111)", $time, oCTL_MODE);
        
        // Next cycle, oCTL_MODE should return to 0.
        `W;
        $display("%0t: [TEST] After one cycle, oCTL_MODE = %b (expected 000)", $time, oCTL_MODE);
        
        $stop;
    end

    // MDL_CTL 모듈 인스턴스화
    MDL_CTL uut (
        .oCTL_MODE(oCTL_MODE),
        .S_AXI_ACLK(iSYS_CLK),
        .S_AXI_ARESETN(iSYS_RST),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY)
    );

endmodule
