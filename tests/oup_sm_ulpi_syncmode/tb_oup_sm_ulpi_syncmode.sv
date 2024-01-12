`include "oup_phymodel.sv"
`include "oup_sm_ulpi_syncmode.sv"

module tb_oup_sm_ulpi_syncmode();

    logic       rst_i;
    logic       ulpi_clk_i;
    logic [7:0] ulpi_data_i;
    logic [7:0] ulpi_data_o;
    logic       ulpi_dir_i;
    logic       ulpi_stp_o;
    logic       ulpi_nxt_i;
    logic [7:0] instruction_i;
    logic       exec_i;
    logic       exec_done_o;
    logic       exec_aborted_o;
    logic [7:0] tx_data_i;
    logic       tx_data_ready_o;
    logic       tx_data_stop_i;
    logic       tx_data_abort_i;
    logic [7:0] rx_data_o;
    logic       rx_data_active_o;
    logic       rx_data_valid_o;
    logic [7:0] rx_cmd_byte_o;
    logic [7:0] phyreg_i;
    logic [7:0] phyreg_addr_i;
    logic [7:0] phyreg_o;
    logic [7:0] phyreg_addr_o;
    logic       tb_receive_start;
    logic       tb_receive_stop;
    logic       tb_receive_rxcmd;

    int         seed=0;                 // Seed used for pseudo-random numbers

    oup_phymodel phymodel (
        .rst_i(rst_i),
        .clk_i(ulpi_clk_i),
        .ulpi_data_i(ulpi_data_o),
        .ulpi_data_o(ulpi_data_i),
        .ulpi_dir_o(ulpi_dir_i),
        .ulpi_stp_i(ulpi_stp_o),
        .ulpi_nxt_o(ulpi_nxt_i),
        .seed_i(seed),
        .tb_receive_start(tb_receive_start),
        .tb_receive_stop (tb_receive_stop),
        .tb_receive_rxcmd(tb_receive_rxcmd)
    );

    oup_sm_ulpi_syncmode dut(
        .rst_i(rst_i),
        .ulpi_clk_i(ulpi_clk_i),
        .ulpi_data_i(ulpi_data_i[7:0]),
        .ulpi_data_o(ulpi_data_o[7:0]),
        .ulpi_dir_i(ulpi_dir_i),
        .ulpi_stp_o(ulpi_stp_o),
        .ulpi_nxt_i(ulpi_nxt_i),
        .instruction_i(instruction_i[7:0]),  
        .exec_i(exec_i),
        .exec_done_o(exec_done_o),
        .exec_aborted_o(exec_aborted_o),
        .tx_data_i(tx_data_i[7:0]),
        .tx_data_ready_o(tx_data_ready_o),
        .tx_data_stop_i(tx_data_stop_i),
        .tx_data_abort_i(tx_data_abort_i),
        .rx_data_o(rx_data_o[7:0]),
        .rx_data_active_o(rx_data_active_o),
        .rx_data_valid_o(rx_data_valid_o),
        .rx_cmd_byte_o(rx_cmd_byte_o[7:0]),
        .phyreg_i(phyreg_i[7:0]),
        .phyreg_addr_i(phyreg_addr_i[7:0]),
        .phyreg_o(phyreg_o[7:0]),
        .phyreg_addr_o(phyreg_addr_o[7:0])
    );

endmodule