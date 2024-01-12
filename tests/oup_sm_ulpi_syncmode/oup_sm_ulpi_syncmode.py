import cocotb
from cocotb.triggers import FallingEdge,RisingEdge,Timer,ClockCycles
from cocotb.binary import BinaryValue
from random import getrandbits,randint

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
    dut.seed.value = getrandbits(32)        # pseudorandom for a given seed
    await FallingEdge(dut.rst_i)
    await test_register_rw(dut)
    await test_transmit(dut)



async def test_register_rw(dut):
    REGW = 0b10000000                       # Register write instruction
    REGR = 0b11000000                       # Register read instruction

    registerTestAddr = 0b00010110           # scratch register
    registerTestValue = 123                 # arbitrary value

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
    assert dut.exec_aborted_o.value == 0, "exec_aborted_o is not 0!"
    assert dut.dut.phyreg_o.value == registerTestValue, "register read failed!"

async def test_transmit(dut):
    TX  = 0b01000000                        # Transmit start instruction
    pid = 0b00001111

    fake_tx_len  = 16                       # Create fake data to transmit
    fake_tx_data = [getrandbits(8) for _ in range(fake_tx_len)]

    dut.instruction_i.value = TX|pid
    dut.exec_i.value = 1
    dut.tx_data_stop_i.value  = 0
    dut.tx_data_abort_i.value = 0
    await ClockCycles(dut.ulpi_clk_i, 1, False)
    dut.exec_i.value = 0
    dut.instruction_i.value = 0b00000000
    
    await RisingEdge(dut.tx_data_ready_o)

    for fakebyte in fake_tx_data:
        await FallingEdge(dut.ulpi_clk_i)
        dut.tx_data_i.value = fakebyte
    # Assert stop during the same cycle that the last value is transmitted
    dut.tx_data_stop_i.value = 1

    await RisingEdge(dut.exec_done_o)
    assert dut.exec_aborted_o.value == 0, "exec_aborted_o is not 0!"
    for i in range(fake_tx_len-1):
        assert dut.phymodel.tx_usb_data[i].value == fake_tx_data[i], "TX data does not match between Python TB and phymodel!"
    
async def test_receive(dut):
    NotImplemented()
