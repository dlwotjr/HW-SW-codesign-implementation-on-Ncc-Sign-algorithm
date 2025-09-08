//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :
//  HISTORY     :  2025-07-07 ?˜¤?›„ 6:31:49
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module MDL_XXX_BRAM_READ #
(
    parameter PRM_DAXI   = 64,
    parameter PRM_ADDR   = 12,
    parameter PRM_DRAM   = 32,
    parameter PRM_COEFFS = 4096,
    parameter D1         = 28,
    parameter D2         = 30
)
(
    input  wire                    iSYS_CLK,
    input  wire                    iSYS_RST,
    input  wire                    iFSM_START,
    output wire                    oFSM_DONE,

    input  wire                    iRs_Tvalid,
    input  wire [PRM_DAXI-1:0]     iRs_Tdata,
    output wire                    oRs_Tready,

    input  wire [1:0]              iCTL_BUT,  // 00=PWM, 01/10=NTT
    input  wire [1:0]              iCTL_Q,    // 00?†’Q1, else?†’Q2

    output wire                    oB1_enA,
    output wire                    oB1_weA,
    output wire [PRM_ADDR-1:0]     oB1_addrA,
    output wire [PRM_DRAM-1:0]     oB1_dinA,
    output wire                    oB1_enB,
    output wire                    oB1_weB,
    output wire [PRM_ADDR-1:0]     oB1_addrB,
    output wire [PRM_DRAM-1:0]     oB1_dinB
);

  localparam [D1-1:0] PRM_Q1 = 28'd134250497;
  localparam [D2-1:0] PRM_Q2 = 30'd536903681;

  reg  [PRM_DRAM-1:0] data_buf_lo, data_buf_hi;
  reg  [PRM_ADDR:0]     cnt, p_cnt, p2_cnt;
  reg                 read_active;
  reg                 p1_ready, p2_ready;
  reg                 d1, d2, d3;
  reg  [PRM_DRAM-1:0] 	p_raw_lo, p_raw_hi;       	      
  
  wire 					isNTT 		= 	(iCTL_BUT != 2'b00);
  wire 	[PRM_DRAM-1:0] 	Q_PRM 		= 	(iCTL_Q == 2'b00) ? {{(PRM_DRAM-D1){1'b0}}, PRM_Q1} : {{(PRM_DRAM-D2){1'b0}}, PRM_Q2};
  wire 	[PRM_DRAM-1:0] 	raw_lo 		= 	iRs_Tdata[PRM_DRAM-1:0];
  wire 	[PRM_DRAM-1:0] 	raw_hi 		= 	iRs_Tdata[PRM_DRAM*2-1:PRM_DRAM];
  wire 	[PRM_DRAM-1:0] 	lo_ntt 		= 	raw_lo[PRM_DRAM-1] ? raw_lo + Q_PRM : raw_lo;
  wire 	[PRM_DRAM-1:0] 	hi_ntt 		= 	raw_hi[PRM_DRAM-1] ? raw_hi + Q_PRM : raw_hi;
  wire 					cnt_done	= 	(cnt == PRM_COEFFS-2);

  assign oRs_Tready  = read_active && iRs_Tvalid;
  assign oB1_enA     = isNTT ? oRs_Tready : p2_ready;
  assign oB1_weA     = isNTT ? oRs_Tready : p2_ready;
  assign oB1_addrA   = isNTT ? cnt : p2_cnt;
  assign oB1_enB     = isNTT ? oRs_Tready : p2_ready;
  assign oB1_weB     = isNTT ? oRs_Tready : p2_ready;
  assign oB1_addrB   = isNTT ? cnt+1 : p2_cnt + 1;
  assign oB1_dinA    = isNTT ? lo_ntt : p_raw_lo;
  assign oB1_dinB    = isNTT ? hi_ntt : p_raw_hi;
  assign oFSM_DONE   = isNTT ? d1 : d3;

  always @(posedge iSYS_CLK) begin
    if (!iSYS_RST) begin
      cnt         <= `A 0;  p_cnt <= `A 0;  p2_cnt <= `A 0;
      read_active <= `A 0;
      p1_ready    <= `A 0;  p2_ready <= `A 0;
      d1 <= `A 0;  d2 <= `A 0;  d3 <= `A 0;
    end else begin
      cnt    <= `A (iFSM_START||cnt_done)? 0 : (oRs_Tready? cnt+2:cnt);
      p_raw_lo <= `A raw_lo;
      p_raw_hi <= `A raw_hi;
      p_cnt  <= `A cnt;
      p2_cnt <= `A p_cnt;
      p1_ready <= `A oRs_Tready;
      p2_ready <= `A p1_ready;
      d1 <= `A cnt_done;
      d2 <= `A d1;
      d3 <= `A d2;
      if (iFSM_START)      read_active <= `A 1;
      else if (cnt_done)   read_active <= `A 0;
    end
  end

endmodule
