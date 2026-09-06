# True-dual-port-RAM
A synthesizable, structural Verilog implementation of a 32-word by 8-bit True Dual-Port RAM. This design supports concurrent read and write operations from two completely independent ports (Port A and Port B) sharing a single clock domain, and includes an explicit hardware collision prevention mechanism.
   Features
    • True Dual-Port Operations: Independent address, data input, write enable, and data output buses for both Port A and Port B.
    • Hardware Collision Resolution: Detects simultaneous write attempts to the same memory address. It flags the collision and gates Port B's write enable signal, preventing memory corruption by giving strict write priority to Port A.
    • Modular Hardware Architecture: Structural design containing a dedicated address decoder, internal memory matrix storage, and read multiplexer networks.

   Hardware Architecture
The top-level module (True_dual_port_RAM) instantiates three distinct sub-modules to separate the control, decoding, and storage logic:
    1. addr_decoder: Decodes the 5-bit binary address into a 32-bit one-hot row selection line (used internally for potential word-line expansion).
    2. mem_storage: The core synchronous memory matrix housing 32 * 8-bit register arrays.
    3. read_sel_net: Asynchronous combinational multiplexer network that routes the selected memory array word to the output port based on the binary address.
Collision Prevention Logic
When we_A and we_B are both high, and addr_A == addr_B:
    • collision_flag is asserted high (1'b1).
    • we_B is masked internally (gated_we_B = 1'b0). Port A's transaction succeeds, while Port B's write is safely dropped.


   Module Interface Definitions
   True_dual_port_RAM (Top-Level)
Port Name	Direction	Width	Description
clk	Input	1 bit	Global clock signal (Active high, positive-edge triggered)
addr_A	Input	5 bits	Port A address bus (Points to 1 of 32 rows)
data_in_A	Input	8 bits	Port A parallel write data bus
we_A	Input	1 bit	Port A write enable (Active High)
data_out_A	Output	8 bits	Port A asynchronous read data bus
addr_B	Input	5 bits	Port B address bus (Points to 1 of 32 rows)
data_in_B	Input	8 bits	Port B parallel write data bus
we_B	Input	1 bit	Port B write enable (Active High)
data_out_B	Output	8 bits	Port B asynchronous read data bus
collision_flag	Output	1 bit	High when Port A and B attempt to write to the same address simultaneously


   Simulation and Synthesis
   Use EDA Playground and open the given link to observe the simulation log and output waveforms.

Link – https://www.edaplayground.com/x/PfFN
