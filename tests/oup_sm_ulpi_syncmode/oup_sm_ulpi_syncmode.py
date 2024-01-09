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

    await cocotb.start(generate_clock(dut))  # run the clock "in the background"

    await cocotb.start(reset(dut)) #reset the DUT

    await FallingEdge(dut.rst_i)
    dut.instruction_i.value = 0b10001111
    dut.phyreg_i.value = 123
    dut.exec_i.value = 1
    await ClockCycles(dut.ulpi_clk_i, 3, True)
    dut.exec_i.value = 0

    await RisingEdge(dut.ulpi_clk_i)
    dut.instruction_i.value = 0b00000000

    #await RisingEdge(dut.exec_done_o)
    #assert dut.exec_aborted_o.value == 0, "exec_aborted_o is not 0!"
    await ClockCycles(dut.ulpi_clk_i, 10)
    #await FallingEdge(dut.ulpi_clk_i)  # wait for falling edge/"negedge"

    dut._log.info("exec_done_o is %s", dut.exec_done_o.value)
