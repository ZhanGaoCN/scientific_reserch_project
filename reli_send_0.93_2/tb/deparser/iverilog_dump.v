module iverilog_dump();
initial begin
    $dumpfile("seanet_rbttx_deparser_top.fst");
    $dumpvars(0, seanet_rbttx_deparser_top);
end
endmodule
