open_project picorv32_vivado/picorv32_vivado.xpr
set_property incremental false [get_filesets sim_1]
generate_target -force all [get_files blk_mem_gen_1.xci]
export_ip_user_files -of_objects [get_files blk_mem_gen_1.xci] -no_script -sync -force -quiet
reset_simulation -mode behavioral sim_1
file delete -force picorv32_vivado.xpr.xsim.dir
close_project