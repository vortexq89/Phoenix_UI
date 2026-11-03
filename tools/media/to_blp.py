#!/usr/bin/env python3
# Copyright (c) 2026 VortexQ8 (ABDULRAHMAN ALYOUSEF). All rights reserved.
"""Phoenix art -> BLP2 (original encoder, one mip level: UI textures need no mipmaps).
  dxt1  colour only (backgrounds)      compression 2, alpha depth 0, alpha type 0
  dxt5  colour + smooth alpha (logo)   compression 2, alpha depth 8, alpha type 7
  raw   crisp UI atlases (BGRA8888)    compression 3, alpha depth 8
usage: to_blp.py in.tga out.blp dxt1|dxt5|raw"""
import struct, sys
from PIL import Image

def encode(img, mode):
    img = img.convert("RGBA")
    w, h = img.size
    rgba = img.tobytes()
    if mode == "raw":
        r = bytearray(rgba); r[0::4], r[2::4] = rgba[2::4], rgba[0::4]
        data, comp, depth, atype = bytes(r), 3, 8, 8
    else:
        import etcpak
        if mode == "dxt1":
            data, comp, depth, atype = etcpak.compress_bc1(rgba, w, h), 2, 0, 0
        else:
            data, comp, depth, atype = etcpak.compress_bc3(rgba, w, h), 2, 8, 7
    head = b"BLP2" + struct.pack("<I4B2I", 1, comp, depth, atype, 0, w, h)
    offs = [1172] + [0] * 15
    sizes = [len(data)] + [0] * 15
    return head + struct.pack("<16I", *offs) + struct.pack("<16I", *sizes) + bytes(1024) + data

if __name__ == "__main__":
    src, dst, mode = sys.argv[1:4]
    open(dst, "wb").write(encode(Image.open(src), mode))
