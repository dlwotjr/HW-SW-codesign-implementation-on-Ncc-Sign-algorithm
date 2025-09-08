/*
https://keccak.team/keccak_specs_summary.html
expain in_w keccak team


Pseudo-code description of the permutations

Keccak-f[b](A) {
  for i in_w 0…n-1
    A = Round[b](A, RC[i])
  return A
}

Round[b](A,RC) {
  // θ step
  C[x] = A[x,0] xor A[x,1] xor A[x,2] xor A[x,3] xor A[x,4],   for x in_w 0…4
  D[x] = C[x-1] xor rot(C[x+1],1),                             for x in_w 0…4
  A[x,y] = A[x,y] xor D[x],                           for (x,y) in_w (0…4,0…4)

  // ρ and π steps
  B[y,2*x+3*y] = rot(A[x,y], r[x,y]),                 for (x,y) in_w (0…4,0…4)

  // χ step
  A[x,y] = B[x,y] xor ((not B[x+1,y]) and B[x+2,y]),  for (x,y) in_w (0…4,0…4)

  // ι step
  A[0,0] = A[0,0] xor RC

  return A
}


Pseudo-code description of the sponge functions

Keccak[r,c](Mbytes || Mbits) {
  # Padding
  d = 2^|Mbits| + sum for i=0..|Mbits|-1 of 2^i*Mbits[i]
  P = Mbytes || d || 0x00 || … || 0x00
  P = P xor (0x00 || … || 0x00 || 0x80)

  # Initialization
  S[x,y] = 0,                               for (x,y) in_w (0…4,0…4)

  # Absorbing phase
  for each block Pi in_w P
    S[x,y] = S[x,y] xor Pi[x+5*y],          for (x,y) such that x+5*y < r/w
    S = Keccak-f[r+c](S)

  # Squeezing phase
  Z = empty string
  while output is requested
    Z = Z || S[x,y],                        for (x,y) such that x+5*y < r/w
    S = Keccak-f[r+c](S)

  return Z
}
*/

