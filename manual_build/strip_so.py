import struct, sys, shutil

src, dst = sys.argv[1], sys.argv[2]
shutil.copy(src, dst)
with open(dst, 'r+b') as f:
    ehdr = f.read(64)
    assert ehdr[:4] == b'\x7fELF' and ehdr[4] == 2, "not 64-bit ELF"
    e_phoff = struct.unpack('<Q', ehdr[0x20:0x28])[0]
    e_phentsize = struct.unpack('<H', ehdr[0x36:0x38])[0]
    e_phnum = struct.unpack('<H', ehdr[0x38:0x3A])[0]
    end = 0
    for i in range(e_phnum):
        f.seek(e_phoff + i * e_phentsize)
        phdr = f.read(56)
        p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz = struct.unpack(
            '<IIQQQQ', phdr[:40])
        if p_type == 1:  # PT_LOAD
            end = max(end, p_offset + p_filesz)
    print(f"truncating at {end:#x} ({end/1048576:.1f} MB)")
    # drop section headers entirely (dynamic loader only needs program hdrs)
    f.seek(0x28); f.write(struct.pack('<Q', 0))   # e_shoff = 0
    f.seek(0x3C); f.write(struct.pack('<H', 0))   # e_shnum = 0
    f.seek(0x3E); f.write(struct.pack('<H', 0))   # e_shstrndx = SHN_UNDEF
    f.truncate(end)
print("done")
