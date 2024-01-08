// Copyright 2024 Ivan Veloz. All rights reserved.
// I'm in the process of choosing an open source license.

`ifndef OUP_ULPI_PHYREGISTERS_
`define OUP_ULPI_PHYREGISTERS_

package oup_ulpi_phyregisters;
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

`endif
