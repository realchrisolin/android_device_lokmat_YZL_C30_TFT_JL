#!/usr/bin/env python3
"""Check a built vendor_boot against this unit's stock slot _a image.

The platform ramdisk must be the same bytes. The recovery ramdisk must be a
separate LZ4 entry named recovery. Exits 0 only when both are true.
"""

import hashlib
import struct
import sys
from pathlib import Path

PAGE = 4096
ENTRY_SIZE = 108
TYPE_PLATFORM = 1
TYPE_RECOVERY = 2


def align(n, page=PAGE):
    return (n + page - 1) & ~(page - 1)


def parse(path):
    data = path.read_bytes()
    magic, ver, page, kaddr, raddr, rsize = struct.unpack_from("<8sIIIII", data, 0)
    if magic != b"VNDRBOOT" or ver != 4 or page != PAGE:
        raise SystemExit(f"{path}: not a vendor_boot v4 page-4096 image")
    cmdline = data[28:28 + 2048].split(b"\x00", 1)[0]
    tags, = struct.unpack_from("<I", data, 2076)
    header_size, dtb_size = struct.unpack_from("<II", data, 2096)
    dtb_addr, = struct.unpack_from("<Q", data, 2104)
    table_size, entry_num, entry_size, bcfg = struct.unpack_from("<IIII", data, 2112)
    if entry_size != ENTRY_SIZE or table_size != entry_num * ENTRY_SIZE:
        raise SystemExit(f"{path}: unexpected ramdisk table {table_size=} {entry_num=} {entry_size=}")
    ramdisk_off = align(header_size, page)
    dtb_off = align(ramdisk_off + rsize, page)
    table_off = align(dtb_off + dtb_size, page)
    entries = []
    for i in range(entry_num):
        base = table_off + i * entry_size
        size, offset, typ = struct.unpack_from("<III", data, base)
        name = data[base + 12:base + 44].split(b"\x00", 1)[0]
        blob = data[ramdisk_off + offset:ramdisk_off + offset + size]
        if len(blob) != size:
            raise SystemExit(f"{path}: entry {i} overruns the file")
        entries.append((typ, name, blob))
    dtb = data[dtb_off:dtb_off + dtb_size]
    return {
        "kaddr": kaddr,
        "raddr": raddr,
        "tags": tags,
        "dtb_addr": dtb_addr,
        "cmdline": cmdline,
        "bootconfig": bcfg,
        "dtb": dtb,
        "entries": entries,
        "size": len(data),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} stock-vendor_boot.img built-vendor_boot.img")
    stock = parse(Path(sys.argv[1]))
    built = parse(Path(sys.argv[2]))
    failed = False

    def check(label, ok, detail):
        nonlocal failed
        print(f"{'ok' if ok else 'FAIL'} {label}: {detail}")
        if not ok:
            failed = True

    for key in ("kaddr", "raddr", "tags", "dtb_addr", "cmdline", "bootconfig"):
        check(key, stock[key] == built[key], f"stock {stock[key]!r} built {built[key]!r}")
    check("dtb", stock["dtb"] == built["dtb"], f"stock {len(stock['dtb'])} built {len(built['dtb'])}")
    check("fits partition", built["size"] <= 67108864, f"{built['size']} bytes")

    stock_platform = [e for e in stock["entries"] if e[0] == TYPE_PLATFORM]
    built_platform = [e for e in built["entries"] if e[0] == TYPE_PLATFORM]
    built_recovery = [e for e in built["entries"] if e[0] == TYPE_RECOVERY]
    check("one platform ramdisk", len(built_platform) == 1, f"{len(built_platform)} entries")
    check("one recovery ramdisk", len(built_recovery) == 1, f"{len(built_recovery)} entries")
    if len(stock_platform) == 1 and len(built_platform) == 1:
        same = stock_platform[0][2] == built_platform[0][2]
        digest = hashlib.sha256(built_platform[0][2]).hexdigest()
        check("platform bytes", same, digest)
        check("platform unnamed", built_platform[0][1] == b"", repr(built_platform[0][1]))
    if len(built_recovery) == 1:
        name, blob = built_recovery[0][1], built_recovery[0][2]
        check("recovery name", name == b"recovery", repr(name))
        check("recovery lz4", blob[:4] == b"\x02\x21\x4c\x18", blob[:4].hex())
        check("recovery differs from stock", blob != stock["entries"][1][2], f"{len(blob)} bytes")
    if failed:
        raise SystemExit(1)
    print("vendor_boot check passed")


if __name__ == "__main__":
    main()
