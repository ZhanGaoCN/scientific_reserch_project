module iverilog_dump();
initial begin
    $dumpfile("rbt_s_parser_top.fst");
    $dumpvars(0, rbt_s_parser_top);
end
endmodule
