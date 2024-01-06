
module oup_sm_ulpi_syncmode(
   input             rst_i,
   input             ulpi_clk_i,
   input       [7:0] ulpi_data_i,
   output      [7:0] ulpi_data_o,
   input             ulpi_dir_i,
   output            ulpi_stp_o,
   input             ulpi_nxt_i,
   input       [7:0] instruction_i,    // Must be held constant until instruction execution is done.
   input             exec_i,           // To execute instruction, assert for one cycle.
   output reg        exec_done_o,	   // This is asserted when instruction execution is done.
   output reg        exec_aborted_o,   // This is asserted when the instruction execution was aborted by a read operation.
   input       [7:0] tx_data_i,	      // Data to be transmitted to USB. Comes from a FIFO.
   output reg        tx_data_next_o,   // 
   input             tx_data_empty_i,  // Indicates FIFO is empty
   output reg  [7:0] rx_data_o,        // Data received from USB. Goes into a FIFO.
   output reg        rx_data_next_o,   // 
   input             rx_data_full_i,   // TODO: implement. Indicates FIFO is full.
   output reg  [7:0] rx_cmd_byte_o,	   // Defined in table 7 of standard.
   input       [7:0] phyreg_i,      	// Data input for ULPI register writes
   input       [7:0] phyreg_addr_i,    // Address input for ULPI register writes
   output reg  [7:0] phyreg_o,         // Data output for ULPI register reads
   output reg  [7:0] phyreg_addr_o     // Address output for ULPI register reads

);

   // TODO: implement exec_aborted output logic.
   oup_sm_ulpi_syncmode_tx smtx (
      .rst_i(rst_i),
      .ulpi_clk_i(ulpi_clk_i),
      .ulpi_data_o(ulpi_data_o),
      // TODO: the rest of this
   );

      
endmodule

module oup_sm_ulpi_syncmode_tx(
   // ULPI bus
   input             rst_i,            // Resets state machine only
   input             ulpi_clk_i,
   output reg  [7:0] ulpi_data_o,
   input             ulpi_dir_i,
   output            ulpi_stp_o,
   input             ulpi_nxt_i,
   
   // Instructions and status
   input       [7:0] instruction_i,    // Must be held constant until instruction execution is done.
   input             exec_i,           // To execute instruction, assert for one cycle when machine is ready.
   output reg        exec_ready_o,     // Asserted when the machine is ready for the next instruction.
   output reg        exec_aborted_o,   // Asserted when the instruction execution was aborted by a read operation.
   
   // TX FIFO buffer
   input       [7:0] tx_data_i,        // TX buffer data input
   output reg        tx_data_next_o,   // Requests next word from data buffer
   input             tx_data_empty_i,  // Indicates when buffer is empty

   // phyreg registers
   input       [7:0] phyreg_i,         // Data input for ULPI register writes
   input       [7:0] phyreg_addr_i,    // Address input for ULPI register writes
   output reg  [7:0] phyreg_addr_o,    // Not handled by the RX machine. Address output for ULPI register reads.
   
   // RX machine communication
   output            rx_regr_assert_o, // TX machine asserts this to indicate to the RX machine it needs a reg read.
   input             rx_done_i,        // RX machine asserts this to indicate the operation was finished.
   input             rx_abort_i,       // RX machine asserts this to indicate the operation was aborted.
   
   // Machine states
   output reg  [3:0] state,            // Useful for debugging
   output reg  [3:0] nextstate         // Useful for debugging
);


   parameter	st_tx_idle           = 4'b0000,  // Transmit NOOP, and execute next instruction
               st_tx_abort          = 4'b0001,  // Transmit NOOP, assert exec_aborted_o, and execute next instruction.
               st_tx_reserved02     = 4'b0010,
               st_tx_reserved03     = 4'b0011,
               st_tx_transmit_start = 4'b0100,  // Transmit TX PID or TXNOPID.
               st_tx_transmit_data  = 4'b0101,  // Transmit USB data.
               st_tx_transmit_stop  = 4'b0110,  // Stop, because there is no more data to transmit (assert stp).
               st_tx_transmit_abort = 4'b0111,  // Abort due to buffer underrun (assert stp and send FF to dataout).
               st_tx_regw_addr      = 4'b1000,  // Transmit REGW address.
               st_tx_extw_addr      = 4'b1001,  // Transmit EXTW address (8'b10101111).
               st_tx_extw_extaddr   = 4'b1010,  // Transmit EXTW extended address (8 bit adress).
               st_tx_regw_extw_data = 4'b1011,  // Transmit register write data.
               st_tx_regr_addr      = 4'b1100,  // Transmit REGR address.
               st_tx_extr_addr      = 4'b1101,  // Transmit EXTR address (8'b11101111).
               st_tx_extr_extaddr   = 4'b1110,  // Transmit EXTR extended address (8 bit address).
               st_tx_regr_extr_read = 4'b1111;  // Tell RX machine that there is a pending register read
               
   parameter   ins_Special    = 2'b00,
               ins_Transmit   = 2'b01,
               ins_RegWrite   = 2'b10,
               ins_RegRead    = 2'b11;
               
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
         state <= st_tx_idle;
      else
         state <= nextstate;
   end
   
   always@(state or nextstate or instruction_i or exec_i or ulpi_dir_i or
           ulpi_nxt_i or tx_data_empty_i or rx_done_i or rx_abort_i)
      begin: next_state_logic
         case(state)
         
            st_tx_idle: begin
               if(!ulpi_dir_i && exec_i)
                  nextstate = decode_instruction(instruction_i);
               else
                  nextstate = st_tx_idle;
               end
               
            st_tx_abort: begin
               if(!ulpi_dir_i && exec_i)
                  nextstate = decode_instruction(instruction_i);
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
   // ULPI bus
   input             rst_i,            // Resets state machine only
   input             ulpi_clk_i,
   input       [7:0] ulpi_data_i,
   input             ulpi_dir_i,
   output            ulpi_stp_o,
   input             ulpi_nxt_i,

   // Instructions and status
   input             rx_regr_assert_i, // TX machine asserts this to indicate to the RX machine it needs a reg read.
   output reg        rx_done_o,        // RX machine asserts this to indicate the operation was finished.
   output reg        rx_abort_o,       // RX machine asserts this to indicate the operation was aborted.

   // RX FIFO buffer
   input       [7:0] rx_data_o,        // RX buffer data output
   output reg        rx_data_next_o,   // Loads next word on data buffer
   input             rx_data_full_i,   // Indicates when buffer is full

   // phyreg register
   output reg  [7:0] phyreg_o,         // Data output for ULPI register reads

   // Machine states
   output reg  [1:0] state,            // Useful for debugging
   output reg  [1:0] nextstate         // Useful for debugging
);

endmodule
