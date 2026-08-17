#!/usr/bin/env python3
import sys

binfile = sys.argv[1]
with open(binfile, "rb") as f:
    bindata = f.read()

assert len(bindata) % 4 == 0

words = []
for i in range(len(bindata) // 4):
    w = bindata[4*i : 4*i+4]
    words.append("%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0]))

with open("firmware/firmware.coe", "w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    f.write(",".join(words) + ";\n")