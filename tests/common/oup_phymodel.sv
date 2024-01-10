// Copyright 2024 Ivan Veloz
// We're in the process of selecting a license
// Not synthesizable

`include "oup_ulpi_phyregisters.sv"

module oup_phymodel (
    input             rst_i,
    input             clk_i,         // In the real world PHY generate the clock
    input       [7:0] ulpi_data_i,
    output reg  [7:0] ulpi_data_o,
    output            ulpi_dir_o,
    input             ulpi_stp_i,
    output            ulpi_nxt_o
);

    logic[7:0] phyregs[0:255];          // Reads like the ULPI standard
    logic[7:0] phyregs_shadow[0:255];   // Register that gets written to

    import oup_ulpi_phyregisters::*;

    typedef enum int {
        ST_IDLE, ST_NOOP, ST_SPECIAL, ST_TRANSMIT, ST_REGWRITE, ST_REGREAD, 
        ST_LOCKED
    } phymodel_state_t;

    typedef enum int {
        P_NOOP=0, P_NOPID, P_PID, P_EXTW, P_REGW, P_EXTR, P_REGR, 
        P_RSVD, P_UNKNOWN
    } phymodel_payload_t;

    typedef enum int {
        C_SPECIAL, C_TRANSMIT, C_REGWRITE, C_REGREAD, C_UNKNOWN
    } phymodel_code_t;

    phymodel_state_t state, nextstate;
    phymodel_state_t regwrite_process_ns = ST_REGWRITE;
    phymodel_state_t regread_process_ns  = ST_REGREAD;
    phymodel_payload_t payload;
    phymodel_code_t code;

    logic [7:0] fctn_ctrl_reg = phyregs[int'(FUNCTION_CTRL)];
    logic       rst = fctn_ctrl_reg[5] || rst_i; // Combine the reset sources

    initial begin
        reset_phyregs();
    end

    always @(posedge clk_i) 
    begin: reset_process
        if(rst) begin
            ulpi_data_o = '0;
            ulpi_dir_o  = 1;
            reset_phyregs();
        end
    end

    always @(posedge clk_i)
    begin: state_latch
        if(rst)
            state <= ST_IDLE;
        else
            state <= nextstate;
    end

    always @(*)
    begin: nextstate_logic
        case(state)
            ST_IDLE: begin
                nextstate = ST_NOOP;
            end
            ST_NOOP: begin
                payload = commandtopayload(ulpi_data_i);
                code    = commandtocode(ulpi_data_i);
                if(payload == P_UNKNOWN || code == C_UNKNOWN)
                    nextstate = ST_LOCKED;
                else if(payload == P_RSVD)
                    nextstate = ST_LOCKED;
                else begin
                    case(code)
                        C_SPECIAL:  nextstate = ST_NOOP;
                        C_TRANSMIT: nextstate = ST_TRANSMIT;
                        C_REGWRITE: nextstate = ST_REGWRITE;
                        C_REGREAD:  nextstate = ST_REGREAD;
                        default:  nextstate = ST_LOCKED;
                    endcase
                end
            end
            ST_TRANSMIT: begin
                nextstate = ST_LOCKED;  // TODO
            end
            ST_REGWRITE: begin
                nextstate = regwrite_process_ns;
            end
            ST_REGREAD: begin
                nextstate = regread_process_ns;
            end
        endcase
    end

    always@(state)
    begin: output_logic
        case(state)
            ST_NOOP: begin
                ulpi_dir_o = '0;
            end
            default: begin end
        endcase
    end

    always@(state)
    begin: regwrite_process
        logic [7:0] address;
        logic [7:0] temp;
        if(state == ST_REGWRITE) begin
            $display("Entered regwrite_process");
            @(posedge clk_i);       // eventually make this delay variable
            ulpi_nxt_o = '1;        // (for a delay, to set nxt=0)
            // Assigning `address` here tests that the link throttles when nxt=0
            address = {2'b00,ulpi_data_i[5:0]}; 
            if(address == 8'b00101111) begin
                $display("Doing extended write");
                @(posedge clk_i);
                address = ulpi_data_i[7:0];
            end
            @(posedge clk_i);
            while(!ulpi_stp_i) begin
                temp = ulpi_data_i;
                @(posedge clk_i);
            end
            ulpi_nxt_o = '0;
            write_phyreg_shadow(int'(address), temp);
            regwrite_process_ns = ST_NOOP;
        end
        else
            regwrite_process_ns = ST_REGWRITE;
    end

    always@(state)
    begin: regread_process
        logic [7:0] address;
        if(state == ST_REGREAD) begin
            $display("Entered regread_process");
            @(posedge clk_i);
            ulpi_nxt_o = '1;
            // Assigning `address` here tests that the link throttles when nxt=0
            address = {2'b00,ulpi_data_i[5:0]};
            if(address == 8'b00101111) begin
                $display("Doing extended read");
                @(posedge clk_i);
                address = ulpi_data_i[7:0];
            end
            @(posedge clk_i);
            ulpi_nxt_o = '0;
            ulpi_dir_o = '1;
            @(posedge clk_i);
            ulpi_data_o = phyregs[address];
            @(posedge clk_i);
            ulpi_dir_o = '0;
            ulpi_data_o = 'X;
            regread_process_ns = ST_NOOP;
        end
        else
            regread_process_ns = ST_REGREAD;
    end

    always@(phyregs_shadow)
    begin: update_phyregs
        foreach(phyregs[i]) begin
            if(i>=1 && is_sr_register(i-1))         // if we are assigning FOO_S
                phyregs[i] = phyregs_shadow[i-1];   // make it read like FOO
            else if (i>=2 && is_sr_register(i-2))   // if we are assigning FOO_C
                phyregs[i] = phyregs_shadow[i-2];   // make it read like FOO
            else                                    // if we assigning FOO
                phyregs[i] = phyregs_shadow[i];     // make it read like FOO
        end
    end

    task write_phyreg_shadow (input int address, input logic [7:0] value);
        if(is_sr_register(address-1)) begin         //we're writing to a _S reg
            phyregs_shadow[address-1] |= value;
        end
        else if(is_sr_register(address-2)) begin    //we're writing to a _C reg
            phyregs_shadow[address-2] &= ~value;
        end
        else begin                                  //we're writing straight
            phyregs_shadow[address] = value;
        end

        // Take the _S and _C masks and apply them to the base register.
        // When this task gets called, only the set or the clear will happen at 
        // once, because of the way the always block is simulated. So the order
        // of setting and clearing doesn't matter.
        //phyregs_shadow[address]  |=  phyregs_shadow[address+1]; // apply _S mask
        //phyregs_shadow[address]  &= ~phyregs_shadow[address+2]; // apply _C mask
        //phyregs_shadow[address+1] =  '0;                        // clear _S mask
        //phyregs_shadow[address+2] =  '0;                        // clear _C mask
    endtask

    task reset_phyregs();
        // Clear everything.
        phyregs_shadow = '{256{'0}};
        // Now only set what needs setting.
        phyregs_shadow[int'(VID_L)]             = 8'hCD;
        phyregs_shadow[int'(VID_H)]             = 8'hAB;
        phyregs_shadow[int'(PID_L)]             = 8'h34;
        phyregs_shadow[int'(PID_H)]             = 8'h12;
        phyregs_shadow[int'(FUNCTION_CTRL)]     = 8'b01000001;
        phyregs_shadow[int'(INTERFACE_CTRL)]    = 8'b00000000; // see spec bit 4
        phyregs_shadow[int'(OTG_CTRL)]          = 8'b00000110;
        phyregs_shadow[int'(USB_INT_EN_RISE)]   = 8'b00011111;
        phyregs_shadow[int'(USB_INT_EN_FALL)]   = 8'b00011111;
        phyregs_shadow[int'(USB_INT_STATUS)]    = 8'b00000000;
        phyregs_shadow[int'(USB_INT_LATCH)]     = 8'b00000000;
        phyregs_shadow[int'(DEBUG)]             = 8'b00000000;
        phyregs_shadow[int'(SCRATCH)]           = 8'b00000000;
        phyregs_shadow[int'(CARKIT_CTRL)]       = 8'b00000000;
        phyregs_shadow[int'(CARKIT_DLY)]        = 8'h18;
        phyregs_shadow[int'(CARKIT_INT_EN)]     = 8'b00000000;
        phyregs_shadow[int'(CARKIT_INT_STAT)]   = 8'b00000000;
        phyregs_shadow[int'(CARKIT_INT_LATCH)]  = 8'b00000000;
        phyregs_shadow[int'(CARKIT_PLS_CTRL)]   = 8'b00000000;
        phyregs_shadow[int'(TX_POS_WIDTH_W)]    = 8'h10;
        phyregs_shadow[int'(TX_NEG_WIDTH_W)]    = 8'h20;
        phyregs_shadow[int'(RX_POL_RECOVERY)]   = 8'h02;
        phyregs_shadow[int'(EXTENDED_REG)]      = 8'h00;
    endtask

    function logic is_sr_register(int address);
        foreach(phy_sc_registers[i]) begin
            if(address == int'(phy_sc_registers[i])) begin
                return 1;
                break;
            end
        end
        return 0;
    endfunction

    function phymodel_payload_t commandtopayload(logic[7:0] command);
        if($isunknown(command))
            return P_UNKNOWN;
        if(command[7:6] == 2'b00) begin
            if(command[5:0] == 6'b000000)
                commandtopayload = P_NOOP;
            else
                commandtopayload = P_RSVD;
        end
        else if(command[7:6] == 2'b01) begin
            if(command[5:0] == 6'b000000)
                commandtopayload = P_NOPID;
            else if(command[5:4] == 2'b00)
                commandtopayload = P_PID;
            else
                commandtopayload = P_RSVD;
        end
        else if(command[7:6] == 2'b10) begin
            if(command[5:0] == 6'b101111)
                commandtopayload = P_EXTW;
            else
                commandtopayload = P_REGW;
        end
        else if(command[7:6] == 2'b11) begin
            if(command[5:0] == 6'b101111)
                commandtopayload = P_REGR;
            else
                commandtopayload = P_REGR;
        end
        else
            commandtopayload = P_RSVD;
    endfunction

    function phymodel_code_t commandtocode(logic [7:0] command);
        if($isunknown(command))
            return C_UNKNOWN;
        case(command[7:6])
            2'b00:      commandtocode = C_SPECIAL;
            2'b01:      commandtocode = C_TRANSMIT;
            2'b10:      commandtocode = C_REGWRITE;
            2'b11:      commandtocode = C_REGREAD;
            default:    commandtocode = C_UNKNOWN;
        endcase
    endfunction


endmodule