`include "./timescale.vh"

module MDL_XXX_keccak(
	input				iSYS_CLK	,
	input				iSYS_RST	,
	input				iFSM_START	,
	input	[1599:0] 	iN			,
	output 	[1599:0] 	oR			,
	output				oFSM_DONE
);
	
	localparam 			D 	= 1;
	localparam integer 	W 	= 64;
	localparam integer 	T 	= 25;    //Total count_r
	localparam integer 	F 	= T<<6;  //F
	
	//W*24
	// round constant value
	parameter RC = {
		64'h0000000000000001, 64'h0000000000008082,64'h800000000000808a, 64'h8000000080008000,
		64'h000000000000808b, 64'h0000000080000001,64'h8000000080008081, 64'h8000000000008009,
		64'h000000000000008a, 64'h0000000000000088,64'h0000000080008009, 64'h000000008000000a,
		64'h000000008000808b, 64'h800000000000008b,64'h8000000000008089, 64'h8000000000008003,
		64'h8000000000008002, 64'h8000000000000080,64'h000000000000800a, 64'h800000008000000a,
		64'h8000000080008081, 64'h8000000000008080,64'h0000000080000001, 64'h8000000080008008};
		
	reg 				fsm;
	localparam	PRM_IDLE = 1'b0;
	localparam	PRM_COMPUTE = 1'b1;
	
	wire [F-1:0]		in_w;		
		
	reg  [5:0]			count_r;
	reg  [W*24-1:0]		RC_r;
	reg 				done_r;
	
	
	reg  [F-1:0]		A_r;		
	wire [W*5-1:0]		B_w;
	wire [F-1:0]		C_w;
	wire [F-1:0]		D_w; 
	wire [F-1:0]		E_w; 
	
	function [W-1:0] Arrange;
        input [W-1:0] Data;
        begin
        	Arrange = {Data[63:56],Data[55:48],Data[47:40],Data[39:32],Data[31:24],Data[23:16],Data[15:8],Data[7:0]};
        end
    endfunction
	
	function [63:0]	ROL1;
		input [63:0] data;
		begin
			ROL1 = {data[62:0],data[63]};
		end
	endfunction
	
	function [W-1:0] ROL;
        input [W-1:0] data;
        input [5:0] rot;
        begin
            ROL = (data << rot) | (data >> (W - rot));
        end
    endfunction
    
    // Reordering of keccak
	genvar i,j;
	generate
	    for (i = 0; i < T; i = i + 1) begin
	        localparam base_in = (T - i) << 6;
	        assign in_w[base_in - 1 : base_in - W] = Arrange(iN[base_in - 1 : base_in - W]);
	    end
	endgenerate		
	
	/*
	θ step
	Theta-1
	  C_w[x] = A_r[x,0] xor A_r[x,1] xor A_r[x,2] xor A_r[x,3] xor A_r[x,4],   for x in_w 0…4
	Theta-2  
	  D_w[x] = C_w[x-1] xor rot(C_w[x+1],1),                             for x in_w 0…4
	  A_r[x,y] = A_r[x,y] xor D_w[x],                           for (x,y) in_w (0…4,0…4)
	*/
	//---Theta-1---
	//B_w[x] = A_r[x,0] xor A_r[x,1] xor A_r[x,2] xor A_r[x,3] xor A_r[x,4],   for x in_w 0…4
	generate
	    for (i = 0; i < 5; i = i + 1) begin
	        assign B_w[((5-i) << 6)-1:((4-i) << 6)] = 					A_r[((25-i) 		<< 6)-1 :((24-i) 			<< 6)]^ 
	                                                					A_r[((20-i) 		<< 6)-1 :((19-i) 			<< 6)]^ 
	                                                					A_r[((15-i) 		<< 6)-1 :((14-i) 			<< 6)]^ 
	                                                					A_r[((10-i) 		<< 6)-1 :((9-i)  			<< 6)]^ 
	                                                					A_r[((5-i)  		<< 6)-1 :((4-i)  			<< 6)];
	    end
	endgenerate
	
	//---Theta-2---
	//C_w[x] = B_w[x-1] xor rot(B_w[x+1],1) xor  A_r[x,y]                  for (x,y) in_w (0…4,0…4)
	assign C_w[F-1:W*24] = A_r[F-1:W*24]^B_w[W*1-1:0]^ROL1(B_w[W*4-1:W*3]);
	assign C_w[W*20-1:W*19] = A_r[W*20-1:W*19]^B_w[W*1-1:0]^ROL1(B_w[W*4-1:W*3]);
	assign C_w[W*15-1:W*14] = A_r[W*15-1:W*14]^B_w[W*1-1:0]^ROL1(B_w[W*4-1:W*3]);
	assign C_w[W*10-1:W* 9] = A_r[W*10-1:W* 9]^B_w[W*1-1:0]^ROL1(B_w[W*4-1:W*3]);
	assign C_w[W* 5-1:W* 4] = A_r[W* 5-1:W* 4]^B_w[W*1-1:0]^ROL1(B_w[W*4-1:W*3]);
	//i=1
	assign C_w[W*24-1:W*23] = A_r[W*24-1:W*23]^B_w[W*5-1:W*4]^ROL1(B_w[W*3-1:W*2]);
	assign C_w[W*19-1:W*18] = A_r[W*19-1:W*18]^B_w[W*5-1:W*4]^ROL1(B_w[W*3-1:W*2]);
	assign C_w[W*14-1:W*13] = A_r[W*14-1:W*13]^B_w[W*5-1:W*4]^ROL1(B_w[W*3-1:W*2]);
	assign C_w[W* 9-1:W* 8] = A_r[W* 9-1:W* 8]^B_w[W*5-1:W*4]^ROL1(B_w[W*3-1:W*2]);
	assign C_w[W* 4-1:W* 3] = A_r[W* 4-1:W* 3]^B_w[W*5-1:W*4]^ROL1(B_w[W*3-1:W*2]);
	//i=2                                                                               
	assign C_w[W*23-1:W*22] = A_r[W*23-1:W*22]^B_w[W*4-1:W*3]^ROL1(B_w[W*2-1:W*1]);
	assign C_w[W*18-1:W*17] = A_r[W*18-1:W*17]^B_w[W*4-1:W*3]^ROL1(B_w[W*2-1:W*1]);
	assign C_w[W*13-1:W*12] = A_r[W*13-1:W*12]^B_w[W*4-1:W*3]^ROL1(B_w[W*2-1:W*1]);
	assign C_w[W* 8-1:W* 7] = A_r[W* 8-1:W* 7]^B_w[W*4-1:W*3]^ROL1(B_w[W*2-1:W*1]);
	assign C_w[W* 3-1:W* 2] = A_r[W* 3-1:W* 2]^B_w[W*4-1:W*3]^ROL1(B_w[W*2-1:W*1]);
	//i=3                                                                               
	assign C_w[W*22-1:W*21] = A_r[W*22-1:W*21]^B_w[W*3-1:W*2]^ROL1(B_w[W*1-1:0]);
	assign C_w[W*17-1:W*16] = A_r[W*17-1:W*16]^B_w[W*3-1:W*2]^ROL1(B_w[W*1-1:0]);
	assign C_w[W*12-1:W*11] = A_r[W*12-1:W*11]^B_w[W*3-1:W*2]^ROL1(B_w[W*1-1:0]);
	assign C_w[W* 7-1:W* 6] = A_r[W* 7-1:W* 6]^B_w[W*3-1:W*2]^ROL1(B_w[W*1-1:0]);
	assign C_w[W* 2-1:W* 1] = A_r[W* 2-1:W* 1]^B_w[W*3-1:W*2]^ROL1(B_w[W*1-1:0]);
	//i=4                                                                               
	assign C_w[W*21-1:W*20] = A_r[W*21-1:W*20]^B_w[W*2-1:W*1]^ROL1(B_w[W*5-1:W*4]);
	assign C_w[W*16-1:W*15] = A_r[W*16-1:W*15]^B_w[W*2-1:W*1]^ROL1(B_w[W*5-1:W*4]);
	assign C_w[W*11-1:W*10] = A_r[W*11-1:W*10]^B_w[W*2-1:W*1]^ROL1(B_w[W*5-1:W*4]);
	assign C_w[W* 6-1:W* 5] = A_r[W* 6-1:W* 5]^B_w[W*2-1:W*1]^ROL1(B_w[W*5-1:W*4]);
	assign C_w[W* 1-1:W* 0] = A_r[W* 1-1:W* 0]^B_w[W*2-1:W*1]^ROL1(B_w[W*5-1:W*4]);
	
	// ρ and π steps
  	//D_w[y,2*x+3*y] = rot(C_w[x,y], r[x,y]),                 for (x,y) in_w (0…4,0…4)
	//---Rho Pi---
	assign D_w[F-1:W*24] 	= C_w[F-1:W*24];
	assign D_w[W*15-1:W*14] = ROL(C_w[W*24-1:W*23],1 );    
	assign D_w[W*18-1:W*17] = ROL(C_w[W*15-1:W*14],3 );    
	assign D_w[W*14-1:W*13] = ROL(C_w[W*18-1:W*17],6 );    
	assign D_w[W* 8-1:W* 7] = ROL(C_w[W*14-1:W*13],10);    
	assign D_w[W* 7-1:W* 6] = ROL(C_w[W* 8-1:W* 7],15);    
	assign D_w[W*22-1:W*21] = ROL(C_w[W* 7-1:W* 6],21);    
	assign D_w[W*20-1:W*19] = ROL(C_w[W*22-1:W*21],28);    
	assign D_w[W* 9-1:W* 8] = ROL(C_w[W*20-1:W*19],36);    
	assign D_w[W*17-1:W*16] = ROL(C_w[W* 9-1:W* 8],45);    
	assign D_w[W* 4-1:W* 3] = ROL(C_w[W*17-1:W*16],55);    
	assign D_w[W* 1-1:W* 0] = ROL(C_w[W* 4-1:W* 3],2 );    
	assign D_w[W*21-1:W*20] = ROL(C_w[W* 1-1:W* 0],14);    
	assign D_w[W*10-1:W* 9] = ROL(C_w[W*21-1:W*20],27);    
	assign D_w[W* 2-1:W* 1] = ROL(C_w[W*10-1:W* 9],41);    
	assign D_w[W* 6-1:W* 5] = ROL(C_w[W* 2-1:W* 1],56);    
	assign D_w[W*12-1:W*11] = ROL(C_w[W* 6-1:W* 5],8 );    
	assign D_w[W*13-1:W*12] = ROL(C_w[W*12-1:W*11],T);    
	assign D_w[W*23-1:W*22] = ROL(C_w[W*13-1:W*12],43);    
	assign D_w[W* 5-1:W* 4] = ROL(C_w[W*23-1:W*22],62);    
	assign D_w[W*11-1:W*10] = ROL(C_w[W* 5-1:W* 4],18);    
	assign D_w[W* 3-1:W* 2] = ROL(C_w[W*11-1:W*10],39);    
	assign D_w[W*16-1:W*15] = ROL(C_w[W* 3-1:W* 2],61);    
	assign D_w[W*19-1:W*18] = ROL(C_w[W*16-1:W*15],20);    
	assign D_w[W*24-1:W*23] = ROL(C_w[W*19-1:W*18],44);   

	// χ step
    //E_w[x,y] = B_w[x,y] xor ((not B_w[x+1,y]) and B_w[x+2,y]),  for (x,y) in_w (0…4,0…4)
	assign E_w[F-1:W*24] 	= D_w[F-1   :W*24]^((~D_w[W*24-1:W*23])&D_w[W*23-1:W*22]); //j=0,i=0:cs[0] = s[0]^((~s[1])&s[2]);
	assign E_w[W*24-1:W*23] = D_w[W*24-1:W*23]^((~D_w[W*23-1:W*22])&D_w[W*22-1:W*21]); //j=0,i=1:cs[1] = s[1]^((~s[2])&s[3]);
	assign E_w[W*23-1:W*22] = D_w[W*23-1:W*22]^((~D_w[W*22-1:W*21])&D_w[W*21-1:W*20]); //j=0,i=2:cs[2] = s[2]^((~s[3])&s[4]);
	assign E_w[W*22-1:W*21] = D_w[W*22-1:W*21]^((~D_w[W*21-1:W*20])&D_w[F-1   :W*24]); //j=0,i=3:cs[3] = s[3]^((~s[4])&s[0]);
	assign E_w[W*21-1:W*20] = D_w[W*21-1:W*20]^((~D_w[F-1   :W*24])&D_w[W*24-1:W*23]); //j=0,i=4:cs[4] = s[4]^((~s[0])&s[1]);
	//--                                                                                           
	assign E_w[W*20-1:W*19] = D_w[W*20-1:W*19]^((~D_w[W*19-1:W*18])&D_w[W*18-1:W*17]); //j=5,i=0:cs[5] = s[5]^((~s[6])&s[7]);
	assign E_w[W*19-1:W*18] = D_w[W*19-1:W*18]^((~D_w[W*18-1:W*17])&D_w[W*17-1:W*16]); //j=5,i=1:cs[6] = s[6]^((~s[7])&s[8]);
	assign E_w[W*18-1:W*17] = D_w[W*18-1:W*17]^((~D_w[W*17-1:W*16])&D_w[W*16-1:W*15]); //j=5,i=2:cs[7] = s[7]^((~s[8])&s[9]);
	assign E_w[W*17-1:W*16] = D_w[W*17-1:W*16]^((~D_w[W*16-1:W*15])&D_w[W*20-1:W*19]); //j=5,i=3:cs[8] = s[8]^((~s[9])&s[5]);
	assign E_w[W*16-1:W*15] = D_w[W*16-1:W*15]^((~D_w[W*20-1:W*19])&D_w[W*19-1:W*18]); //j=5,i=4:cs[9] = s[9]^((~s[5])&s[6]);	
    //--                                                                                
	assign E_w[W*15-1:W*14] = D_w[W*15-1:W*14]^((~D_w[W*14-1:W*13])&D_w[W*13-1:W*12]); //j=10,i=0:cs[10] = s[10]^((~s[11])&s[12]);
	assign E_w[W*14-1:W*13] = D_w[W*14-1:W*13]^((~D_w[W*13-1:W*12])&D_w[W*12-1:W*11]); //j=10,i=1:cs[11] = s[11]^((~s[12])&s[13]);
	assign E_w[W*13-1:W*12] = D_w[W*13-1:W*12]^((~D_w[W*12-1:W*11])&D_w[W*11-1:W*10]); //j=10,i=2:cs[12] = s[12]^((~s[13])&s[14]);
	assign E_w[W*12-1:W*11] = D_w[W*12-1:W*11]^((~D_w[W*11-1:W*10])&D_w[W*15-1:W*14]); //j=10,i=3:cs[13] = s[13]^((~s[14])&s[11]);
	assign E_w[W*11-1:W*10] = D_w[W*11-1:W*10]^((~D_w[W*15-1:W*14])&D_w[W*14-1:W*13]); //j=10,i=4:cs[14] = s[14]^((~s[15])&s[12]);	
	//--                                                                                   
	assign E_w[W*10-1:W* 9] = D_w[W*10-1:W* 9]^((~D_w[W* 9-1:W* 8])&D_w[W* 8-1:W* 7]); //j=15,i=0:cs[15] = s[15]^((~s[16])&s[17]);
	assign E_w[W* 9-1:W* 8] = D_w[W* 9-1:W* 8]^((~D_w[W* 8-1:W* 7])&D_w[W* 7-1:W* 6]); //j=15,i=1:cs[16] = s[16]^((~s[17])&s[18]);
	assign E_w[W* 8-1:W* 7] = D_w[W* 8-1:W* 7]^((~D_w[W* 7-1:W* 6])&D_w[W* 6-1:W* 5]); //j=15,i=2:cs[17] = s[17]^((~s[18])&s[19]);
	assign E_w[W* 7-1:W* 6] = D_w[W* 7-1:W* 6]^((~D_w[W* 6-1:W* 5])&D_w[W*10-1:W* 9]); //j=15,i=3:cs[18] = s[18]^((~s[19])&s[15]);
	assign E_w[W* 6-1:W* 5] = D_w[W* 6-1:W* 5]^((~D_w[W*10-1:W* 9])&D_w[W* 9-1:W* 8]); //j=15,i=4:cs[19] = s[19]^((~s[15])&s[16]);	
			//--                                                                                   
	assign E_w[W* 5-1:W* 4] = D_w[W* 5-1:W* 4]^((~D_w[W* 4-1:W* 3])&D_w[W* 3-1:W* 2]); //j=20,i=0:cs[20] = s[20]^((~s[21])&s[22]);
	assign E_w[W* 4-1:W* 3] = D_w[W* 4-1:W* 3]^((~D_w[W* 3-1:W* 2])&D_w[W* 2-1:W* 1]); //j=20,i=1:cs[21] = s[21]^((~s[22])&s[23]);
	assign E_w[W* 3-1:W* 2] = D_w[W* 3-1:W* 2]^((~D_w[W* 2-1:W* 1])&D_w[W* 1-1:W* 0]); //j=20,i=2:cs[22] = s[22]^((~s[23])&s[24]);
	assign E_w[W* 2-1:W* 1] = D_w[W* 2-1:W* 1]^((~D_w[W* 1-1:W* 0])&D_w[W* 5-1:W* 4]); //j=20,i=3:cs[23] = s[23]^((~s[24])&s[20]);
	assign E_w[W* 1-1:W* 0] = D_w[W* 1-1:W* 0]^((~D_w[W* 5-1:W* 4])&D_w[W* 4-1:W* 3]); //j=20,i=4:cs[24] = s[24]^((~s[20])&s[21]);	
	
	always@(posedge iSYS_CLK) begin
		if(!iSYS_RST) begin
			$display("KECCAK inside reset");
			A_r 	<= `A 1600'b0;
			count_r	<= `A 5'd0;
			RC_r 	<= `A 1536'b0;
			done_r 	<= `A 1'b0;
			fsm 	<= `A 1'b0;
		end else begin
			case(fsm)
				PRM_IDLE: begin
					done_r <= `A 1'b0;
					if(iFSM_START) 
					begin
						$display("KECCAK inside | fsm : IDLE | done_r : %b | round : %h", done_r, count_r);
						count_r<= `A 5'd0;
						A_r <= `A in_w; //input
						RC_r <= `A RC;
						fsm <= `A PRM_COMPUTE;	
					end
				end
				PRM_COMPUTE : begin
					$display("KECCAK inside | fsm : COMPUTE | done_r : %b | round : %d | ", done_r, count_r);
					count_r <= `A count_r + 1'b1;
					A_r[W*24-1:0]<= `A E_w[W*24-1:0];
					A_r[F-1:W*24] <= `A E_w[F-1:W*24]^RC_r[W*24-1:W*23];
					RC_r <= `A {RC_r[W*23-1:0],64'b0};
					if(count_r==5'h17) begin
						$display("KECCAK inside | KECCAK DONE | oR : %h |", oR);
						done_r 	<= `A 1'b1;
						fsm 	<= `A PRM_IDLE;
					end
				end
			endcase
		end
	end

	assign oR[F-1:W*24] = Arrange(A_r[F-1:W*24]);
	assign oR[W*24-1:W*23] = Arrange(A_r[W*24-1:W*23]);
	assign oR[W*23-1:W*22] = Arrange(A_r[W*23-1:W*22]);
	assign oR[W*22-1:W*21] = Arrange(A_r[W*22-1:W*21]);
	assign oR[W*21-1:W*20] = Arrange(A_r[W*21-1:W*20]);
	assign oR[W*20-1:W*19] = Arrange(A_r[W*20-1:W*19]);
	assign oR[W*19-1:W*18] = Arrange(A_r[W*19-1:W*18]);
	assign oR[W*18-1:W*17] = Arrange(A_r[W*18-1:W*17]);
	assign oR[W*17-1:W*16] = Arrange(A_r[W*17-1:W*16]);
	assign oR[W*16-1:W*15] = Arrange(A_r[W*16-1:W*15]);
	assign oR[W*15-1:W*14] = Arrange(A_r[W*15-1:W*14]);
	assign oR[W*14-1:W*13] = Arrange(A_r[W*14-1:W*13]);
	assign oR[W*13-1:W*12] = Arrange(A_r[W*13-1:W*12]);
	assign oR[W*12-1:W*11] = Arrange(A_r[W*12-1:W*11]);
	assign oR[W*11-1:W*10] = Arrange(A_r[W*11-1:W*10]);
	assign oR[W*10-1:W* 9] = Arrange(A_r[W*10-1:W* 9]);
	assign oR[W* 9-1:W* 8] = Arrange(A_r[W* 9-1:W* 8]);	
	assign oR[W* 8-1:W* 7] = Arrange(A_r[W* 8-1:W* 7]);
	assign oR[W* 7-1:W* 6] = Arrange(A_r[W* 7-1:W* 6]);	
	assign oR[W* 6-1:W* 5] = Arrange(A_r[W* 6-1:W* 5]);
	assign oR[W* 5-1:W* 4] = Arrange(A_r[W* 5-1:W* 4]);	
	assign oR[W* 4-1:W* 3] = Arrange(A_r[W* 4-1:W* 3]);
	assign oR[W* 3-1:W* 2] = Arrange(A_r[W* 3-1:W* 2]);	
	assign oR[W* 2-1:W* 1] = Arrange(A_r[W* 2-1:W* 1]);
	assign oR[W* 1-1:W* 0] = Arrange(A_r[W* 1-1:W* 0]);			
	
	
	assign oFSM_DONE = done_r;
	
		
//	wire [W-1:0]	seta_res 	[24:0];
//	wire [W-1:0] 	pi_rho_res 	[24:0];
//	wire [W-1:0]	chi_res 	[24:0];
//	generate
//	    for (i = 0; i < T; i = i + 1) begin : assign_slices
//	    //θ step result
//        assign seta_res[i] 		= C_w[W*(T-i)-1 : W*(24-i)];
//        // ρ and π steps result
//        assign pi_rho_res[i] 	= D_w[W*(T-i)-1 : W*(24-i)];
//        //χ step result
//        assign chi_res[i] 		= E_w[W*(T-i)-1 : W*(24-i)];
//	    end
//	endgenerate	
		
endmodule
