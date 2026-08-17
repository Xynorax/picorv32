open_project picorv32_vivado/picorv32_vivado.xpr
upgrade_ip [get_ips blk_mem_gen_1]
generate_target all [get_files blk_mem_gen_1.xci]
file delete -force picorv32_vivado.xpr.xsim.dir
close_project