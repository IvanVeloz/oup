// Copyright 2024 Ivan Veloz. All rights reserved.
// I'm in the process of choosing an open source license.


package oup_ulpi_phyregisters_p;
   typedef enum logic[5:0]{
      VID_L             = 'h00, VID_H, 
      PID_L             = 'h02, PID_H,
      FUNCTION_CTRL     = 'h04, FUNCTION_CTRL_S, FUNCTION_CTRL_C,
      INTERFACE_CTRL    = 'h07, INTERFACE_CTRL_S, INTERFACE_CTRL_C,
      OTG_CTRL          = 'h0A, OTG_CTRL_S, OTG_CTRL_C,
      USB_INT_EN_RISE   = 'h0D, USB_INT_EN_RISE_S, USB_INT_EN_RISE_C,
      USB_INT_EN_FALL   = 'h10, USB_INT_EN_FALL_S, USB_INT_EN_FALL_C,
      USB_INT_STATUS    = 'h13,
      USB_INT_LATCH     = 'h14,
      DEBUG             = 'h15,
      SCRATCH           = 'h16, SCRATCH_S, SCRATCH_C,
      TX_POS_WIDTH_W    = 'h25,
      TX_NEG_WIDTH_W    = 'h26,
      RX_POL_RECOVERY   = 'h27,
      EXTENDED_REG      = 'h2F
   } phy_registers_t;
endpackage

package oup_ulpi_syncmode_instruction_p;
   typedef union packed {
      logic[7:0] aslogic;           // view is as a logic vector
      struct packed {               // View it as an instruction
         instruction_opcode_t opcode;
         instruction_data_t data;
      } instruction_t;
   } instruction_union_t;

   typedef enum logic[1:0] {
      SPECIAL  = 2'b00,
      TRANSMIT = 2'b01,
      REGREAD  = 2'b10,
      REGWRITE = 2'b11
   } instruction_opcode_t;

   typedef union packed {
      oup_ulpi_phyregisters_p::phy_registers_t phyreg;   // view it as a phyreg enum
      logic[5:0] data;                                    // view it as raw logic
   } instruction_data_t;

endpackage

module oup_sm_ulpi_syncmode_m(
   input             rst_i,
   input             ulpi_clk_i,
   input       [7:0] ulpi_data_i,
   output      [7:0] ulpi_data_o,
   input             ulpi_dir_i,
   output            ulpi_stp_o,
   input             ulpi_nxt_i,
   input       [7:0] instruction_i,    // Must be held constant until instruction execution is done.
   input             exec_i,           // To execute instruction, assert for one cycle.
   output            exec_done_o,      // This is asserted when instruction execution is done.
   output            exec_aborted_o,   // This is asserted when the instruction execution was aborted by a read operation.
   input       [7:0] tx_data_i,        // Data to be transmitted to USB. Comes from a FIFO.
   output            tx_data_next_o,   // 
   input             tx_data_empty_i,  // Indicates FIFO is empty
   output      [7:0] rx_data_o,        // Data received from USB. Goes into a FIFO.
   output            rx_data_next_o,   // 
   input             rx_data_full_i,   // TODO: implement. Indicates FIFO is full.
   output      [7:0] rx_cmd_byte_o,    // Defined in table 7 of standard.
   input       [7:0] phyreg_i,         // Data input for ULPI register writes
   input       [7:0] phyreg_addr_i,    // Address input for ULPI register writes
   output      [7:0] phyreg_o,         // Data output for ULPI register reads
   output      [7:0] phyreg_addr_o     // Address output for ULPI register reads

);

   wor ulpi_stp;
   wire rx_regr_assert;
   wire rx_done;
   wire rx_abort;

   assign ulpi_stp_o = ulpi_stp;

   oup_sm_ulpi_syncmode_tx smtx (
      .rst_i(rst_i),
      .ulpi_clk_i(ulpi_clk_i),
      .ulpi_data_i(ulpi_data_i[7:0]),
      .ulpi_dir_i(ulpi_dir_i),
      .ulpi_stp_o(ulpi_stp),
      .ulpi_nxt_i(ulpi_nxt_i),
      .instruction(instruction_i[7:0]),
      .exec_i(exec_i),
      .exec_ready_o(exec_done_o),
      .exec_aborted_o(exec_aborted_o),
      .tx_data_i(tx_data_i[7:0]),
      .tx_data_next_o(tx_data_next_o),
      .tx_data_empty_i(tx_data_empty_i),
      .phyreg_i(phyreg_i[7:0]),
      .phyreg_addr_i(phyreg_addr_i[7:0]),
      .phyreg_addr_o(phyreg_addr_o[7:0]),
      .rx_regr_assert_o(rx_regr_assert),
      .rx_done_i(rx_done),
      .rx_abort_i(rx_abort)
   );

   oup_sm_ulpi_syncmode_rx rxsm (
      .rst_i(rst_i),
      .ulpi_clk_i(ulpi_clk_i),
      .ulpi_data_i(ulpi_data_i[7:0]),
      .ulpi_dir_i(ulpi_dir_i),
      .ulpi_stp_o(ulpi_stp),
      .ulpi_nxt_i(ulpi_nxt_i),
      .rx_regr_assert_i(rx_regr_assert),
      .rx_done_o(rx_done),
      .rx_abort_o(rx_abort),
      .rx_data_o(rx_data_o[7:0]),
      .rx_data_next_o(rx_data_next_o),
      .rx_data_full_i(rx_data_full_i),
      .phyreg_o(phyreg_o[7:0]),
      .rxcmdreg_o(rx_cmd_byte_o[7:0])
   );

      
