module iverilog_dump();
initial begin
    $dumpfile("mau_rbttx_top.fst");
    $dumpvars(0, mau_rbttx_top);
end
endmodule
