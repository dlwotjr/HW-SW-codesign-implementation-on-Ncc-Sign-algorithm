//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :
//  HISTORY     :  2025-07-07 ¿ÀÈÄ PRM_ADDR:21:47
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module MDL_XXX_BUT_NTT#(
	parameter	PRM_DAXI	= 	64,
    parameter	PRM_ADDR	= 	12,
    parameter	PRM_DRAM	=	32,
    parameter	PRM_COEFFS	=	16,
    parameter	D    		=	30
)(
    input  							iSYS_CLK,
    input  							iSYS_RST,
    input  							iFSM_START,//1 for iFSM_START
    input  							iRead_start,
    input  							iComp_working,
    input  							iCTL_SEL, //0 for DIT, 1 for DIF
    input  			[1:0]			iCTL_Q, 
    input			[3:0]			iCTL_NTTDepth,
    output 							oFSM_DONE,
    output 	reg 					oSEL_keep,
    
    output							oZeta_en, //ROM for zeta
    output 	reg 	[PRM_ADDR-1:0]	oZeta_addr,
    input  			[30-1:0]		iZeta_dout,
                           
    output 							oB1_enA,//RAM for 256 coefficient
    output 							oB1_weA,
    output 			[PRM_ADDR-1:0] 	oB1_addrA,
    output 			[PRM_DRAM-1:0] 	oB1_dinA,
    input  			[PRM_DRAM-1:0] 	iB1_doutA,
  
    output 							oB1_enB,
    output 							oB1_weB,
    output 			[PRM_ADDR-1:0]	oB1_addrB,
    output 			[PRM_DRAM-1:0] 	oB1_dinB,
    input 			[PRM_DRAM-1:0]	iB1_doutB,
    
    output 							oB2_enA,
    output 							oB2_weA,
    output 			[PRM_ADDR-1:0]	oB2_addrA,
    output 			[PRM_DRAM-1:0] 	oB2_dinA,
    input  			[PRM_DRAM-1:0] 	iB2_doutA,
  
    output 							oB2_enB,
    output 							oB2_weB,
    output 			[PRM_ADDR-1:0]	oB2_addrB,
    output 			[PRM_DRAM-1:0] 	oB2_dinB,
    input 			[PRM_DRAM-1:0]	iB2_doutB,
    
    output 	reg 	[D-1:0] 		oBUT_iA,
    output 	reg 	[D-1:0] 		oBUT_iB, 
    output 	reg 	[D-1:0] 		oBUT_iW,
    input  			[D-1:0] 		iBUT_oA,
    input  			[D-1:0] 		iBUT_oB
    );
    
    function integer clog2;
	    input integer value;
	    integer i;
	    begin
	        clog2 = 0;
	        for (i = value - 1; i > 0; i = i >> 1)
	            clog2 = clog2 + 1;
	    end
	endfunction
    
    localparam integer PRM_LOGCO = clog2(PRM_COEFFS);
    localparam 	[D-1:0] 	PRM_Q1 		= 30'd134250497;
	localparam 	[D-1:0] 	PRM_Q2 		= 30'd536903681;
	wire    	[D-1:0]   	PRM_Q  		= (iCTL_Q==2'd1) ? PRM_Q2 : PRM_Q1;
    
    wire	[PRM_ADDR-1:0]	len;
    reg		[PRM_ADDR-1:0]	len_buf;
    reg 	[PRM_LOGCO-1:0]	counter1;
    reg 	[PRM_ADDR-1:0]	counter2;
    reg 	[PRM_LOGCO-2:0]	counter3;
    wire	[PRM_ADDR-1:0]	temp_loop2;
    wire 					count1_last,	count2_last,	count3_last;
    
    reg 					round_start_buf1,	round_start_buf2,	round_start_buf3,	round_start_buf4,	round_start_buf5,	round_start_buf6,	round_start_buf7,	round_start_buf8,	round_start_buf9,	round_start_buf10,	round_start_buf11,	round_start_buf12,	round_start_buf13,	round_start_buf14;
    reg  					count2_last_1,	count2_last_2,	count2_last_3,	count2_last_4,	count2_last_5,	count2_last_6,	count2_last_7,	count2_last_8,	count2_last_9,	count2_last_10,	count2_last_11,	count2_last_12,	count2_last_13,	count2_last_14,	count2_last_15,	count2_last_16;

    wire 					ntt_first;
    wire 					ntt_last;
    wire 	[PRM_LOGCO-1:0] max_level = iCTL_NTTDepth;
    
    wire 					count2_buf;    
    wire 					keep;
    reg 					running;
    reg 					running_buf;
    wire 					round_start;
    
    reg 	[PRM_ADDR-1:0] 	zeta_addr;
    reg		[PRM_DRAM-1:0] 	a1_buf_1,	b1_buf_1,a1_buf_2,	b1_buf_2,a1_buf_3,	b1_buf_3,a1_buf_4,	b1_buf_4,a1_buf_5,	b1_buf_5;
    wire	[PRM_ADDR-1:0] 	BFU1_addr,	BFU2_addr;
    reg		[PRM_ADDR-1:0] 	BFU1_addr_1,	BFU1_addr_2,	BFU1_addr_3,	BFU1_addr_4,	BFU1_addr_5,	BFU1_addr_6,	BFU1_addr_7,	BFU1_addr_8,	BFU1_addr_9,	BFU1_addr_10,	BFU1_addr_11,	BFU1_addr_12,	BFU1_addr_13,	BFU1_addr_14,	BFU1_addr_15;
    reg		[PRM_ADDR-1:0] 	BFU2_addr_1,	BFU2_addr_2,	BFU2_addr_3,	BFU2_addr_4,	BFU2_addr_5,	BFU2_addr_6,	BFU2_addr_7,	BFU2_addr_8,	BFU2_addr_9,	BFU2_addr_10,	BFU2_addr_11,	BFU2_addr_12,	BFU2_addr_13,	BFU2_addr_14,	BFU2_addr_15;
    reg 					block;
    reg 					wr_en;
    
    wire 					zeta_keep;
    wire 					start_stop;
    
    wire 	RAM_enable = running_buf || wr_en;
    assign 	len = (counter1 < iCTL_NTTDepth) ? (oSEL_keep ? (1<<counter1) : (PRM_COEFFS/2 >> counter1)): 0;
    assign 	temp_loop2 = counter3 + len_buf;
    assign 	ntt_first = (counter1 == 0);
    assign 	ntt_last    = (counter1 == max_level-1);
    assign 	count3_last = (counter3==(len-1'b1));
    assign 	count2_last = (counter2 == (PRM_COEFFS-1-temp_loop2));
    assign 	count1_last = (counter1 == (iCTL_NTTDepth-1)) && count2_last; 
    assign 	count2_buf = count2_last_1 | count2_last_2 | count2_last_3 | count2_last_4 | count2_last_5 | count2_last_6 | count2_last_7 | count2_last_8 | count2_last_9 | count2_last_10| count2_last_11 | count2_last_12 | count2_last_13;//| count2_last_14 | count2_last_15;
    assign 	keep =  (ntt_first&&(!count2_last))?0: (count2_last||count2_buf);
    assign 	round_start = (counter2 == 0)&(counter3==0)&(!keep)&running;
    assign 	BFU1_addr = counter2 + counter3;
    assign 	BFU2_addr = BFU1_addr + len;
    assign 	oB1_addrA = block? BFU1_addr_12:BFU1_addr_1;
    assign 	oB1_addrB = block? BFU2_addr_12:BFU2_addr_1;
    assign 	oB2_addrA = block? BFU1_addr_1:BFU1_addr_12;
    assign 	oB2_addrB = block? BFU2_addr_1:BFU2_addr_12;
    
    assign 	oB1_dinA = block? a1_buf_1 : 0; //a1_buf_5 : 0; //iBUT_oA:0;//a1_buf_1 : 0;
    assign 	oB1_dinB = block? b1_buf_1 : 0; //b1_buf_5 : 0; //iBUT_oB:0;//b1_buf_1 : 0;
    assign 	oB2_dinA = block? 0  : a1_buf_1;//0  : a1_buf_5;//0:iBUT_oA;//0  : a1_buf_1;
    assign 	oB2_dinB = block? 0  : b1_buf_1;//0  : b1_buf_5;//0:iBUT_oB;//0  : b1_buf_1;
    assign 	oZeta_en = running_buf;
    assign 	oB1_enA = RAM_enable;
    assign 	oB1_enB = RAM_enable;
    assign 	oB2_enA = RAM_enable;
    assign 	oB2_enB = RAM_enable;
    assign 	oB1_weA = (block&&wr_en)? 1 :0;
    assign 	oB1_weB = (block&&wr_en)? 1 :0;
    assign 	oB2_weA =  ((!block)&&wr_en)? 1 :0;
    assign 	oB2_weB =  ((!block)&&wr_en)? 1 :0;
    assign 	zeta_keep =  ntt_last&&count2_buf;
    assign 	oFSM_DONE = (!running)&&(wr_en)&&count2_last_12;
    assign 	start_stop = (iFSM_START||!iComp_working);
    
    always@(posedge iSYS_CLK)
    begin
    	if (!iSYS_RST) 
    	begin
    		oSEL_keep 		<= `A 0;
	        running 		<= `A 0;
	        running_buf 	<= `A 0;
	        wr_en 			<= `A 0;//delay -1
	        
	        block 			<= `A 0;
	        
	        zeta_addr		<= `A 0;
	        oZeta_addr 		<= `A 0;
	        
	        counter3 		<= `A 0;
	        counter2 		<= `A 0;
	        counter1 		<= `A 0;
	        
	        len_buf 		<= `A 0;
	        
	        count2_last_1 	<= `A 0;
	        count2_last_2 	<= `A 0;
	        count2_last_3 	<= `A 0;
	        count2_last_4 	<= `A 0;
	        count2_last_5 	<= `A 0;
	        count2_last_6 	<= `A 0;
	        count2_last_7 	<= `A 0;
	        count2_last_8 	<= `A 0;
	        count2_last_9 	<= `A 0;
	        count2_last_10 	<= `A 0;
	        count2_last_11 	<= `A 0;
	        count2_last_12 	<= `A 0;
	        count2_last_13 	<= `A 0;
//	        count2_last_14 	<= `A 0;
	        //count2_last_15 	<= `A 0;
	        //count2_last_16 	<= `A 0;
	        
	        round_start_buf1 <= `A 0;
	        round_start_buf2 <= `A 0;
	        round_start_buf3 <= `A 0;
	        round_start_buf4 <= `A 0;
	        round_start_buf5 <= `A 0;
	        round_start_buf6 <= `A 0;
	        round_start_buf7 <= `A 0;
	        round_start_buf8 <= `A 0;
	        round_start_buf9 <= `A 0;
	        round_start_buf10 <= `A 0;
	        round_start_buf11 <= `A 0;
//	        round_start_buf12 <= `A 0;
	        //round_start_buf13 <= `A 0;
	        //round_start_buf14 <= `A 0;
	        
	        oBUT_iA <= `A 0;
	        oBUT_iB <= `A 0;

	        oBUT_iW <= `A 0;
	        a1_buf_1 <= `A 0;
	        b1_buf_1 <= `A 0;
	        
	        BFU1_addr_1 <= `A 0;
	        BFU1_addr_2 <= `A 0;
	        BFU1_addr_3 <= `A 0;
	        BFU1_addr_4 <= `A 0;
	        BFU1_addr_5 <= `A 0;
	        BFU1_addr_6 <= `A 0;
	        BFU1_addr_7 <= `A 0;
	        BFU1_addr_8 <= `A 0;
	        BFU1_addr_9 <= `A 0;
	        BFU1_addr_10 <= `A 0;
	        BFU1_addr_11 <= `A 0;
	        BFU1_addr_12 <= `A 0;
//	        BFU1_addr_13 <= `A 0;
	        //BFU1_addr_14 <= `A 0;
	        //BFU1_addr_15 <= `A 0;
	        
	        BFU2_addr_1 <= `A 0;
	        BFU2_addr_2 <= `A 0;
	        BFU2_addr_3 <= `A 0;
	        BFU2_addr_4 <= `A 0;
	        BFU2_addr_5 <= `A 0;
	        BFU2_addr_6 <= `A 0;
	        BFU2_addr_7 <= `A 0;
	        BFU2_addr_8 <= `A 0;
	        BFU2_addr_9 <= `A 0;
	        BFU2_addr_10 <= `A 0;
	        BFU2_addr_11 <= `A 0;
	        BFU2_addr_12 <= `A 0;
//	        BFU2_addr_13 <= `A 0;
	        //BFU2_addr_14 <= `A 0;
	        //BFU2_addr_15 <= `A 0;
    	end
    	
    	else
    	begin
	        oSEL_keep 		<= `A (iRead_start)? iCTL_SEL : oSEL_keep;
	        running 		<= `A iFSM_START? 1'b1 : count1_last? 1'b0 : running;
	        running_buf 	<= `A running;
	        wr_en 			<= `A (round_start_buf11)? 1 : (count2_last_12)?0: wr_en;//delay -1
	        
	        block 			<= `A iFSM_START? 1'b0 : count2_last_13? ~block : block;
	        
	        zeta_addr		<= `A (iFSM_START)? (oSEL_keep? PRM_COEFFS-2:0): ((count3_last && (!zeta_keep))? (oSEL_keep? (zeta_addr-1'b1):(zeta_addr+1'b1)) : zeta_addr);
	        oZeta_addr 		<= `A zeta_addr;
	        
	        counter3 		<= `A (start_stop||count3_last||keep)? 0 : (counter3+1'b1);
	        counter2 		<= `A (start_stop||keep)? 0: (count3_last?(counter2+temp_loop2+1'b1):counter2);
	        counter1 		<= `A (start_stop)? 0 : count2_last? (counter1+1):counter1;
	        
	        len_buf 		<= `A len;
	        
	        count2_last_1 	<= `A count2_last;
	        count2_last_2 	<= `A count2_last_1;
	        count2_last_3 	<= `A count2_last_2;
	        count2_last_4 	<= `A count2_last_3;
	        count2_last_5 	<= `A count2_last_4;
	        count2_last_6 	<= `A count2_last_5;
	        count2_last_7 	<= `A count2_last_6;
	        count2_last_8 	<= `A count2_last_7;
	        count2_last_9 	<= `A count2_last_8;
	        count2_last_10 	<= `A count2_last_9;
	        count2_last_11 	<= `A count2_last_10;
	        count2_last_12 	<= `A count2_last_11;
	        count2_last_13 	<= `A count2_last_12;
//	        count2_last_14 	<= `A count2_last_13;
	        //count2_last_15 	<= `A count2_last_14;
	        //count2_last_16 	<= `A count2_last_15;
	        
	        round_start_buf1 <= `A round_start;
	        round_start_buf2 <= `A round_start_buf1;
	        round_start_buf3 <= `A round_start_buf2;
	        round_start_buf4 <= `A round_start_buf3;
	        round_start_buf5 <= `A round_start_buf4;
	        round_start_buf6 <= `A round_start_buf5;
	        round_start_buf7 <= `A round_start_buf6;
	        round_start_buf8 <= `A round_start_buf7;
	        round_start_buf9 <= `A round_start_buf8;
	        round_start_buf10 <= `A round_start_buf9;
	        round_start_buf11 <= `A round_start_buf10;
//	        round_start_buf12 <= `A round_start_buf11;
	        //round_start_buf13 <= `A round_start_buf12;
	        //round_start_buf14 <= `A round_start_buf13;
	        
	        oBUT_iA <= `A block? iB2_doutA[D-1:0]	: iB1_doutA[D-1:0];
	        oBUT_iB <= `A block? iB2_doutB[D-1:0]	: iB1_doutB[D-1:0];

	        oBUT_iW <= `A oSEL_keep? (PRM_Q - iZeta_dout):iZeta_dout;
	        a1_buf_1 <= `A iBUT_oA;
	        b1_buf_1 <= `A iBUT_oB;
	        
	        BFU1_addr_1 <= `A BFU1_addr;
	        BFU1_addr_2 <= `A BFU1_addr_1;
	        BFU1_addr_3 <= `A BFU1_addr_2;
	        BFU1_addr_4 <= `A BFU1_addr_3;
	        BFU1_addr_5 <= `A BFU1_addr_4;
	        BFU1_addr_6 <= `A BFU1_addr_5;
	        BFU1_addr_7 <= `A BFU1_addr_6;
	        BFU1_addr_8 <= `A BFU1_addr_7;
	        BFU1_addr_9 <= `A BFU1_addr_8;
	        BFU1_addr_10 <= `A BFU1_addr_9;
	        BFU1_addr_11 <= `A BFU1_addr_10;
	        BFU1_addr_12 <= `A BFU1_addr_11;
//	        BFU1_addr_13 <= `A BFU1_addr_12;
	        //BFU1_addr_14 <= `A BFU1_addr_13;
	        //BFU1_addr_15 <= `A BFU1_addr_14;
	        
	        BFU2_addr_1 <= `A BFU2_addr;
	        BFU2_addr_2 <= `A BFU2_addr_1;
	        BFU2_addr_3 <= `A BFU2_addr_2;
	        BFU2_addr_4 <= `A BFU2_addr_3;
	        BFU2_addr_5 <= `A BFU2_addr_4;
	        BFU2_addr_6 <= `A BFU2_addr_5;
	        BFU2_addr_7 <= `A BFU2_addr_6;
	        BFU2_addr_8 <= `A BFU2_addr_7;
	        BFU2_addr_9 <= `A BFU2_addr_8;
	        BFU2_addr_10 <= `A BFU2_addr_9;
	        BFU2_addr_11 <= `A BFU2_addr_10;
	        BFU2_addr_12 <= `A BFU2_addr_11;
//	        BFU2_addr_13 <= `A BFU2_addr_12;
	        //BFU2_addr_14 <= `A BFU2_addr_13;
	        //BFU2_addr_15 <= `A BFU2_addr_14;
        end
    end
    
endmodule 