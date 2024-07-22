module cocotb_iverilog_dump();
initial begin
    $dumpfile("sim_build/mau_rbttx_top.fst");
    $dumpvars(0, mau_rbttx_top);
end
endmodule
