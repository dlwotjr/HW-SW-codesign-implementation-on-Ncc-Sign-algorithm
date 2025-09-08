//============================================================================
//  AUTHOR      :	YoungBeom Kim, jaeSeok Lee, and Seog Chung Seo
//  SPEC        :
//  HISTORY     :	2025-02-08 오후 3:14:45
//  Copyright	:	2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`timescale 1ns/1ps
module TB_FIFO;

  // Clock and reset
  reg         iSYS_CLK;
  reg         iSYS_RST;

  // Slave interface signals
  reg         iS_AXIS_TVALID;
  wire        oS_AXIS_TREADY;
  reg  [63:0] iS_AXIS_TDATA;
  reg  [7:0]  iS_AXIS_TKEEP;
  reg         iS_AXIS_TLAST;

  // Master interface signals
  wire        oM_AXIS_TVALID;
  reg         iM_AXIS_TREADY;
  wire [63:0] oM_AXIS_TDATA;
  wire [7:0]  oM_AXIS_TKEEP;
  wire        oM_AXIS_TLAST;

  // FIFO status output
  wire [31:0] axis_rd_data_count;

  // DUT 인스턴스화
  MDL_XXX_FIFO dut (
    .iSYS_CLK       (iSYS_CLK),
    .iSYS_RST       (iSYS_RST),
    .iS_AXIS_TVALID (iS_AXIS_TVALID),
    .oS_AXIS_TREADY (oS_AXIS_TREADY),
    .iS_AXIS_TDATA  (iS_AXIS_TDATA),
    .iS_AXIS_TKEEP  (iS_AXIS_TKEEP),
    .iS_AXIS_TLAST  (iS_AXIS_TLAST),
    .oM_AXIS_TVALID (oM_AXIS_TVALID),
    .iM_AXIS_TREADY (iM_AXIS_TREADY),
    .oM_AXIS_TDATA  (oM_AXIS_TDATA),
    .oM_AXIS_TKEEP  (oM_AXIS_TKEEP),
    .oM_AXIS_TLAST  (oM_AXIS_TLAST),
    .axis_rd_data_count(axis_rd_data_count)
  );

  //-------------------------------------------------------------------------
  // Clock Generation: 10ns period -> 100MHz
  //-------------------------------------------------------------------------
  initial begin
    iSYS_CLK = 0;
    forever #5 iSYS_CLK = ~iSYS_CLK;
  end

  //-------------------------------------------------------------------------
  // Reset Generation: Active Low Reset
  //-------------------------------------------------------------------------
  initial begin
    iSYS_RST = 0;
    #20;           // 20 ns 동안 reset 유지
    iSYS_RST = 1;  // reset 해제
  end

  //-------------------------------------------------------------------------
  // Stimulus: Write and Read transactions
  //-------------------------------------------------------------------------
  initial begin
    // 초기값 설정
    iS_AXIS_TVALID = 0;
    iS_AXIS_TDATA  = 64'd0;
    iS_AXIS_TKEEP  = 8'hFF;
    iS_AXIS_TLAST  = 0;
    iM_AXIS_TREADY = 1; // 항상 다운스트림이 준비된 상태로 가정

    // reset 해제 후 잠시 대기
    #30;

    // 첫 번째 데이터 전송
    @(posedge iSYS_CLK);
      iS_AXIS_TDATA  <= 64'hDEADBEEFCAFEBABE;
      iS_AXIS_TKEEP  <= 8'hFF;
      iS_AXIS_TLAST  <= 0;
      iS_AXIS_TVALID <= 1;
    @(posedge iSYS_CLK);
      // oS_AXIS_TREADY가 high이면 데이터가 FIFO에 쓰여짐
      if (oS_AXIS_TREADY)
        $display("Time %t: Write 1 accepted, FIFO count = %0d", $time, axis_rd_data_count);
    @(posedge iSYS_CLK);
      // 두 번째 데이터 전송 (마지막 플래그 설정)
      iS_AXIS_TDATA  <= 64'h0123456789ABCDEF;
      iS_AXIS_TKEEP  <= 8'hFF;
      iS_AXIS_TLAST  <= 1;
    @(posedge iSYS_CLK);
      if (oS_AXIS_TREADY)
        $display("Time %t: Write 2 accepted, FIFO count = %0d", $time, axis_rd_data_count);
    @(posedge iSYS_CLK);
      iS_AXIS_TVALID <= 0; // 전송 종료

    // 데이터 읽기 확인: 다운스트림(iM_AXIS_TREADY = 1)이 항상 준비된 상태
    // FIFO에 데이터가 저장되면 oM_AXIS_TVALID가 1이 되고, 데이터가 출력됩니다.
    repeat (10) begin
      @(posedge iSYS_CLK);
      if (oM_AXIS_TVALID)
        $display("Time %t: Read data = 0x%h, tlast = %b, FIFO count = %0d",
                 $time, oM_AXIS_TDATA, oM_AXIS_TLAST, axis_rd_data_count);
    end

    #100;
    $finish;
  end

endmodule
