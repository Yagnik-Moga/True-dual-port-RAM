`timescale 1ns / 1ps

`include "true_dual_port_RAM.v"
`include "ram_interface.sv"

// ============================================================================
// VERIFICATION DATA STRUCTURES
// ============================================================================
class ram_transaction;
    rand bit [4:0] addr_A;
    rand bit [7:0] data_in_A;
    rand bit       we_A;
    rand bit [4:0] addr_B;
    rand bit [7:0] data_in_B;
    rand bit       we_B;

    bit [7:0] data_out_A;
    bit [7:0] data_out_B;
    bit       collision_flag;

    constraint collision_scenario_dist {
        addr_B dist { addr_A := 20, [0:31] := 80 };
        we_A   dist { 1 := 70, 0 := 30 };
        we_B   dist { 1 := 70, 0 := 30 };
    }
  
 	 function void display(string prefix = "");
        $display("[%0d ns] %s | Port A: Addr=%0d WE=%b Din=%0h Dout=%0h | Port B: Addr=%0d WE=%b Din=%0h Dout=%0h | Collision=%b", $time, prefix, addr_A, we_A, data_in_A, data_out_A, addr_B, we_B, data_in_B, data_out_B,  collision_flag);
  	  endfunction
endclass

// ============================================================================
// GENERATOR COMPONENT
// ============================================================================
class ram_generator;
    ram_transaction tx;
    mailbox #(ram_transaction) gen2drv;
    event drv_done;
    int num_loops;

    function new(mailbox #(ram_transaction) gen2drv, event drv_done, int num_loops);
        this.gen2drv  = gen2drv;
        this.drv_done  = drv_done;
        this.num_loops = num_loops;
    endfunction

    task run();
        repeat(num_loops) begin
            tx = new();
            if (!tx.randomize()) $error("[GEN ERROR] Randomization failure!");
            gen2drv.put(tx);
            @(drv_done);
        end
    endtask
endclass

// ============================================================================
// DRIVER COMPONENT
// ============================================================================
class ram_driver;
    virtual ram_interface.DRV vif;
    mailbox #(ram_transaction) gen2drv;
    event drv_done;

    function new(virtual ram_interface.DRV vif, mailbox #(ram_transaction) gen2drv, event drv_done);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv_done = drv_done;
    endfunction

    task run();
        forever begin
            ram_transaction tx;
            gen2drv.get(tx);
            vif.drv_cb.addr_A    <= tx.addr_A;
            vif.drv_cb.data_in_A <= tx.data_in_A;
            vif.drv_cb.we_A      <= tx.we_A;
            vif.drv_cb.addr_B    <= tx.addr_B;
            vif.drv_cb.data_in_B <= tx.data_in_B;
            vif.drv_cb.we_B      <= tx.we_B;
            @(vif.drv_cb);
            ->drv_done;
        end
    endtask
endclass

// ============================================================================
// MONITOR COMPONENT //============================================================================
class ram_monitor;
    virtual ram_interface vif; // Uses base interface reference to sample.
    mailbox #(ram_transaction) mon2scb;

    function new(virtual ram_interface vif, mailbox #(ram_transaction) mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
       $display("\n=== STARTING TRANSACTION RECORDING FOR PRESENTATION ===");
      
        forever begin
            ram_transaction observed_tx = new();
            
            // Wait for the active clock edge
            @(posedge vif.clk);
            // Wait a tiny #1ps step to let the RAM's internal wires update and settle completely
            #1ps; 
            
            // Capture the real, stable signals post-settling
            observed_tx.addr_A    = vif.addr_A;
            observed_tx.data_in_A = vif.data_in_A;
            observed_tx.we_A      = vif.we_A;
            observed_tx.data_out_A= vif.data_out_A;
            
            observed_tx.addr_B    = vif.addr_B;
            observed_tx.data_in_B = vif.data_in_B;
            observed_tx.we_B      = vif.we_B;
            observed_tx.data_out_B= vif.data_out_B;
            
            observed_tx.collision_flag = vif.collision_flag;
          
          	observed_tx.display("MONITOR SNAPSHOT");
            
            mon2scb.put(observed_tx);
        end
    endtask
endclass

// ============================================================================
// SCOREBOARD COMPONENT (Handles asynchronous outputs accurately)
// ============================================================================
class ram_scoreboard;
    mailbox #(ram_transaction) mon2scb;
    bit [7:0] ref_mem [0:31];
    int match_count = 0;
    int error_count = 0;
    int collision_verified = 0;

    function new(mailbox #(ram_transaction) mon2scb);
        this.mon2scb = mon2scb;
        foreach(ref_mem[i]) ref_mem[i] = 8'h00;
    endfunction

    task run();
        forever begin
            ram_transaction tx;
            bit expected_collision;
            mon2scb.get(tx);

            expected_collision = (tx.we_A && tx.we_B && (tx.addr_A == tx.addr_B));
            
            if (tx.collision_flag !== expected_collision) begin
                $error("[SCB ERROR] Collision Mismatch! Exp: %b, Got: %b", expected_collision, tx.collision_flag);
                error_count++;
            end else if (expected_collision && tx.collision_flag === 1'b1) begin
                collision_verified++;
            end

            // Update golden memory model state variables
            if (tx.we_A) ref_mem[tx.addr_A] = tx.data_in_A;
            if (tx.we_B && !expected_collision) ref_mem[tx.addr_B] = tx.data_in_B;

            // Validate outputs against our reference memory model
            if (tx.data_out_A === ref_mem[tx.addr_A]) begin
                match_count++;
            end else begin
                $error("[SCB PORT A ERROR] Addr: %0d | Exp: %h | Got: %h", tx.addr_A, ref_mem[tx.addr_A], tx.data_out_A);
                error_count++;
            end

            if (tx.data_out_B === ref_mem[tx.addr_B]) begin
                match_count++;
            end else begin
                $error("[SCB PORT B ERROR] Addr: %0d | Exp: %h | Got: %h", tx.addr_B, ref_mem[tx.addr_B], tx.data_out_B);
                error_count++;
            end
        end
    endtask
endclass

// ============================================================================
// ENV COMPONENT CONTAINER
// ============================================================================
class ram_env;
    ram_generator   gen;
    ram_driver      drv;
    ram_monitor     mon;
    ram_scoreboard  scb;
    mailbox #(ram_transaction) gen2drv;
    mailbox #(ram_transaction) mon2scb;
    event drv_done;
    virtual ram_interface vif;
    int test_cycles;

    function new(virtual ram_interface vif, int test_cycles);
        this.vif         = vif;
        this.test_cycles = test_cycles;
        gen2drv = new();
        mon2scb = new();
        gen = new(gen2drv, drv_done, test_cycles);
        drv = new(vif.DRV, gen2drv, drv_done);
        mon = new(vif, mon2scb); // Pass the direct base interface reference
        scb = new(mon2scb);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any
        repeat(3) @(posedge tb_top.clk);
        $display("\n==================================================");
        $display("          RAM LOGIC SIMULATION REPORT             ");
        $display("==================================================");
        $display(" Total Verified Safe Operations : %0d", scb.match_count);
        $display(" Total Structural Faults Found  : %0d", scb.error_count);
        $display(" Target Address Collisions Handled: %0d", scb.collision_verified);
        $display("==================================================\n");
    endtask
endclass

// ============================================================================
// TOP SIMULATION MODULE
// ============================================================================
module tb_top;
    bit clk;
    always #5 clk = ~clk;

    // Explicitly link the clock through the interface initialization
    ram_interface intf(clk);

    true_dual_port_RAM dut (
        .clk            (intf.clk),
        .addr_A         (intf.addr_A),
        .data_in_A      (intf.data_in_A),
        .we_A           (intf.we_A),
        .data_out_A     (intf.data_out_A),
        .addr_B         (intf.addr_B),
        .data_in_B      (intf.data_in_B),
        .we_B           (intf.we_B),
        .data_out_B     (intf.data_out_B),
        .collision_flag (intf.collision_flag)
    );

    initial begin
        ram_env env;
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);

        env = new(intf, 50);
        env.run();
        $finish;
    end
endmodule
