
module oup_sm_ulpi_syncmode(
	input rst,
	input  ulpi_clk,
	inout  [7:0]ulpi_data,
	input  ulpi_dir,
	output ulpi_stp,
	input  ulpi_nxt,
	input [7:0]instruction,		// Must be held constant until instruction execution is done.
	input exec,						// To execute instruction, assert for one cycle.
	output reg exec_done,		// This is asserted when instruction execution is done.
	output reg exec_aborted,	// This is asserted when the instruction execution was aborted by a read operation.
	input [7:0]tx_data,			// Data to be transmitted to USB. Comes from a FIFO.
	output reg tx_data_next,   // 
	input tx_data_empty,			// Indicates FIFO is empty
	output reg [7:0]rx_data,      // Data received from USB. Goes into a FIFO.
	output reg rx_data_next,		// 
	input rx_data_full,				// TODO: implement. Indicates FIFO is full.
	output reg [7:0]rx_cmd_byte,	// Defined in table 7 of standard.
	input [7:0]phyreg_i,				// Data input for ULPI register writes
	input [7:0]phyreg_addr_i,		// Address input for ULPI register writes
	output reg [7:0]phyreg_o,		// Data output for ULPI register reads
	output reg [7:0]phyreg_addr_o // Address output for ULPI register reads

);

	// TODO: implement exec_aborted output logic.
	// TODO: separate this into two state machines: RX machine and TX machine. Would help readability and expansion.
			
	parameter	st_rx_command 			= 6'b100000,	// Receive RX CMD from table 7.
					st_rx_abort				= 6'b100001,	// Abort reading register read data.
					st_rx_regr_extr_data = 6'b100010,	// Receive register read data.
					st_rx_success			= 6'b100011,	// Register read sucessful
					st_rx_regr_extr_read = 6'b101111,	// Prepare to receive register read data.
					st_rx_data 				= 6'b110000,	// Receive USB data.
					st_tx_idle				= 6'b0?0000,	// Transmit NOOP and execute next instruction
					st_tx_abort				= 6'b0?0001,	// Instruction aborted
					st_tx_regr_extr_data = 6'b0?0010,	// Register read (was) in progress
					st_tx_success			= 6'b0?0011,	// Register read successful
					st_tx_transmit_start = 6'b0?0100,	// Transmit TX PID or TXNOPID.
					st_tx_transmit_data	= 6'b0?0101,	// Transmit USB data.
					st_tx_transmit_stop	= 6'b0?0110,	// Stop because there is no more data to transmit.
					st_tx_transmit_abort	= 6'b0?0111,	// Abort due to buffer underrun (assert stp and send FF to dataout).
					st_tx_regw_addr		= 6'b0?1000,	// Transmit REGW address.
					st_tx_extw_addr		= 6'b0?1001,	// Transmit EXTW address (8'b10101111).
					st_tx_extw_extaddr	= 6'b0?1010,	// Transmit EXTW extended address (8 bit adress).
					st_tx_regw_extw_data	= 6'b0?1011,	// Transmit register write data.
					st_tx_regr_addr		= 6'b0?1100,	// Transmit REGR address.
					st_tx_extr_addr		= 6'b0?1101,	// Transmit EXTR address (8'b11101111).
					st_tx_extr_extaddr	= 6'b0?1110,	// Transmit EXTR extended address (8 bit address).
					st_tx_regr_extr_read	= 6'b0?1111;	// Perform REGR or EXTR register read.
					
	parameter 	ins_Special		= 2'b00,
					ins_Transmit 	= 2'b01,
					ins_RegWrite	= 2'b10,
					ins_RegRead		= 2'b11;				
					
					

	reg	[5:0]state = 6'b0;
	reg	[5:0]nextstate;
	reg	turnover = 1'b0;
	
	reg 	[7:0]ulpi_data_out;
	reg 	ulpi_stp_out;
	
	reg 	[7:0]ulpi_data_latched;
	
	assign ulpi_stp = ulpi_stp_out;
	assign ulpi_data = (ulpi_dir)? 8'bzzzzzzzz : ulpi_data_out; // Don't modify.
	// Damage to FPGA I/O is possible if this line is modified.
	
	function [3:0] decode_instruction;
		input[7:0] instruction;
		begin
			case(instruction[7:6])
				ins_Special: begin
					decode_instruction = st_tx_idle[3:0];
					end
				ins_Transmit: begin
					decode_instruction = st_tx_transmit_start[3:0];
					end
				ins_RegWrite: begin
					if(instruction[5:0] == 6'b101111)
						decode_instruction = st_tx_extw_addr[3:0];
					else
						decode_instruction = st_tx_regw_addr[3:0];
					end
				ins_RegRead: begin
					if(instruction[5:0] == 6'b101111)
						decode_instruction = st_tx_extr_addr[3:0];
					else
						decode_instruction = st_tx_regr_addr[3:0];
					end
				default: decode_instruction = 4'b0000;
			endcase
		end
	endfunction
	
	always@(negedge ulpi_clk)
		begin: state_latch
			if(rst)
				state <= 6'b0;
			else
				state <= nextstate;
		end
	always@(negedge ulpi_clk)
		begin: other_latch
			ulpi_data_latched <= ulpi_data;
			turnover <= state[5] ^ nextstate[5]; // [5] is DIR
		end
	

	
	always@(state or nextstate or instruction or exec or ulpi_dir or ulpi_nxt or tx_data_empty)
		begin: next_state_logic
		
			nextstate[5] = ulpi_dir;	// Used to switch between RX and TX states.
			nextstate[4] = ulpi_nxt;	// Used on RX states, ignored by TX states.
			
			
			if(state[5] == 1'b0 && nextstate[5] == 1'b0) begin
				// TX states
				case(state[3:0])
					st_tx_idle[3:0]: 					begin
						if(exec)
							nextstate[3:0] = decode_instruction(instruction);
						else
							nextstate[3:0] = st_tx_idle[3:0];
						end
					st_tx_abort[3:0]: 			nextstate[3:0] = st_tx_idle[3:0];
					st_tx_regr_extr_data[3:0]: 			nextstate[3:0] = st_tx_idle[3:0];
					st_tx_success[3:0]: 			nextstate[3:0] = st_tx_idle[3:0];
					st_tx_transmit_start[3:0]: 	begin		
						if(ulpi_nxt) begin
								if(!tx_data_empty)
									nextstate[3:0] = st_tx_transmit_data[3:0];
								else
									nextstate[3:0] = st_tx_transmit_abort[3:0];
									// TODO: transmit high-speed abort if PHY is set up as high-speed
									// (inverted CRC instead of the st_tx_transmit_abort state)
								end
						else
							nextstate[3:0] = st_tx_transmit_start[3:0];
						end
						
					st_tx_transmit_data[3:0]: 		begin
						if(!tx_data_empty)
							nextstate[3:0] = st_tx_transmit_data[3:0];
						else
							nextstate[3:0] = st_tx_transmit_stop[3:0];
							// TODO: transmit_abort logic 
							// (differentiate between normal end of data and buffer underflow)
						end
						
					st_tx_transmit_stop[3:0]:		nextstate[3:0] = st_tx_idle[3:0];
					st_tx_transmit_abort[3:0]:		nextstate[3:0] = st_tx_idle[3:0];
					st_tx_regw_addr[3:0]:			begin
						if(ulpi_nxt)
							nextstate[3:0] = st_tx_regw_extw_data[3:0];
						else
							nextstate[3:0] = st_tx_regw_addr[3:0];
						end
						
					st_tx_extw_addr[3:0]:				begin
						if(ulpi_nxt)
							nextstate[3:0] = st_tx_extw_extaddr[3:0];
						else
							nextstate[3:0] = st_tx_extw_addr[3:0];
						end
						
					st_tx_extw_extaddr[3:0]:			begin
						if(ulpi_nxt)
							nextstate[3:0] = st_tx_regw_extw_data[3:0];
						else
							nextstate[3:0] = st_tx_extw_extaddr[3:0];
						end
						
					st_tx_regw_extw_data[3:0]:		begin
						if(ulpi_nxt)
							nextstate[3:0] = st_tx_transmit_stop[3:0];
						else
							nextstate[3:0] = st_tx_regw_extw_data[3:0];
						end
					st_tx_regr_addr[3:0]:			begin
						if(ulpi_nxt)
							nextstate[3:0] = st_tx_regr_extr_read[3:0];
						else
							nextstate[3:0] = st_tx_regr_addr[3:0];
						end						
					st_tx_extr_addr[3:0]:				begin
						if(ulpi_nxt)
							nextstate[3:0] = st_tx_extr_extaddr[3:0];
						else
							nextstate[3:0] = st_tx_extr_addr[3:0];
						end
						
					st_tx_extr_extaddr[3:0]:			begin
						if(ulpi_nxt)
							nextstate[3:0] = st_tx_regr_extr_read[3:0];
						else
							nextstate[3:0] = st_tx_extr_extaddr[3:0];
						end
					st_tx_regr_extr_read[3:0]:			nextstate[3:0] = st_tx_idle[3:0];
					default:								nextstate[3:0] = st_tx_idle[3:0];
					endcase
				end
			
			else if(state[5] == 1'b0 && nextstate[5] == 1'b1) begin
				// turnover from TX to RX
					if(nextstate[4] == 1'b1) begin
						// This happens if USB data is incoming
						if(state[3:0] == st_tx_regr_extr_read[3:0])
							// This happens if we planned on doing a register read
							nextstate[3:0] = st_tx_abort[3:0];	// Register read is aborted by incoming data.
						else
							nextstate[3:0] = st_tx_idle;
						end
						// TODO: cover other the cases of other states being aborted by incoming data. Hint: using else if.
						// another hint, use st_tx_aborted/st_rx_aborted to cover all cases during the turnover and output
						// an "aborted" signal.
					else begin
						if(state[3:0] == st_tx_regr_extr_read[3:0])
							// We get here if we planned on doing a register read and there is no USB data incoming
							nextstate[3:0] = st_rx_regr_extr_data[3:0]; // set up for register read
						else
							// We get here if the PHY sends an RX CMD with no USB data incoming
							nextstate[3:0] = st_tx_idle;	
						end
					end
			
			else if(state[5] == 1'b1 && nextstate[5] == 1'b1) begin
				// RX states
				/* Some logic is needed here to handle what to do when, for example, a register read is interrupted
					by a USB receive. Or when a USB reveice immediately follows a register read. That and any other cases
					that can be found in the documentation. */
				if(state[3:0] == st_rx_regr_extr_data[3:0])
					nextstate[3:0] = st_rx_success[3:0];
				else
					nextstate[3:0] = 4'b0000;
				end

			else if(state[5] == 1'b1 && nextstate[5] == 1'b0) begin
				// turnover from RX to TX
				/* I think some serious logic is needed here to handle what to do if a a transmission of any
					kind is interrupted by a receive, but for now, let's ignore and have this in a state where
					we can test transmit states. */
				nextstate[3:0] = state[3:0];
				end

			else begin
				// undefined states from simulation
				nextstate[3:0] = 4'b0;
				//nextstate[5:0] = 6'b0;
				end
		end


		
	always@(state or instruction or tx_data or ulpi_nxt or phyreg_addr_i or phyreg_i)
		begin: output_logic_unregistered
		// These outputs change on the falling edge plus some output delay 
		// Constrain the output delay to >=3ns.
			casez(state)
				st_rx_command: begin
					ulpi_data_out = 2'h00; // Don't care, but needs to be set
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_rx_data: begin
					ulpi_data_out = 2'h00; // Don't care, but needs to be set
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_idle: begin
					ulpi_data_out = 2'h00;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b1;
					end
				st_tx_transmit_start: begin
					ulpi_data_out = instruction;
					ulpi_stp_out = 1'b0;
					tx_data_next = ulpi_nxt;
					exec_done = 1'b0;
					end
				st_tx_transmit_data: begin
					ulpi_data_out = tx_data;
					ulpi_stp_out = 1'b0;
					tx_data_next = ulpi_nxt;
					exec_done = 1'b0;
					end
				st_tx_transmit_stop: begin
					ulpi_data_out = 2'h00;
					ulpi_stp_out = 1'b1;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_transmit_abort: begin
					ulpi_data_out = 8'hFF;
					ulpi_stp_out = 1'b1;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_regw_addr: begin
					ulpi_data_out = instruction;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_extw_addr: begin
					ulpi_data_out = instruction;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_extw_extaddr: begin
					ulpi_data_out = phyreg_addr_i;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_regw_extw_data: begin
					ulpi_data_out = phyreg_i;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_regr_addr: begin
					ulpi_data_out = instruction;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_extr_addr: begin
					ulpi_data_out = instruction;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				st_tx_extr_extaddr: begin
					ulpi_data_out = phyreg_addr_i;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
				default: begin
					ulpi_data_out = 2'h00;
					ulpi_stp_out = 1'b0;
					tx_data_next = 1'b0;
					exec_done = 1'b0;
					end
			endcase
		end

	
	always@(negedge ulpi_clk)
		begin: output_logic_registered
		
			casez(state)
				st_rx_data: begin
					if(!turnover) begin
						rx_data = ulpi_data_latched;
						rx_data_next = 1'b1;
						end
					else begin
						rx_data = 8'b0;
						rx_data_next = 1'b0;
						end
					end
				default: begin
						rx_data = 8'b0;
						rx_data_next = 1'b0;
					end
			endcase		
		end


	always@(negedge ulpi_clk)
		begin: input_logic_registered
		
				casez(state)
					// Evaluate the more specific cases first, such as st_tx_abort.
					st_rx_regr_extr_data: begin
						phyreg_o = ulpi_data;
						end
					st_rx_command: begin
						if(!turnover)
							rx_cmd_byte = ulpi_data_latched;
						end
					st_tx_regw_addr: begin
						phyreg_addr_o = {2'b00,instruction[5:0]};
						end
					st_tx_regw_extw_data: begin
						phyreg_o = phyreg_i;
						end
					st_tx_extw_extaddr: begin
						phyreg_addr_o = phyreg_addr_i;
						end
					st_tx_regr_addr: begin
						phyreg_addr_o = {2'b00,instruction[5:0]};
						end
					st_tx_extr_extaddr: begin
						phyreg_addr_o = phyreg_addr_i;
						end
					default: begin end
			endcase
			
		end

		
endmodule

module oup_sm_ulpi_syncmode_tx(
	input rst_i,					// Resets state machine only
	input  ulpi_clk_i,
	output reg  [7:0]ulpi_data_o,
	input  ulpi_dir_i,
	output ulpi_stp_o,
	input  ulpi_nxt_i,
	
	input [7:0]instruction_i,	// Must be held constant until instruction execution is done.
	input exec_i,					// To execute instruction, assert for one cycle when machine is ready.
	output reg exec_ready_o,	// This is asserted when the machine is ready for the next instruction.
	output reg exec_aborted_o,	// This is asserted when the instruction execution was aborted by a read operation.
	
	input [7:0]tx_data_i,		// Data buffer data output
	output reg tx_data_next_o,	// Requests next word from data buffer
	input tx_data_empty_i,		// Indicates when data is empty
	
	output rx_regr_assert_o,	// TX machine asserts this line to indicate to the RX machine it needs a register read.
	input  rx_done_i,				// RX machine asserts this line to indicate the operation was finished.
	input  rx_abort_i,			// RX machine asserts this line to indicate the operation was aborted.
	
	output reg [3:0]state,			// Useful for debugging
	output reg [3:0]nextstate		// Useful for debugging
);


	parameter	st_tx_idle				= 4'b0000,	// Transmit NOOP, and execute next instruction
					st_tx_abort				= 4'b0001,	// Transmit NOOP, assert exec_aborted_o, and execute next instruction.
					st_tx_reserved02		= 4'b0010,	
					st_tx_reserved03		= 4'b0011,	
					st_tx_transmit_start	= 4'b0100,	// Transmit TX PID or TXNOPID.
					st_tx_transmit_data	= 4'b0101,	// Transmit USB data.
					st_tx_transmit_stop	= 4'b0110,	// Stop, because there is no more data to transmit (assert stp).
					st_tx_transmit_abort	= 4'b0111,	// Abort due to buffer underrun (assert stp and send FF to dataout).
					st_tx_regw_addr		= 4'b1000,	// Transmit REGW address.
					st_tx_extw_addr		= 4'b1001,	// Transmit EXTW address (8'b10101111).
					st_tx_extw_extaddr	= 4'b1010,	// Transmit EXTW extended address (8 bit adress).
					st_tx_regw_extw_data	= 4'b1011,	// Transmit register write data.
					st_tx_regr_addr		= 4'b1100,	// Transmit REGR address.
					st_tx_extr_addr		= 4'b1101,	// Transmit EXTR address (8'b11101111).
					st_tx_extr_extaddr	= 4'b1110,	// Transmit EXTR extended address (8 bit address).
					st_tx_regr_extr_read	= 4'b1111;	// Tell RX machine that there is a pending register read
					
	parameter 	ins_Special		= 2'b00,
					ins_Transmit 	= 2'b01,
					ins_RegWrite	= 2'b10,
					ins_RegRead		= 2'b11;				
					
	function [3:0] decode_instruction;
		input[7:0] instruction;
		begin
			case(instruction[7:6])
				ins_Special: begin
					decode_instruction = st_tx_idle;
					end
				ins_Transmit: begin
					decode_instruction = st_tx_transmit_start;
					end
				ins_RegWrite: begin
					if(instruction[5:0] == 6'b101111)
						decode_instruction = st_tx_extw_addr;
					else
						decode_instruction = st_tx_regw_addr;
					end
				ins_RegRead: begin
					if(instruction[5:0] == 6'b101111)
						decode_instruction = st_tx_extr_addr;
					else
						decode_instruction = st_tx_regr_addr;
					end
				default: decode_instruction = st_tx_idle;
			endcase
		end
	endfunction	

	always@(negedge ulpi_clk_i)
	begin: state_latch
		if(rst_i)
			state <= state_tx_idle;
		else
			state <= nextstate;
	end
	
	always@(state or nextstate or instruction_i or exec_i or ulpi_dir_i or
	        ulpi_nxt_i or tx_data_empty_i or rx_done_i or rx_abort_i)
		begin: next_state_logic
			case(state)
			
				st_tx_idle: begin
					if(!ulpi_dir_i && exec_i)
						nextstate = decode_instruction(instruction_i)
					else
						nextstate = st_tx_idle;
					end
					
				st_tx_abort: begin
					if((!ulpi_dir_i && exec_i)
						nextstate = decode_instruction(instruction_i)
					else
						nextstate = st_tx_idle;
					end
					
				st_tx_reserved02: nextstate = st_tx_idle;
				
				st_tx_reserved03: nextstate = st_tx_idle;
				
				st_tx_transmit_start: begin		
						if(ulpi_nxt_i) begin
								if(!tx_data_empty_i)
									nextstate = st_tx_transmit_data;
								else
									nextstate = st_tx_transmit_abort;
								end
						else
							nextstate = st_tx_transmit_start;
						end
						// TODO: transmit high-speed abort if PHY is set up as high-speed
						// (inverted CRC instead of the st_tx_transmit_abort state)
						
				st_tx_transmit_data: begin
						if(!tx_data_empty_i)
							nextstate = st_tx_transmit_data;
						else
							nextstate = st_tx_transmit_stop;
						end
						// TODO: transmit_abort logic 
						// (differentiate between normal end of data and buffer underflow)
						
				st_tx_transmit_stop:	nextstate = st_tx_idle;
				
				st_tx_transmit_abort: nextstate = st_tx_idle;
				
				st_tx_regw_addr: begin
						if(ulpi_nxt_i)
							nextstate = st_tx_regw_extw_data;
						else
							nextstate = st_tx_regw_addr;
						end
						
				st_tx_extw_addr: begin
						if(ulpi_nxt_i)
							nextstate = st_tx_extw_extaddr;
						else
							nextstate = st_tx_extw_addr;
						end
						
				st_tx_extw_extaddr: begin
						if(ulpi_nxt_i)
							nextstate = st_tx_regw_extw_data;
						else
							nextstate = st_tx_extw_extaddr;
						end
						
				st_tx_regw_extw_data: begin
						if(ulpi_nxt_i)
							nextstate = st_tx_transmit_stop;
						else
							nextstate = st_tx_regw_extw_data;
						end
						
				st_tx_regr_addr: begin
						if(ulpi_nxt_i)
							nextstate = st_tx_regr_extr_read;
						else
							nextstate = st_tx_regr_addr;
						end	
						
				st_tx_extr_addr: begin
						if(ulpi_nxt_i)
							nextstate = st_tx_extr_extaddr;
						else
							nextstate = st_tx_extr_addr;
						end
						
				st_tx_extr_extaddr: begin
						if(ulpi_nxt_i)
							nextstate = st_tx_regr_extr_read;
						else
							nextstate = st_tx_extr_extaddr;
						end
						
				st_tx_regr_extr_read: begin
						if(rx_abort_i)
							nextstate = st_tx_abort;
						else if(rx_done_i)
							nextstate = st_tx_idle;
						else if(ulpi_dir_i)
							nextstate = st_tx_regr_extr_read;
						else
							nextstate = st_tx_abort;
							// The RX machine is not responding.
						end
				default: nextstate = st_tx_idle;
			endcase
		end

	always@(state or instruction_i or tx_data_i or ulpi_nxt_i or phyreg_addr_i or phyreg_i)
		begin: output_logic_unregistered
		// These outputs change on the falling edge plus some output delay 
		// Constrain the output delay to >=3ns.
			casez(state)
				st_tx_idle: begin
					ulpi_data_o = 2'h00;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b1;
					exec_aborted_o = 1'b0;
					end
				st_tx_abort: begin
					ulpi_data_o = 2'h00;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b1;
					exec_aborted_o = 1'b1;
					end
				st_tx_transmit_start: begin
					ulpi_data_o = instruction_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = ulpi_nxt_i;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_transmit_data: begin
					ulpi_data_o = tx_data_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = ulpi_nxt_i;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_transmit_stop: begin
					ulpi_data_o = 2'h00;
					ulpi_stp_o = 1'b1;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_transmit_abort: begin
					ulpi_data_o = 8'hFF;
					ulpi_stp_o = 1'b1;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_regw_addr: begin
					ulpi_data_o = instruction_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_extw_addr: begin
					ulpi_data_o = instruction_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_extw_extaddr: begin
					ulpi_data_o = phyreg_addr_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_regw_extw_data: begin
					ulpi_data_o = phyreg_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_regr_addr: begin
					ulpi_data_o = instruction_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_extr_addr: begin
					ulpi_data_o = instruction_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				st_tx_extr_extaddr: begin
					ulpi_data_o = phyreg_addr_i;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
				default: begin
					ulpi_data_o = 2'h00;
					ulpi_stp_o = 1'b0;
					tx_data_next_o = 1'b0;
					exec_ready_o = 1'b0;
					exec_aborted_o = 1'b0;
					end
			endcase
		end

					
endmodule

module oup_sm_ulpi_syncmode_rx(

);

endmodule
