`timescale 1ns/10ps
`define A #1

module TB_BFU_GS_pipe5;

localparam D = 28;
localparam  PARAM_Q = 134250497;

    // 테스트벤치의 입력 및 출력 신호 정의
    reg            	iSYS_CLK       	= 	1'b0;
    reg 			iSYS_RST		=	1'b1;
    reg 			iFSM_START		=	1'b0;
    reg            	sel       		= 	1'b0;
    reg  [D-1:0]    iA         		= 	28'b0;
    reg  [D-1:0]    iB         		= 	28'b0;
    reg  [D-1:0]    iW     			= 	28'b0;
    
    wire [D-1:0]    oA;
    wire [D-1:0]    oB;
    
    // 시스템 클럭 생성 (100 MHz, 주기 = 10 ns)
    initial begin    	
//    	#100 iSYS_RST = 0;
//		#100 iSYS_RST = 1;
//		#100;
		while(1) #5 iSYS_CLK = ~iSYS_CLK; // #5 means 100 MHz clock period
    end
    
    
    `define R @(posedge iSYS_CLK)
    `define W @(posedge iSYS_CLK) #1
    `define RR(n) repeat(n) `R
    `define WW(n) repeat(n) `W

    // DUT (Device Under Test) 인스턴스
    MDL_pipe_BUF #(
    	.PARAM_Q(PARAM_Q), 
    	.D(D)
    )
    uut (
        .iSYS_CLK	(iSYS_CLK	),
        .iSYS_RST	(iSYS_RST	),
        .sel		(sel		),
        .iFSM_START	(iFSM_START	),
        .iA			(iA			),
        .iB			(iB			),
        .iW			(iW			),
        .oA			(oA			),
        .oB			(oB			)
    );
    
    initial begin     
        #500 iSYS_RST = 0;
		#100 iSYS_RST = 1;
		
        $display("%12d: TEST START -------------------------------", $time);
        
        // 테스트 벡터 적용
        `W iFSM_START	= 1'b1;	sel = 1'b1;
        `W iA = 28'h1A3F2; iB = 28'h0F123; iW = 28'h07A5C; // 기본 입력
        `W iA = 28'h12345; iB = 28'h67890; iW = 28'h0ABC1; 
        `W iA = 28'h12123; iB = 28'h67949; iW = 28'h0ABC2; 
        `W iA = 28'h12732; iB = 28'h67000; iW = 28'h0ABC3; 
        `W iA = 28'h12098; iB = 28'h67111; iW = 28'h0ABC4; 

        $display("%12d: oA = %h, oB = %h", $time, oA, oB);
        
        #500;
        $display("%12d: TEST FINISHED ----------------------------", $time);
        $stop;
    end

endmodule
