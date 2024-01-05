#include <neorv32.h>
#include <oup_wishbone.h>
#include <oup_wishbone_reg.h>

// Struct holding all of the registers used by OUP
struct OUP_WB * const oup_wb = (struct OUP_WB *)OUP_WB_BASE;

void oup_wishbone_resetphy() {
    oup_wb->INS |= OUP_INS_RESET;
}

void oup_wishbone_sendinstruction(char instruction) {
    oup_wb->INS |= OUP_INS_EXEC | OUP_INS_INSTRUCTION_W(instruction);
}