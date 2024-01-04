`ifndef ULPI_EXTERNAL_RESET
  `define ULPI_EXTERNAL_RESET 1
`endif

module oup(

	//////////// CLOCK //////////
	input 		          		ADC_CLK_10,
	input 		          		MAX10_CLK1_50,
	input 		          		MAX10_CLK2_50,

	//////////// SDRAM //////////
	output		    [12:0]		DRAM_ADDR,
	output		     [1:0]		DRAM_BA,
	output		          		DRAM_CAS_N,
	output		          		DRAM_CKE,
	output		          		DRAM_CLK,
	output		          		DRAM_CS_N,
	inout 		    [15:0]		DRAM_DQ,
	output		          		DRAM_LDQM,
	output		          		DRAM_RAS_N,
	output		          		DRAM_UDQM,
	output		          		DRAM_WE_N,

	//////////// SEG7 //////////
	output		     [7:0]		HEX0,
	output		     [7:0]		HEX1,
	output		     [7:0]		HEX2,
	output		     [7:0]		HEX3,
	output		     [7:0]		HEX4,
	output		     [7:0]		HEX5,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [9:0]		LEDR,

	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// VGA //////////
	output		     [3:0]		VGA_B,
	output		     [3:0]		VGA_G,
	output		          		VGA_HS,
	output		     [3:0]		VGA_R,
	output		          		VGA_VS,

	//////////// Accelerometer //////////
	output		          		GSENSOR_CS_N,
	input 		     [2:1]		GSENSOR_INT,
	output		          		GSENSOR_SCLK,
	inout 		          		GSENSOR_SDI,
	inout 		          		GSENSOR_SDO,

	//////////// Arduino //////////
	inout 		    [15:0]		ARDUINO_IO,
	inout 		          		ARDUINO_RESET_N,

	//////////// GPIO, GPIO connect to GPIO Default //////////
	inout 		    [35:0]		GPIO
);

wire        clk_cpu_i;
wire        rstn_i;
wire [7:0]  cpu_gpio_o;
wire [7:0]  cpu_gpio_i;
wire        uart0_txd_o;
wire        uart0_rxd_i;
wire [2:0]  wb_tag_m2s;  // Tags, MASTER to slave
wire [31:0] wb_adr;
wire [31:0] wb_dat_s2m;  // Data, SLAVE to MASTER
wire [31:0] wb_dat_m2s;  // Data, MASTER to SLAVE
wire        wb_we;
wire [3:0]  wb_sel;
wire        wb_stb;
wire        wb_cyc;
wire        wb_ack;
wire        wb_err;

assign clk_cpu_i        = MAX10_CLK1_50;    // 50MHz clock
assign rstn_i           = SW[9];            // Reset switch, active low
assign cpu_gpio_i[7:0]  = SW[7:0];          // General purpose switches
assign LEDR[7:0]        = cpu_gpio_o[7:0];  // LED row
assign LEDR[9:8]        = 2'bzz;            // LED row

// Dev board IO //
gpio_connector gpio_con (GPIO);
arduino_connector arduino_con (
  .ARDUINO_IO(ARDUINO_IO), 
  .ARDUINO_RESET_N(ARDUINO_RESET_N), 
  .uart0_txd_o_i(uart0_txd_o),
  .uart0_rxd_i_o(uart0_rxd_i)
);

// The NEORV32 soft-processor
neorv32_test_setup_bootloader neorv32_processor (
  .clk_i(clk_cpu_i),
  .rstn_i(rstn_i),
  .gpio_o(cpu_gpio_o[7:0]),
  .gpio_i(cpu_gpio_i[7:0]),
  .uart0_txd_o(uart0_txd_o),
  .uart0_rxd_i(uart0_rxd_i),
  .wb_tag_o(wb_tag_m2s[2:0]),
  .wb_adr_o(wb_adr[31:0]),
  .wb_dat_i(wb_dat_s2m[31:0]),
  .wb_dat_o(wb_dat_m2s[31:0]),
  .wb_we_o(wb_we),
  .wb_sel_o(wb_sel[3:0]),
  .wb_stb_o(wb_stb),
  .wb_cyc_o(wb_cyc),
  .wb_ack_i(wb_ack),
  .wb_err_i(wb_err)
);

// The OUP wishbone interface
oup_device_controller oup_device (
  .wb_clk_i(clk_cpu_i),
  .wb_dat_i(wb_dat_m2s[31:0]),
  .wb_dat_o(wb_dat_s2m[31:0]),
  .rst_n_i(rstn_i),
  .wb_ack_o(wb_ack),
  .wb_adr_i(wb_adr[31:0]),
  .wb_cyc_i(wb_cyc),
  .wb_err_o(wb_err),
  .wb_sel_i(wb_sel[3:0]),
  .wb_stb_i(wb_stb),
  .wb_we_i(wb_we),
  .wb_rty_o(),      // Empty because neither NEORV32 nor wbgen2 implement it.
  .wb_stall_o(),    // Empty because we're not using a pipelined master.
  .ulpi_rst_o(),    // TODO
  .ulpi_clk_i(),    // TODO
  .ulpi_data_io(),  // TODO [7:1]
  .ulpi_dir_i(),    // TODO
  .ulpi_stp_o(),    // TODO
  .ulpi_nxt_i()     // TODO
);

// High-Z unused IO //
assign DRAM_ADDR  [12:0]  = {13{1'bz}};
assign DRAM_BA    [1:0]   = {2{1'bz}};
assign DRAM_CAS_N         = 1'bz;
assign DRAM_CKE           = 1'bz;
assign DRAM_CLK           = 1'bz;
assign DRAM_CS_N          = 1'bz;
assign DRAM_DQ    [15:0]  = {16{1'bz}};
assign DRAM_LDQM          = 1'bz;
assign DRAM_RAS_N         = 1'bz;
assign DRAM_UDQM          = 1'bz;
assign DRAM_WE_N          = 1'bz;
assign HEX0       [7:0]   = {8{1'bz}};
assign HEX1       [7:0]   = {8{1'bz}};
assign HEX2       [7:0]   = {8{1'bz}};
assign HEX3       [7:0]   = {8{1'bz}};
assign HEX4       [7:0]   = {8{1'bz}};
assign HEX5       [7:0]   = {8{1'bz}};
assign VGA_B      [3:0]   = {4{1'bz}};
assign VGA_G      [3:0]   = {4{1'bz}};
assign VGA_HS             = 1'bz;
assign VGA_R              = {4{1'bz}};
assign VGA_VS             = 1'bz;
assign GSENSOR_CS_N       = 1'bz;
assign GSENSOR_SCLK       = 1'bz;
assign GSENSOR_SDI        = 1'bz;
assign GSENSOR_SDO        = 1'bz;

endmodule

// This module enforces signal directions (overrides the inout type)
module gpio_connector(
  inout   [35:0]  GPIO
);
  wire    [35:0]  floating = {36{1'bz}};

  assign GPIO[35:0]   = floating[35:0];

endmodule

// This module enforces signal directions (overrides the inout type)
module arduino_connector(
  inout   [15:0]  ARDUINO_IO,
  inout           ARDUINO_RESET_N,
  input           uart0_txd_o_i,
  output          uart0_rxd_i_o
);
  wire    [15:0]  floating = {16{1'bz}};

  assign ARDUINO_IO[1]    = uart0_txd_o_i;    // Physical pin is output (3.3V)
  assign uart0_rxd_i_o    = ARDUINO_IO[0];    // Physical pin is input (3.3V)
  assign ARDUINO_IO[15:2] = floating[15:2];

endmodule