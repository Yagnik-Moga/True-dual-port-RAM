module mem_storage(input wire clk, 
                   input wire [4:0] write_row_sel_A,
                   input wire [7:0] data_in_A,
                   input wire we_A,
                   input wire [4:0] write_row_sel_B,
                   input wire [7:0] data_in_B,
                   input wire we_B,
                   
                   output reg [7:0] ram_matrix [0:31]);

        always @(posedge clk)
        begin
            if(we_A)
            begin
                ram_matrix[write_row_sel_A] <= data_in_A;
            end
            if(we_B)
             begin
                ram_matrix[write_row_sel_B] <= data_in_B;
             end
        end
endmodule

module addr_decoder(input wire [4:0] bin_addr,
                    output reg [31:0] row_sel_line);
                    
        always @(*)
        begin
            row_sel_line = 32'b0;
          row_sel_line = (32'b1 << bin_addr);
        end
endmodule

module read_sel_net(input wire [4:0] bin_addr,
                   input wire [7:0] ram_matrix_in[0:31],
                    output reg [7:0] data_out);

        always @(*)
        begin
            data_out = ram_matrix_in[bin_addr];
        end
endmodule

module true_dual_port_RAM(input wire clk,
                          input wire [4:0] addr_A,
                          input wire [7:0] data_in_A,
                          input wire we_A,
                          output wire [7:0] data_out_A,

                          input wire [4:0] addr_B,
                          input wire [7:0] data_in_B,
                          input wire we_B,
                          output wire [7:0] data_out_B,

                          output reg collision_flag);

                          wire [31:0] row_sel_A;
                          wire [31:0] row_sel_B;
                          wire [7:0] internal_matrix [0:31];

                          reg gated_we_B;

            always @(*)
            begin
                if(we_A && we_B && (addr_A == addr_B))
                begin
                    collision_flag = 1'b1;
                    gated_we_B = 1'b0;
                end
                else
                begin
                    collision_flag = 1'b0;
                    gated_we_B = we_B;
                end
            end

    addr_decoder decode_A (.bin_addr(addr_A), .row_sel_line(row_sel_A));
    addr_decoder decode_B (.bin_addr(addr_B), .row_sel_line(row_sel_B));

    mem_storage core_storage(.clk(clk), .write_row_sel_A(addr_A), .we_A(we_A), .data_in_A(data_in_A), .write_row_sel_B(addr_B), .we_B(gated_we_B), .data_in_B(data_in_B), .ram_matrix(internal_matrix));

  read_sel_net read_mux_A(.bin_addr(addr_A), .ram_matrix_in(internal_matrix), .data_out(data_out_A));
  read_sel_net read_mux_B(.bin_addr(addr_B), .ram_matrix_in(internal_matrix), .data_out(data_out_B));

endmodule
