// Copyright 2023 Ivan E. Veloz Guerrero. All rights reserved. //
// An open source license will be chosen later.

// This module aims for Wishbone B4 compatibility //

// OUP Wishbone B4 interface module
module oup_wishbone #(
    parameter ADR_WID =     32,          // Wishbone bus address width
    parameter B_BASE_ADR =  32'hF0000000,// OUP's buffer base memory address
    parameter B_SIZE =      16,          // OUP's buffer size in address bits
    parameter C_BASE_ADR =  32'hF0010000,// OUP's config register base address
    parameter C_SIZE =      8            // OUP's config reg size in addr bits
    // NOTE: the base addresses must be naturally aligned to their sizes.
    // That is, a buffer of size s must have a base address of n*(2^s) where
    // n is a natural number.

    // NOTE: the configuration register size `C_SIZE` should not be made
    // smaller than the default, but is may be increased for customization.

) (
    input                   clk_i,  // Clock in
    input   [31:0]          dat_i,  // Data in
    output  [31:0]          dat_o,  // Data out
    input                   rst_i,  // Reset (Wishbone interface only)
    input   [2:0]           tgs_i,  // Data tag input
    output  [2:0]           tgs_o,  // Data tag output
    output                  ack_o,  // Acknowledge output
    input   [ADR_WID-1:0]   adr_i,  // Address input
    input                   cyc_i,  // Cycle input
    output                  err_o,  // Error output
    input                   lock_i, // Lock input
    output                  rty_o,  // Retry output
    input   [3:0]           sel_i,  // Select input
    input                   stb_i,  // Strobe input
    input                   tga_i,  // Address tag type input
    input                   tgc_i,  // Cycle tag input
    input                   we_i    // Write enable input
);
 
reg [31:0] m_config [(2**B_SIZE-1):0];  // Configuration register
reg [31:0] m_buffer [(2**C_SIZE-1):0];  // Buffer

// TODO: implement read/write access to buffer and config register. //

endmodule