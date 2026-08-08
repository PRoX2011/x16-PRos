#!/usr/bin/env python3
"""
FAT12 floppy image builder for x16-PRos (verified approach).

Layout matches exactly what the x16-PRos bootloader expects:
  sector 0        boot sector (BOOT.BIN)
  sectors 1-9     FAT #1
  sectors 10-18   FAT #2
  sectors 19-32   root directory (224 entries / 14 sectors)
  sectors 33+     data region (SPC=1)

Usage:
  build_image.py <image> <src_bin_dir> [placement...]
    placement := <local_path>:<disk_path>
    disk_path uses / as separator and may start with / (root).
    The first component after / is a directory name.
"""

import sys
import os

BYTE = 512
RESERVED = 1
NFATS = 2
ROOT_ENTRIES = 224
TOTAL_SECTORS = 2880
SPF = 9
ROOT_SECTORS = ROOT_ENTRIES * 32 // BYTE  # 14
DATA_START = RESERVED + NFATS * SPF + ROOT_SECTORS  # 33
MAX_CLUSTERS = TOTAL_SECTORS - DATA_START  # 2847


def to_83(name):
    name = name.upper()
    if "." in name:
        base, ext = name.split(".", 1)
    else:
        base, ext = name, ""
    base = (base[:8] + " " * 8)[:8]
    ext = (ext[:3] + " " * 3)[:3]
    return (base + ext).encode("ascii")


def pack_fat(fat):
    out = bytearray()
    for i in range(0, len(fat), 2):
        e0 = fat[i] & 0xFFF
        e1 = fat[i + 1] & 0xFFF if i + 1 < len(fat) else 0xFFF
        out += bytes([e0 & 0xFF, ((e0 >> 8) & 0x0F) | ((e1 & 0x0F) << 4), (e1 >> 4) & 0xFF])
    return bytes(out[:SPF * BYTE].ljust(SPF * BYTE, b"\0"))


def dir_entry(name11, attr, cluster, size):
    e = bytearray(32)
    e[0:11] = name11
    e[11] = attr
    e[26:28] = bytes([cluster & 0xFF, (cluster >> 8) & 0xFF])
    e[28:32] = bytes([size & 0xFF, (size >> 8) & 0xFF, (size >> 16) & 0xFF, (size >> 24) & 0xFF])
    return bytes(e)


class Image:
    def __init__(self):
        self.data = bytearray(TOTAL_SECTORS * BYTE)
        self.fat = [0] * (MAX_CLUSTERS + 2)
        self.fat[0] = 0xFF0
        self.fat[1] = 0xFFF
        self.next_cluster = 2
        self.root_entries = []
        self.dir_entries = {}   # dir path -> list of 32-byte entries
        self.dir_cluster = {}   # dir path -> first cluster

    def alloc(self, n):
        start = self.next_cluster
        for i in range(n):
            c = start + i
            self.fat[c] = (c + 1) if i < n - 1 else 0xFFF
        self.next_cluster += n
        if self.next_cluster - 2 > MAX_CLUSTERS:
            raise RuntimeError("image full")
        return start

    def add_dir(self, path, parent_cluster=0):
        cl = self.alloc(1)
        self.dir_cluster[path] = cl
        self.dir_entries[path] = [
            dir_entry(b".          ", 0x10, cl, 0),
            dir_entry(b"..         ", 0x10, parent_cluster, 0),
        ]
        return cl

    def add_file(self, disk_path, data):
        n = max(1, (len(data) + BYTE - 1) // BYTE)
        cl = self.alloc(n)
        # write data
        for i in range(n):
            sector = DATA_START + (cl - 2) + i
            chunk = data[i * BYTE:(i + 1) * BYTE]
            self.data[sector * BYTE:sector * BYTE + len(chunk)] = chunk
        entry = dir_entry(to_83(os.path.basename(disk_path)), 0x20, cl, len(data))
        if "/" not in disk_path:
            self.root_entries.append(entry)
        else:
            parent = disk_path.rsplit("/", 1)[0]
            self.dir_entries.setdefault(parent, []).append(entry)

    def build(self, boot, out_path):
        self.data[0:len(boot)] = boot[:BYTE]

        # FATs
        fatb = pack_fat(self.fat)
        self.data[1 * BYTE:10 * BYTE] = fatb
        self.data[10 * BYTE:19 * BYTE] = fatb

        # root directory
        rootb = b"".join(self.root_entries)
        rootb = rootb.ljust(ROOT_SECTORS * BYTE, b"\0")
        self.data[19 * BYTE:33 * BYTE] = rootb[:ROOT_SECTORS * BYTE]

        # subdirectories: write contents to their clusters
        for path, entries in self.dir_entries.items():
            cl = self.dir_cluster[path]
            content = b"".join(entries).ljust(BYTE, b"\0")
            # a directory may span clusters if it has many entries
            needed = max(1, (len(b"".join(entries)) + BYTE - 1) // BYTE)
            content = b"".join(entries).ljust(needed * BYTE, b"\0")
            for i in range(needed):
                sector = DATA_START + (cl - 2) + i
                chunk = content[i * BYTE:(i + 1) * BYTE]
                self.data[sector * BYTE:sector * BYTE + len(chunk)] = chunk

        with open(out_path, "wb") as f:
            f.write(self.data)
        print(f"wrote {out_path} ({os.path.getsize(out_path)} bytes)")


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(2)
    out_path = sys.argv[1]
    src_bin = sys.argv[2]
    placements = sys.argv[3:]

    img = Image()

    # register dirs first so their clusters are allocated before files
    dirs = set()
    norm = []
    for placement in placements:
        local, disk = placement.split(":", 1)
        while disk.startswith("/"):
            disk = disk[1:]
        norm.append(local + ":" + disk)
        parts = disk.split("/")
        for i in range(1, len(parts)):
            dirs.add("/".join(parts[:i]))
    placements = norm

    for d in sorted(dirs):
        parent = d.rsplit("/", 1)[0] if "/" in d else ""
        pc = img.dir_cluster.get(parent, 0)
        img.add_dir(d, pc)
        # register the dir itself in the parent directory
        entry = dir_entry(to_83(os.path.basename(d)), 0x10, img.dir_cluster[d], 0)
        if parent == "":
            img.root_entries.append(entry)
        else:
            img.dir_entries[parent].append(entry)

    # add files
    for placement in placements:
        local, disk = placement.split(":", 1)
        with open(local, "rb") as f:
            data = f.read()
        img.add_file(disk, data)

    with open(os.path.join(src_bin, "BOOT.BIN"), "rb") as f:
        boot = f.read()
    img.build(boot, out_path)


if __name__ == "__main__":
    main()
