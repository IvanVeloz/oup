`ifndef ULPI_EXTERNAL_RESET
   `define ULPI_EXTERNAL_RESET 1
`endif

module oup_device_controller (
   // General signals 
   input              rst_n_i,

   // Wishbone interface signals
   input              wb_clk_i,
   input       [0:0]  wb_adr_i,
   input       [31:0] wb_dat_i,
   output      [31:0] wb_dat_o,
   input              wb_cyc_i,
   input       [3:0]  wb_sel_i,
   input              wb_stb_i,
   input              wb_we_i,
   output             wb_ack_o,
   output             wb_err_o,
   output             wb_rty_o,
   output             wb_stall_o,

   // ULPI interface signals
   `ifdef ULPI_EXTERNAL_RESET
   output             ulpi_rst_o,
   `endif
   input              ulpi_clk_i,
   inout       [7:0]  ulpi_data_io,
   input              ulpi_dir_i,
   output             ulpi_stp_o,
   input              ulpi_nxt_i
);

   oup_wishbone wb (
      .clk_sys_i(wb_clk_i),
      .wb_dat_i(wb_dat_i[31:0]),
      .wb_dat_o(wb_dat_o[31:0]),
      .rst_n_i(rst_n_i),
      .wb_ack_o(wb_ack_o),
      .wb_adr_i(wb_adr_i[0:0]),
      .wb_cyc_i(wb_cyc_i),
      .wb_err_o(wb_err_o),
      .wb_sel_i(wb_sel_i[3:0]),
      .wb_stb_i(wb_stb_i),
      .wb_we_i(wb_we_i),
      .wb_rty_o(wb_rty_o),
      .wb_stall_o(wb_stall_o),
      .oup_ins_instruction_o(),   //7:0
      .oup_ins_exec_o(),
      .oup_ins_reset_o(),
      .oup_ins_exec_done_i(),
      .oup_ins_exec_aborted_i(),
      .oup_phyreg_addr_o(), //7:0
      .oup_phyreg_addr_i(), //7:0
      .oup_phyreg_addr_load_o(),
      .oup_phyreg_data_o(), //7:0
      .oup_phyreg_data_i(), //7:0
      .oup_phyreg_data_load_o(),
      .oup_phyreg_rx_cmd_byte_i()   //7:0
   );

   assign ulpi_rst_o = !rst_n_i;

	// TODO: instantiate ULPI state machine
	
endmodule
