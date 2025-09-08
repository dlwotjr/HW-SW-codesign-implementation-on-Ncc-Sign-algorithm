//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :
//  HISTORY     :  2025-03-07 오전 11:05:43
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module MDL_BDY_KECCAK #
(
    parameter   PRM_DAXI    =   64,
    parameter   PRM_DRAM    =   6  // log2(25) -> 5 bits for counting to 25
)
(
    input   wire                    iSYS_CLK,
    input   wire                    iSYS_RST,

    input	wire					iFSM_START,
    output  wire                    oFSM_DONE,
    
    input   wire                    iRs_Tvalid,
    output  wire                    oRs_Tready,
    input   wire    [PRM_DAXI-1:0]   iRs_Tdata,
    input	wire					 iRs_Tlast,
    
    output  wire                    oWm_Tvalid,
    input   wire                    iWm_Tready,
    output  wire    [PRM_DAXI-1:0]   oWm_Tdata,
    output 	wire					 oWm_Tlast
);

// KECCAK FSM states
localparam  [1:0]   PRM_IDLE    = 2'b00;  
localparam  [1:0]   PRM_READ    = 2'b01;  
localparam  [1:0]   PRM_COMPUTE = 2'b10;  
localparam  [1:0]   PRM_LWE   	= 2'b11;  

reg         [1:0]           fsm;
reg         [PRM_DRAM-1:0]  in_cnt;
wire       	[1599:0]        keccak_in;
reg			[1599:0]        keccak_reg;
reg                         keccak_start;
wire                        read_done;
wire                        compute_done;
wire       	[1599:0]        keccak_out;
reg         [PRM_DRAM-1:0]  out_cnt;

assign	keccak_in		= keccak_reg;
assign  read_done     	= (in_cnt == 24);
assign  oFSM_DONE     	= (out_cnt == 24);

assign  oRs_Tready    	= (fsm == PRM_READ);
assign 	oWm_Tvalid 		= (fsm == PRM_LWE);
assign  oWm_Tdata     	= keccak_reg[((24-out_cnt) * 64) +: 64];
assign	oWm_Tlast		= (out_cnt == 24);

always @(posedge iSYS_CLK) begin
    if (!iSYS_RST) begin
    	$display("MDL_BDY_KECCAK | start_reset=0");
        fsm         <= `A PRM_IDLE;
        in_cnt      <= `A 'b0;
        out_cnt     <= `A 'b0;
        keccak_start <= `A 'b0;
        keccak_reg <= `A 'b0;
    end else begin
        case (fsm)
            PRM_IDLE: begin
            	keccak_reg <= `A 'b0;
            	in_cnt 	<= `A 'b0;
                out_cnt <= `A 'b0;
                if (iFSM_START) begin
                	$display("MDL_BDY_KECCAK | PRM_IDLE");
                    fsm 	<= `A PRM_READ;
                end
            end
            
            PRM_READ: begin
                if (iRs_Tvalid) begin
                	$display("MDL_BDY_KECCAK | PRM_READ");
                	$display("MDL_BDY_KECCAK | iRs_Tdata : %h | in_cnt : %d", iRs_Tdata, in_cnt);
                	keccak_reg[(in_cnt * 64) +: 64] <= `A iRs_Tdata;
                    in_cnt <= `A in_cnt + 1;
                    //padding process input here
                    if (read_done) 
                    begin
                        fsm <= `A PRM_COMPUTE;
                        keccak_start <= `A 1'b1;
                    end
                end
            end
            
            PRM_COMPUTE: 
            begin
            	$display("MDL_BDY_KECCAK | PRM_COMPUTE - PROCESS");
                if (compute_done)
                begin
                	$display("MDL_BDY_KECCAK | PRM_COMPUTE - DONE");
			        keccak_start <= `A 'b0;
			        fsm <= `A PRM_LWE;
			        keccak_reg <= `A keccak_out;
			    end
            end
            
            PRM_LWE: 
            begin
                if (iWm_Tready) 
                begin
                	$display("MDL_BDY_KECCAK | PRM_LWE");
                	$display("MDL_BDY_KECCAK | out_cnt : %d", out_cnt);
                    out_cnt 	<= `A out_cnt + 1;
                    if (oWm_Tlast) 
                    begin
                        fsm 	<= `A PRM_IDLE;
                    end
                end
            end
        endcase
    end
end


MDL_XXX_keccak ins_keccak (
    .iSYS_CLK    (iSYS_CLK		),
    .iSYS_RST    (iSYS_RST		),
    .iFSM_START  (keccak_start	), 
    .iN          (keccak_in		),
    .oR          (keccak_out	),
    .oFSM_DONE   (compute_done	)
);

endmodule