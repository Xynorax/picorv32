# 1. Bind the port 'clk' to physical pin Y9 (a dedicated MRCC clock pin)
set_property PACKAGE_PIN Y9 [get_ports sys_clk]

# 2. Assign the electrical signaling standard (SSTL15 is standard for ZedBoard PL clock)
set_property IOSTANDARD SSTL15 [get_ports sys_clk]

# 3. Create the Timing engine constraint for a 100MHz waveform (10ns period)
create_clock -period 10.000 -name sys_clk_pin [get_ports sys_clk]