endmodule

package oup_sm_ulpi_syncmode_tx_p;

   parameter VERSION = "0.1";

   typedef enum logic[3:0] {
      IDLE           = 4'b0000,  // Transmiting NOOP, and fetching next instruction
      ABORT          = 4'b0001,  // Transmitting NOOP, asserting exec_aborted_o, and executing next instruction.
      RSVD02         = 4'b0010,  // Same as IDLE
      RSVD03         = 4'b0011,  // Same as IDLE
      TX_START       = 4'b0100,  // Transmiting TX PID or TXNOPID.
      TX_DATA        = 4'b0101,  // Transmiting USB data.
      TX_STOP        = 4'b0110,  // Asserting ulpi_stp_o, because there is no more data to transmit.
      TX_ABORT       = 4'b0111,  // Aborting due to buffer underrun (asserting stp and sending 'hFF to dataout).
      REGW_ADDR      = 4'b1000,  // Transmiting REGW address.
      EXTW_ADDR      = 4'b1001,  // Transmiting EXTW address (8'b10101111).
      EXTW_EXTADDR   = 4'b1010,  // Transmiting EXTW extended address (8 bit adress).
      REGW_DATA      = 4'b1011,  // Transmiting register write data.
      REGR_ADDR      = 4'b1100,  // Transmiting REGR address.
      EXTR_ADDR      = 4'b1101,  // Transmiting EXTR address (8'b11101111).
      EXTR_EXTADDR   = 4'b1110,  // Transmiting EXTR extended address (8 bit address).
      REGR_WAIT      = 4'b1111   // Asserting rx_regr_assert_o to tell RX machine there is a pending register read.
   } tx_states_t;

   function tx_states_t decode_instruction;
      input oup_ulpi_syncmode_instruction_p::instruction_union_t instruction;
      begin
         case(instruction.opcode)
            oup_ulpi_syncmode_instruction_p::SPECIAL: begin
               decode_instruction = IDLE;
               end
            oup_ulpi_syncmode_instruction_p::TRANSMIT: begin
               decode_instruction = TX_START;
               end
            oup_ulpi_syncmode_instruction_p::REGWRITE: begin
               if(instruction[5:0] == 6'b101111)
                  decode_instruction = EXTW_ADDR;
               else
                  decode_instruction = REGW_ADDR;
               end
            oup_ulpi_syncmode_instruction_p::REGREAD: begin
               if(instruction[5:0] == 6'b101111)
                  decode_instruction = EXTR_ADDR;
               else
                  decode_instruction = REGR_ADDR;
               end
            default: decode_instruction = IDLE;
         endcase
      end
   endfunction	


endpackage

module oup_sm_ulpi_syncmode_tx(
   // ULPI bus
   input             rst_i,            // Resets state machine only
   input             ulpi_clk_i,
   output reg  [7:0] ulpi_data_o,
   input             ulpi_dir_i,
   output            ulpi_stp_o,
   input             ulpi_nxt_i,
   
   // Instructions and status
   input  oup_ulpi_syncmode_instruction_p::instruction_union_t instruction_i, 
                                       // instruction_i must be held constant until execution is done.
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
   input             rx_abort_i        // RX machine asserts this to indicate the operation was aborted.
);

   import oup_sm_ulpi_syncmode_tx_p::*;

   tx_states_t state, nextstate;

   always@(negedge ulpi_clk_i)
   begin: state_latch
      if(rst_i)
         state <= IDLE;
      else
         state <= nextstate;
   end
   
   always@(state or nextstate or instruction_i or exec_i or ulpi_dir_i or
           ulpi_nxt_i or tx_data_empty_i or rx_done_i or rx_abort_i)
      begin: next_state_logic

         case(state)
         
            IDLE: begin
               if(ulpi_dir_i && exec_i)
                  nextstate = decode_instruction(instruction_i);
               else
                  nextstate = IDLE;
            end
               
            TX_ABORT: begin
               if(!ulpi_dir_i && exec_i)
                  nextstate = decode_instruction(instruction_i);
               else
                  nextstate = IDLE;
            end
               
            RSVD02: nextstate = IDLE;
            
            RSVD03: nextstate = IDLE;
            
            TX_START: begin	
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin	
                  if(ulpi_nxt_i) begin
                        if(!tx_data_empty_i)
                           nextstate = TX_DATA;
                        else
                           nextstate = TX_ABORT;
                  end
                  else
                     nextstate = TX_START;
               end
            end
                  // TODO: transmit high-speed abort if PHY is set up as high-speed
                  // (inverted CRC instead of the st_tx_transmit_abort state)
                  
            TX_DATA: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin	
                  if(!tx_data_empty_i)
                     nextstate = TX_DATA;
                  else
                     nextstate = TX_STOP;
               end
            end
                  // TODO: transmit_abort logic 
                  // (differentiate between normal end of data and buffer underflow)
                  
            TX_STOP:	begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else
                  nextstate = IDLE;
            end
            
            TX_ABORT: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else
                  nextstate = IDLE;
            end
            
            REGW_ADDR: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin
                  if(ulpi_nxt_i)
                     nextstate = REGW_DATA;
                  else
                     nextstate = REGW_ADDR;
               end
            end
                  
            EXTW_ADDR: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin
                  if(ulpi_nxt_i)
                     nextstate = EXTW_EXTADDR;
                  else
                     nextstate = EXTW_ADDR;
               end
            end
                  
            EXTW_EXTADDR: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin
                  if(ulpi_nxt_i)
                     nextstate = REGW_DATA;
                  else
                     nextstate = EXTW_EXTADDR;
               end
            end
                  
            REGW_DATA: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin
                  if(ulpi_nxt_i)
                     nextstate = TX_STOP;    // we're done
                  else
                     nextstate = REGW_DATA;
               end
            end
                  
            REGR_ADDR: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin
                  if(ulpi_nxt_i)
                     nextstate = REGR_WAIT;
                  else
                     nextstate = REGR_ADDR;
               end
            end	
                  
            EXTR_ADDR: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin
                  if(ulpi_nxt_i)
                     nextstate = EXTR_EXTADDR;
                  else
                     nextstate = EXTR_ADDR;
               end
            end
                  
            EXTR_EXTADDR: begin
               if(ulpi_dir_i)
                  nextstate = ABORT;
               else begin
                  if(ulpi_nxt_i)
                     nextstate = REGR_WAIT;
                  else
                     nextstate = EXTR_EXTADDR;
               end
            end
                  
            REGR_WAIT: begin                 // turnaround + phy transmitting
                  if(rx_abort_i)
                     nextstate = ABORT;
                  else if(rx_done_i)
                     nextstate = IDLE;
                  else if(ulpi_dir_i)
                     nextstate = REGR_WAIT;  // PHY is transmitting, keep waiting
                  else
                     nextstate = ABORT;
                     // The RX machine is not responding.
            end
            default: nextstate = IDLE;
         endcase
      end

   always@(state or instruction_i or tx_data_i or ulpi_nxt_i or phyreg_addr_i or phyreg_i)
      begin: output_logic_asynchronous
      // These outputs change on the falling edge plus some output delay 
      // Constrain the output delay to >=3ns.
         case(state)
            IDLE: begin
               ulpi_data_o       = 2'h00;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b1;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            ABORT: begin
               ulpi_data_o       = 2'h00;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b1;
               exec_aborted_o    = 1'b1;
               rx_regr_assert_o  = 1'b0;
               end
            TX_START: begin
               ulpi_data_o       = instruction_i.aslogic;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = ulpi_nxt_i;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            TX_DATA: begin
               ulpi_data_o       = tx_data_i;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = ulpi_nxt_i;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            TX_STOP: begin
               ulpi_data_o       = 2'h00;
               ulpi_stp_o        = 1'b1;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            TX_ABORT: begin
               ulpi_data_o       = 8'hFF;
               ulpi_stp_o        = 1'b1;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            REGW_ADDR: begin
               ulpi_data_o       = instruction_i.aslogic;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            EXTW_ADDR: begin
               ulpi_data_o       = instruction_i.aslogic;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            EXTW_EXTADDR: begin
               ulpi_data_o       = phyreg_addr_i;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            REGW_DATA: begin
               ulpi_data_o       = phyreg_i;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            REGR_ADDR: begin
               ulpi_data_o       = instruction_i.aslogic;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            EXTR_ADDR: begin
               ulpi_data_o       = instruction_i.aslogic;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            EXTR_EXTADDR: begin
               ulpi_data_o       = phyreg_addr_i;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
            REGR_WAIT: begin
               ulpi_data_o       = 2'h00;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b1;
               end
            default: begin
               ulpi_data_o       = 2'h00;
               ulpi_stp_o        = 1'b0;
               tx_data_next_o    = 1'b0;
               exec_ready_o      = 1'b0;
               exec_aborted_o    = 1'b0;
               rx_regr_assert_o  = 1'b0;
               end
         endcase
      end

               
endmodule

package oup_sm_ulpi_syncmode_rx_p;
   typedef enum logic[1:0] {
      IDLE, REGR_DATA, RECEIVING_ABORT, RECEIVING
   } rx_states_t;

endpackage

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
   output      [7:0] rx_data_o,        // RX buffer data output
   output reg        rx_data_next_o,   // Loads next word on data buffer
   input             rx_data_full_i,   // Indicates when buffer is full

   // phyreg register
   output reg  [7:0] phyreg_o,         // Data output for ULPI register reads

   // RX CMD register
   output reg  [7:0] rxcmdreg_o        // RX CMD register
);

   // TODO: IMPLEMENT RX_DATA_FULL LOGIC 
   import oup_sm_ulpi_syncmode_rx_p::*;

   rx_states_t state, nextstate;

   always@(negedge ulpi_clk_i)
      begin: state_latch
         if (rst_i)
            state <= IDLE;
         else
            state <= nextstate;
      end

   always@(*)
      begin: next_state_logic
         case(state)
            IDLE: begin
               if(!ulpi_dir_i)
                  nextstate = IDLE;                // we are not receiving
               else begin
                  if(rx_regr_assert_i) begin
                     if(ulpi_nxt_i)     
                        nextstate = RECEIVING_ABORT;    // a register read was aborted by an incoming USB receive 
                     else
                        nextstate = REGR_DATA;     // a register read is happening
                  end
                  else begin
                        nextstate = RECEIVING;
                  end
               end
            end
            REGR_DATA: begin
               if(!ulpi_dir_i)                     // we are not receiving
                  nextstate = IDLE;
               else begin
                  nextstate = RECEIVING;           // we are receiving if dir is high on next clock
               end
            end
            RECEIVING_ABORT: begin
               if(!ulpi_dir_i)                     // we are not receiving
                  nextstate = IDLE;
               else begin
                  nextstate = RECEIVING;           // we are receiving if dir is high on next clock
               end
            end
            RECEIVING: begin
               if(!ulpi_dir_i)                     // we are not receiving
                  nextstate = IDLE;
               else begin
                  nextstate = RECEIVING;           // we are receiving if dir is high on next clock
               end
            end
            default:
               nextstate = IDLE;
         endcase
      end

   always@(ulpi_clk_i)
      begin: output_logic_synchronous

         // Default assignments for combinational signals
         rx_done_o      = '0;
         rx_abort_o     = '0;
         rx_data_next_o = '0;
         rx_data_o      = '0;


         if(state == RECEIVING_ABORT) 
            rx_abort_o = '1;

         case(state)
            IDLE: begin
               rx_done_o   = '1;
            end
            REGR_DATA: begin
               if(ulpi_dir_i)
                  phyreg_o = ulpi_data_i;
               else
                  rx_abort_o = '1;                 // we didn't get the data we expected because DIR changed direction
            end
            RECEIVING, RECEIVING_ABORT: begin
               if(ulpi_dir_i) begin                // Only latch these things if dir is still high for receiving
                  if(!ulpi_nxt_i) begin            // receiving RX CMD
                     rxcmdreg_o = ulpi_data_i;
                  end
                  else begin                       // receiving RX data
                     rx_data_next_o = '1;
                     rx_data_o = ulpi_data_i;
                  end
               end
            end
         endcase



      end
endmodule
