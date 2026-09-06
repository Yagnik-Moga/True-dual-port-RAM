`timescale 1ns / 1ps

interface ram_interface(input logic clk);

    // Port A signals
    logic [4:0] addr_A;
    logic [7:0] data_in_A;
    logic       we_A;
    logic [7:0] data_out_A;

    // Port B signals
    logic [4:0] addr_B;
    logic [7:0] data_in_B;
    logic       we_B;
    logic [7:0] data_out_B;

    // Arbitration signal
    logic       collision_flag;

    // Driver Clocking Block (Used by the Driver to write safely)
    clocking drv_cb @(posedge clk);
        default input #1ns output #1ns; 
        output addr_A, data_in_A, we_A;
        output addr_B, data_in_B, we_B;
        input  data_out_A, data_out_B, collision_flag;
    endclocking

    modport DRV (clocking drv_cb);

endinterface
