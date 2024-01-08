`ifndef OUP_SM_ULPI_SYNCMODE_RX
`define OUP_SM_ULPI_SYNCMODE_RX

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

`endif

