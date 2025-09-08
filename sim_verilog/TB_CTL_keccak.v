//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-03-23 오후 8:07:24
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================
`include "./timescale.vh"

module TB_CTL_keccak;

    `define R @(posedge iSYS_CLK)
    `define W @(posedge iSYS_CLK) #1
    `define RR(n) repeat(n) `R
    `define WW(n) repeat(n) `W

    // Clock & Reset signals
    reg         iSYS_CLK = 1'b0;
    reg         iSYS_RST = 1'b0;  // active low reset: 0 = reset, 1 = normal

    // AXI Lite Interface Signals
    reg  [4:0]  s00_axi_awaddr   = 5'd0;
    reg  [2:0]  s00_axi_awprot   = 3'b000;
    reg         s00_axi_awvalid  = 1'b0;
    wire        s00_axi_awready;
    reg  [31:0] s00_axi_wdata    = 32'd0;
    reg  [3:0]  s00_axi_wstrb    = 4'b1111;
    reg         s00_axi_wvalid   = 1'b0;
    wire        s00_axi_wready;
    wire [1:0]  s00_axi_bresp;
    wire        s00_axi_bvalid;
    reg         s00_axi_bready   = 1'b1;

    reg  [4:0]  s00_axi_araddr   = 5'd0;
    reg  [2:0]  s00_axi_arprot   = 3'b000;
    reg         s00_axi_arvalid  = 1'b0;
    wire        s00_axi_arready;
    wire [31:0] s00_axi_rdata;
    wire [1:0]  s00_axi_rresp;
    wire        s00_axi_rvalid;
    reg         s00_axi_rready   = 1'b1;

    // Streaming Interface Signals (DMA write channel input)
    reg         iS_AXIS_TVALID   = 1'b0;
    wire        oS_AXIS_TREADY;
    reg  [63:0] iS_AXIS_TDATA    = 64'd0;
    reg  [7:0]  iS_AXIS_TKEEP    = 8'hFF;
    reg         iS_AXIS_TLAST    = 1'b0;

    // Streaming Interface Signals (DMA read channel output)
    wire        oM_AXIS_TVALID;
    reg         iM_AXIS_TREADY   = 1'b1;
    wire [63:0] oM_AXIS_TDATA;
    wire [7:0]  oM_AXIS_TKEEP;
    wire        oM_AXIS_TLAST;

    // Test Data Memory: 25 x 64-bit words (total 1600 bits)
    integer cnt;
    reg [63:0] DATA1 [0:24];

    // 1) Clock generation (계속 토글)
    initial begin
        forever #5 iSYS_CLK = ~iSYS_CLK;  // 100 MHz (10 ns period)
    end

    // 2) Reset generation: active-low로 100 ns 동안 0 유지 후 1로 해제
    initial begin
        iSYS_RST = 1'b0;   // assert reset
        #100;
        iSYS_RST = 1'b1;   // deassert reset
    end

    // 3) DATA1 초기화
    initial begin
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
    end

    // 4) Main Test Sequence
    initial begin
        // 리셋 해제 대기
        wait(iSYS_RST == 1);
        // 여유 클록 5개
        repeat (5) `R;

        $display("%0t: [TEST] Simulation start.", $time);

        // 4.1) 스트리밍 초기화
        `W iS_AXIS_TVALID = 1'b0;
        `W iS_AXIS_TDATA  = 64'd0;
        `W iS_AXIS_TKEEP  = 8'hFF;
        `W iS_AXIS_TLAST  = 1'b0;
        `W iM_AXIS_TREADY = 1'b1;

        // 4.2) 스트리밍 전송: 25개 워드
        $display("%0t: [TEST] Start streaming data transfer...", $time);
        for (cnt = 0; cnt < 25; cnt = cnt + 1) begin
            `W begin
                iS_AXIS_TVALID = 1;
                iS_AXIS_TDATA  = DATA1[cnt];
                iS_AXIS_TKEEP  = 8'hFF;
                iS_AXIS_TLAST  = (cnt == 24) ? 1'b1 : 1'b0;
            end
        end
        $display("%0t: [TEST] Streaming transfer completed.", $time);
        
        

        // 4.3) AXI-Lite Write Transaction: 주소 0번에 7 쓰기
        $display("%0t: [TEST] Issuing AXI write transaction (mode = 7)...", $time);
        `W begin
            s00_axi_awaddr  = 5'd0;
            s00_axi_awvalid = 1;
            s00_axi_wdata   = 32'd7; // 하위 3비트 = 111
            s00_axi_wstrb   = 4'b1111;
            s00_axi_wvalid  = 1;
            s00_axi_bready  = 1;
        end
        
        `W;

        // 한 클록 사이클 대기 후 valid deassert
        `W begin
            s00_axi_awvalid = 0;
            s00_axi_wvalid  = 0;
        end
		
		repeat (100) `R;
		$stop;
        // BVALID 대기
        wait(s00_axi_bvalid);
        `W s00_axi_bready = 0;
        $display("%0t: [TEST] AXI write (mode=7) transaction completed.", $time);

        // (선택) 2천 클록 정도 대기
        repeat (2000) `R;
        $display("%0t: [TEST] Simulation finished.", $time);
        $stop;
    end

    // MDL (MDL_BDY + MDL_CTL) 모듈 인스턴스화
    MDL uut_MDL (
       .iSYS_RST         (iSYS_RST),
       .iSYS_CLK         (iSYS_CLK),

       .s00_axi_awaddr   (s00_axi_awaddr),
       .s00_axi_awprot   (s00_axi_awprot),
       .s00_axi_awvalid  (s00_axi_awvalid),
       .s00_axi_awready  (s00_axi_awready),
       .s00_axi_wdata    (s00_axi_wdata),
       .s00_axi_wstrb    (s00_axi_wstrb),
       .s00_axi_wvalid   (s00_axi_wvalid),
       .s00_axi_wready   (s00_axi_wready),
       .s00_axi_bresp    (s00_axi_bresp),
       .s00_axi_bvalid   (s00_axi_bvalid),
       .s00_axi_bready   (s00_axi_bready),
       .s00_axi_araddr   (s00_axi_araddr),
       .s00_axi_arprot   (s00_axi_arprot),
       .s00_axi_arvalid  (s00_axi_arvalid),
       .s00_axi_arready  (s00_axi_arready),
       .s00_axi_rdata    (s00_axi_rdata),
       .s00_axi_rresp    (s00_axi_rresp),
       .s00_axi_rvalid   (s00_axi_rvalid),
       .s00_axi_rready   (s00_axi_rready),
       
       .s_axis_tvalid    (iS_AXIS_TVALID),
       .s_axis_tready    (oS_AXIS_TREADY),
       .s_axis_tdata     (iS_AXIS_TDATA),
       .s_axis_tkeep     (iS_AXIS_TKEEP),
       .s_axis_tlast     (iS_AXIS_TLAST),
                        
       .m_axis_tvalid    (oM_AXIS_TVALID),
       .m_axis_tready    (iM_AXIS_TREADY),
       .m_axis_tdata     (oM_AXIS_TDATA),
       .m_axis_tkeep     (oM_AXIS_TKEEP),
       .m_axis_tlast     (oM_AXIS_TLAST)
    );

endmodule
