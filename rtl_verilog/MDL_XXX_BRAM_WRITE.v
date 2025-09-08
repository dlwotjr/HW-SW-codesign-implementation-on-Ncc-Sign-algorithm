//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-07-09 오후 3:33:50
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================
`include "./timescale.vh"

module MDL_XXX_BRAM_WRITE#
(
    parameter PRM_DAXI   = 64,
    parameter PRM_ADDR   = 12,
    parameter PRM_DRAM   = 32,
    parameter PRM_COEFFS = 4096,
    parameter D1         = 28,
    parameter D2         = 30
)
(

    input  wire 					iSYS_CLK,
    input  wire						iSYS_RST,
    input  wire 					iFSM_START,
    output wire 					oFSM_DONE, 
    
    input  wire 					iWm_Tready,
    output wire 	[PRM_DAXI-1:0] 	oWm_Tdata,
    output wire 					oWm_Tvalid,
    
    output wire 					oB_enA,
    output wire 					oB_weA,
    output wire 	[PRM_ADDR-1:0]	oB_addrA,
    input  wire 	[PRM_DRAM-1:0]	iB_doutA,
    
    output wire 					oB_enB,
    output wire 					oB_weB,
    output wire 	[PRM_ADDR-1:0]	oB_addrB,
    input  wire 	[PRM_DRAM-1:0] 	iB_doutB
    );
    
    reg				[PRM_ADDR:0] 	counter;
    reg				[PRM_ADDR:0] 	counter_Tlast;
    reg				 	            count_Tlast_done_p;
    reg				 	            count_Tlast_done_p2;
    reg 							counter_working;
    reg				[PRM_DRAM-1:0] 	data1;
    reg				[PRM_DRAM-1:0] 	data2;
    reg 							working_1;
    reg 							working_2;
    reg 							done_1;
    reg 							done_2;
    
    wire 	count_done = (counter == PRM_COEFFS-2);
    //wire    count_Tlast_done = (counter_Tlast == 1024-2)? 1'b1 : 1'b0;
    wire 	mem_working = counter_working | done_2;
    assign 	oB_addrA = counter;
    assign 	oB_addrB = counter + 1'b1;
    assign 	oWm_Tvalid = working_2 & iWm_Tready;
    assign 	oB_enA = counter_working;
    assign 	oB_weA = 1'b0;
    assign 	oB_enB = counter_working;
    assign 	oB_weB = 1'b0;
    assign 	oWm_Tdata[PRM_DRAM-1:0]  = data1;
    assign 	oWm_Tdata[PRM_DRAM*2-1:PRM_DRAM] = data2;
    assign 	oFSM_DONE = done_2;//done_1;
    
    
    always@(posedge iSYS_CLK)
    begin
		if(~iSYS_RST)
			begin
				counter			<=	0;
//				counter_Tlast   <=  0;
				counter_working <=	0;
				data1           <=	0;
				data2           <=	0;
				working_1       <=	0;
				working_2       <=	0;
				done_1          <=	0;
				done_2          <=	0;
				count_Tlast_done_p <= 0;
				count_Tlast_done_p2<=0;
			end		
		else
		    begin
		        counter 		<= (iFSM_START)? 0 : (iWm_Tready & mem_working)? (counter + 2'd2) : counter;
//		        counter_Tlast 		<= (iFSM_START)? 0 : (iWm_Tready & mem_working)? (counter_Tlast==1024-2)? 0 :(counter_Tlast + 2'd2) : counter_Tlast;
		        counter_working <= iFSM_START? 1 : (counter_working & count_done)? 0 : counter_working;
		        data1 			<= iB_doutA;
		        data2 			<= iB_doutB;
		        working_1 		<= counter_working;
		        working_2 		<= working_1;
		        done_1 			<= count_done;
		        done_2 			<= done_1;
//		        count_Tlast_done_p <= count_Tlast_done;
//		        count_Tlast_done_p2 <= count_Tlast_done_p;
		    end
    end    
    assign 	oWm_Tlast = count_Tlast_done_p2;//done_1;
endmodule