import cocotb
from cocotb.triggers import FallingEdge,RisingEdge,Timer,ClockCycles

async def generate_clock(dut, cycles=100):
    """Generate clock pulses."""

    for cycle in range(cycles):
        dut.ulpi_clk_i.value = 0
        await Timer(1, units="ns")
        dut.ulpi_clk_i.value = 1
        await Timer(1, units="ns")

async def reset(dut):
    """Reset the DUT."""
    await RisingEdge(dut.ulpi_clk_i)
    dut.rst_i.value = 1
    await RisingEdge(dut.ulpi_clk_i)
    dut.rst_i.value = 0

@cocotb.test()
async def tb_oup_sm_ulpi_syncmode(dut):
    """Try accessing the design."""

    await cocotb.start(generate_clock(dut)) # run the clock "in the background"

    await cocotb.start(reset(dut))          # reset the DUT

    REGW = 0b10000000                       # Register write instruction
    REGR = 0b11000000                       # Register read instruction

    registerTestAddr = 0b00010110           # scratch register
    registerTestValue = 123                 # arbitrary value

    await FallingEdge(dut.rst_i)
    dut.instruction_i.value = REGW|registerTestAddr
    dut.phyreg_i.value = registerTestValue
    dut.exec_i.value = 1
    await ClockCycles(dut.ulpi_clk_i, 1, False)
    dut.exec_i.value = 0

    await RisingEdge(dut.ulpi_clk_i)
    dut.instruction_i.value = 0b00000000

    await RisingEdge(dut.exec_done_o)
    assert dut.exec_aborted_o.value == 0, "exec_aborted_o is not 0!"
    assert dut.phymodel.phyregs[registerTestAddr].value == registerTestValue, "register write failed!"
    # Check that you're not writing to a _S or _C register, they don't read the same they write.

    dut.instruction_i.value = REGR|registerTestAddr
    dut.exec_i.value = 1
    await ClockCycles(dut.ulpi_clk_i, 1, False)
    dut.exec_i.value = 0

    await RisingEdge(dut.ulpi_clk_i)
    dut.instruction_i.value = 0b00000000

    await RisingEdge(dut.exec_done_o)
    assert dut.exec_aborted_o == 0, "exec_aborted_o is not 0!"
    assert dut.dut.phyreg_o.value == registerTestValue, "register read failed!"
