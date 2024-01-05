#ifndef OUP_WISHBONE_H

#define OUP_WISHBONE_H
#define OUP_WB_BASE 0xF0000000  // Base mem. address of Wishbone interface

/* Resets the ULPI phy but not the Wishbone bus. */
void oup_wishbone_resetphy();

/* Sends an instruction to the ULPI interface. 
 * See rtl/core/oup_sm_ulpi_syncmode.sv for more information
 * and instruction definitions.
 */
void oup_wishbone_sendinstruction(char instruction);

#endif