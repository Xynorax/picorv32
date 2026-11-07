# Currently the script only pads the data with the 8 bytes nonce.
# It does not encrypt the data.
# TODO: Encryption of data.

set fp [open "firmware/firmware.coe" r]
gets $fp first_line
gets $fp second_line
set content [read $fp]
close $fp

set total_sum 0
set list [split $content ","]
set updated_list [list]

foreach hex_val $list {
    set total_sum [expr $total_sum + 1]
    lappend updated_list $hex_val
    if {$total_sum %16== 0} {
        lappend updated_list "00000000"
        lappend updated_list "00000000"
    }

}

set fp [open "firmware/firmware_encrypted.coe" w]
puts $fp $first_line
puts $fp $second_line
puts $fp [join $updated_list ","]