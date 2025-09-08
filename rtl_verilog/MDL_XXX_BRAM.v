//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-02-10 오후 5:18:53
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module MDL_XXX_BRAM #
(
    parameter	PRM_DRAM	= 32,
    parameter	PRM_ADDR	= 12,
    parameter	PRM_DEPTH	= 4096
)
(
	input	wire        			iSYS_CLK	,
	
	input	wire        			iEN_A		, // Enable A
	input	wire        			iWE_A		, // Write Enable A
	input	wire	[PRM_ADDR-1:0]	iADR_A		, // Address of A
	input	wire	[PRM_DRAM-1:0]	iDIN_A		, // input data of A
	output	reg		[PRM_DRAM-1:0]	oDOUT_A		, // output A
	
	input	wire        			iEN_B		, // same as A
	input	wire        			iWE_B		,
	input	wire	[PRM_ADDR-1:0]	iADR_B		,
	input	wire	[PRM_DRAM-1:0]	iDIN_B		,
	output	reg		[PRM_DRAM-1:0]	oDOUT_B
);

(* ram_style = "block" *) reg [PRM_DRAM-1:0] mem [0:PRM_DEPTH-1];

// wire first
always @(posedge iSYS_CLK) 
begin
	if (iEN_A)
	begin
		if (iWE_A)
		begin
			mem[iADR_A]	<= iDIN_A;
			oDOUT_A		<= iDIN_A;
      	end 
      	else
      	begin
			oDOUT_A		<= mem[iADR_A];
		end
    end
end

always @(posedge iSYS_CLK) 
begin
	if (iEN_B)
	begin
		if (iWE_B)
		begin
			mem[iADR_B]	<= iDIN_B;
			oDOUT_B		<= iDIN_B;
      	end 
      	else
      	begin
			oDOUT_B		<= mem[iADR_B];
		end
    end
end

endmodule
