//============================================================================
//  AUTHOR      :  YoungBeom Kim and jaeSeok Lee
//  SPEC        :  
//  HISTORY     :  2025-03-07 오전 11:05:37
//  Copyright   :  2025 Crypto & Security Engineering Laboratory. MIT license
//============================================================================

`include "./timescale.vh"

module MDL_FSM
(
	input	wire        	iSYS_CLK			,
	input	wire        	iSYS_RST			,

	// Control Signal
	input	wire	[2:0]	iFSM_MODE			,
	
	input	wire			iFSM_BUT_DONE		,
	input	wire			iFSM_KECCAK_DONE	,		
	
//	output			[1:0]	oFSM_BUT			,	
//	output					oFSM_KECCAK			,
	//output					oFSM_START
	output					oFSM_BUT_START		,
	output					oFSM_KECCAK_START
);

localparam	[1:0]	PRM_IDLE			= 2'd0;
localparam	[1:0]	PRM_KECCAK			= 2'd1;
localparam	[1:0]	PRM_BUT				= 2'd2;

reg	[1:0]	fsm;
//reg			start;
reg			BUT_start;
reg			KECCAK_start;

//assign	oFSM_IDLE			=	(fsm==PRM_IDLE);
//assign	oFSM_BUT			=	(fsm==PRM_BUT);
//assign	oFSM_KECCAK			=	(fsm==PRM_KECCAK);
//assign	oFSM_START			=	start;
assign	oFSM_BUT_START		=	BUT_start;
assign	oFSM_KECCAK_START	=	KECCAK_start;

always@(posedge iSYS_CLK)
begin
	if(~iSYS_RST)
	begin
		fsm		<= `A 'b0;
		BUT_start	<= `A 'b0;	
		KECCAK_start	<= `A 'b0;				
	end				
	else
	begin
		case(fsm)		
			PRM_IDLE:
			begin
				case(iFSM_MODE)
					PRM_BUT:
					begin
						fsm		<=`A PRM_BUT;
						BUT_start	<=`A 1'b1;
					end		
					PRM_KECCAK:
					begin
						fsm		<=`A PRM_KECCAK;
						KECCAK_start	<=`A 1'b1;
					end							
				endcase
			end			
			PRM_BUT: 
			begin
				if(iFSM_BUT_DONE)	fsm	<=`A PRM_IDLE;
				else
				begin
					fsm		<=`A fsm;
					BUT_start	<=`A 'b0;
				end				
			end	
			PRM_KECCAK: 
			begin
				if(iFSM_KECCAK_DONE)fsm	<=`A PRM_IDLE;
				else
				begin
					fsm		<=`A fsm;
					KECCAK_start	<=`A 'b0;
				end
			end		
			default: 				fsm <=`A fsm;
		endcase
	end
end

endmodule