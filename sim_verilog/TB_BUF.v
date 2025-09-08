`timescale 1ns/10ps
`define A #1

module TB_BFU;

localparam D = 28;
localparam  PARAM_Q = 134250497;

    // 테스트벤치의 입력 및 출력 신호 정의
    reg            clk       = 1'b0;
    reg            sel       = 1'b0;
    reg  [D-1:0]    a         = 23'b0;
    reg  [D-1:0]    b         = 23'b0;
    reg  [D-1:0]    omiga     = 23'b0;
    
    wire [D-1:0]    a1;
    wire [D-1:0]    b1;

    
    // 시스템 클럭 생성 (100 MHz, 주기 = 10 ns)
    initial begin
        #100;
        while (1) #5 clk = ~clk;
    end
    
    `define R @(posedge clk)
    `define W @(posedge clk) #1
    `define RR(n) repeat(n) `R
    `define WW(n) repeat(n) `W

    // DUT (Device Under Test) 인스턴스
    compact_BFU_no #(
    .PARAM_Q(PARAM_Q), .D(D)
    )
    uut (
        .clk(clk),
        .sel(sel),
        .a(a),
        .b(b),
        .omiga(omiga),
        .a1(a1),
        .b1(b1)
    );

    always @(posedge clk) begin
        //$display("%12d: Inside UUT - a_pipeline = %h, b_pipeline = %h", $time, uut.a_pipeline_1, uut.b_pipeline_1);
        $display("%12d: Inside UUT - mul_result = %h", $time, uut.mul_result);
    end

    
    initial begin
        #500;
        $display("%12d: TEST START -------------------------------", $time);
        
        // 테스트 벡터 적용
        `W sel = 1'b0;
        `W a = 23'h1A3F2; b = 23'h0F123; omiga = 23'h07A5C; // 기본 입력
        //`W a = 23'h12345; b = 23'h67890; omiga = 23'h0ABC1;
        //`W a = 23'h7FFFF; b = 23'h00001; omiga = 23'h12345;
        //`W sel = 1'b1;
        //`W a = 23'h54321; b = 23'h0FFFF; omiga = 23'h1A2B3;
        //`W a = 23'h7ABCD; b = 23'h12345; omiga = 23'h0F1F1;
        
        // 출력 확인
        $display("%12d: a1 = %h, b1 = %h", $time, a1, b1);
        
        // 추가 변수 출력
        //$display("%12d: opt1_final = %h", $time, uut.opt1_final);
        //$display("%12d: butterfly_add_input = %h", $time, uut.butterfly_add_input);
        //$display("%12d: butterfly_sub_stage = %h", $time, uut.butterfly_sub_stage);
        //$display("%12d: mul_result_pipeline = %h", $time, uut.mul_result_pipeline);
        //$display("%12d: butterfly_add_stage = %h", $time, uut.butterfly_add_stage);
        //$display("%12d: a1_final = %h", $time, uut.a1_final);
        //$display("%12d: b1_final = %h", $time, uut.b1_final);
        
        // 출력 확인
        $display("%12d: a1 = %h, b1 = %h", $time, a1, b1);
        
        #500;
        $display("%12d: TEST FINISHED ----------------------------", $time);
        $stop;
    end

endmodule
