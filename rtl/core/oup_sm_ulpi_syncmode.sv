// Copyright 2024 Ivan Veloz. All rights reserved.
// I'm in the process of choosing an open source license.

`include "oup_ulpi_phyregisters.sv"
`include "oup_sm_ulpi_syncmode_tx.sv"
`include "oup_sm_ulpi_syncmode_rx.sv"

module oup_sm_ulpi_syncmode(
   input             rst_i,
   input             ulpi_clk_i,
   input       [7:0] ulpi_data_i,
   output      [7:0] ulpi_data_o,
   input             ulpi_dir_i,
   output            ulpi_stp_o,
   input             ulpi_nxt_i,
   input       [7:0] instruction_i,
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

   wire ulpi_stp_smtx;
   wire ulpi_stp_smrx;
   wire rx_regr_assert;
   wire rx_done;
   wire rx_abort;

   assign ulpi_stp_o = ulpi_stp_smtx | ulpi_stp_smrx;

   oup_sm_ulpi_syncmode_tx smtx (
      .rst_i(rst_i),
      .ulpi_clk_i(ulpi_clk_i),
      .ulpi_data_o(ulpi_data_o[7:0]),
      .ulpi_dir_i(ulpi_dir_i),
      .ulpi_stp_o(ulpi_stp_smtx),
      .ulpi_nxt_i(ulpi_nxt_i),
      .instruction_i(instruction_i[7:0]),
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

   oup_sm_ulpi_syncmode_rx smrx (
      .rst_i(rst_i),
      .ulpi_clk_i(ulpi_clk_i),
      .ulpi_data_i(ulpi_data_i[7:0]),
      .ulpi_dir_i(ulpi_dir_i),
      .ulpi_stp_o(ulpi_stp_smrx),
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
