module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/rbt_s_parser_top.fst");
    $dumpvars(0, rbt_s_parser_top);
end
endmodule
