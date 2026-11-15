import pathlib
import struct

data = pathlib.Path("out2/AcidVision.dylib").read_bytes()
magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = struct.unpack_from("<IiiIIII", data, 0)
print(hex(magic), "cputype", hex(cputype & 0xffffffff), "filetype", filetype, "ncmds", ncmds)
assert magic == 0xFEEDFACF
assert (cputype & 0xffffffff) == 0x0100000C, "not arm64"

pos = 32
loads = []
for _ in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", data, pos)
    if cmd == 0xC:  # LC_LOAD_DYLIB
        name_off = struct.unpack_from("<I", data, pos + 8)[0]
        name = data[pos + name_off:data.find(b"\x00", pos + name_off)].decode()
        loads.append(name)
    pos += cmdsize
print("dylibs:")
for name in loads:
    print(" ", name)
