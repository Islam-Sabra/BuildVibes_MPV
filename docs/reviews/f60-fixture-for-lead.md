# F60 test fixtures, for the lead to check

Two files, **not committed**: they are in the worktree at
`test/fixtures/xiaomi_exif.jpg` and `test/fixtures/xiaomi_exif_sideways.jpg`,
with their test `test/core/photo_privacy_fixture_test.dart`. Everything below
is read from the files themselves.

## xiaomi_exif.jpg

- Size: 1272 bytes; SHA-256 `6003633f10bab0d2b749a29722bba4270d697818b31c059adeb1d146bd2bb639`.
- Picture: 64×48, mode L, every pixel [128] (blank grey; nothing of the office photo).
- Segments: SOI, APP1 EXIF (906 bytes, from byte 2), then the 364 bytes of a Pillow-made grey JPEG (APP0 JFIF, tables, frame, scan, EOI).

## xiaomi_exif_sideways.jpg

- Size: 1272 bytes; SHA-256 `8fb966b47482e2f8b8e1d35215619e81d302aaeaf00bc7a82c080488967466ea`.
- Picture: 64×48, mode L, every pixel [128] (blank grey; nothing of the office photo).
- Segments: SOI, APP1 EXIF (906 bytes, from byte 2), then the 364 bytes of a Pillow-made grey JPEG (APP0 JFIF, tables, frame, scan, EOI).

The two files differ only in byte 115: the Orientation value (0 in the first, as the phone wrote it; 6 in the sideways one).

## Full EXIF tag listing (xiaomi_exif.jpg)

Big-endian TIFF. Offsets count from the TIFF header (APP1 byte 10).

```
IFD0 at TIFF offset 8, 9 entries:
  0x0100 ImageWidth                   LONG      count 1   inline   = 1205
  0x0110 Model                        ASCII     count 11  at 122   = ''
  0x0101 ImageLength                  LONG      count 1   inline   = 1600
  0x010F Make                         ASCII     count 7   at 133   = ''
  0x0131 Software                     ASCII     count 28  at 140   = 'MediaTek Camera Application'
  0x8825 GPSInfoIFDPointer            LONG      count 1   inline   = 794
  0x8769 ExifIFDPointer               LONG      count 1   inline   = 188
  0x0112 Orientation                  SHORT     count 1   inline   = 0
  0x0132 DateTime                     ASCII     count 20  at 168   = '2026:10:21 15:21:11'
  next IFD: 0 (no thumbnail)
Exif IFD at TIFF offset 188, 27 entries:
  0x9000 ExifVersion                  ASCII     count 5   at 518   = '0220'
  0x9204 ExposureBiasValue            SRATIONAL count 1   at 523   = 0/10
  0x8822 ExposureProgram              SHORT     count 1   inline   = 0
  0x9205 MaxApertureValue             RATIONAL  count 1   at 531   = 0/100
  0x9203 BrightnessValue              SRATIONAL count 1   at 539   = 0/10
  0x9003 DateTimeOriginal             ASCII     count 20  at 547   = '2026:10:21 15:21:11'
  0xA000 FlashpixVersion              ASCII     count 5   at 567   = '0100'
  0x9291 SubSecTimeOriginal           ASCII     count 4   inline   = '481'
  0xA403 WhiteBalance                 SHORT     count 1   inline   = 0
  0xA005 InteropIFDPointer            LONG      count 1   inline   = 632
  0x8832 RecommendedExposureIndex     LONG      count 1   inline   = 0
  0xA402 ExposureMode                 SHORT     count 1   inline   = 0
  0x829A ExposureTime                 RATIONAL  count 1   at 572   = 2911/97001
  0x9209 Flash                        SHORT     count 1   inline   = 16
  0x9290 SubSecTime                   ASCII     count 4   inline   = '481'
  0x829D FNumber                      RATIONAL  count 1   at 580   = 9/5
  0x8827 ISOSpeedRatings              SHORT     count 1   inline   = 283
  0xA405 FocalLengthIn35mmFilm        SHORT     count 1   inline   = 0
  0x9292 SubSecTimeDigitized          ASCII     count 4   inline   = '481'
  0xA404 DigitalZoomRatio             RATIONAL  count 1   at 588   = 1/1
  0x9004 DateTimeDigitized            ASCII     count 20  at 596   = '2026:10:21 15:21:11'
  0x9201 ShutterSpeedValue            SRATIONAL count 1   at 616   = 5044/1000
  0x9207 MeteringMode                 SHORT     count 1   inline   = 2
  0x920A FocalLength                  RATIONAL  count 1   at 624   = 4266/1000
  0x8830 SensitivityType              SHORT     count 1   inline   = 0
  0xA406 SceneCaptureType             SHORT     count 1   inline   = 0
  0x9208 LightSource                  SHORT     count 1   inline   = 255
  next IFD: 0
Interop IFD at TIFF offset 632, 1 entries:
  0x0001 InteropIndex / GPSLatitudeRef ASCII     count 4   inline   = 'R98'
  next IFD: 0
GPS IFD at TIFF offset 794, 4 entries:
  0x0001 InteropIndex / GPSLatitudeRef ASCII     count 2   inline   = 'N'
  0x0002 GPSLatitude                  RATIONAL  count 3   at 848   = 0/1 0/1 0/1
  0x0003 GPSLongitudeRef              ASCII     count 2   inline   = 'E'
  0x0004 GPSLongitude                 RATIONAL  count 3   at 872   = 0/1 0/1 0/1
  next IFD: 0
```

Besides the tags, the TIFF holds, at offsets 650–793, an area no tag
points to: a stale copy of IFD0 entries followed by the strings
"22120RN86G", "Xiaomi", "MediaTek Camera Application" and
"2026:10:21 15:21:11". It is left exactly as the phone wrote it.

## Hex dump of the APP1 segment (xiaomi_exif.jpg)

From the FF E1 marker; offset 000a is the TIFF header.

```
0000  ff e1 03 88 45 78 69 66 00 00 4d 4d 00 2a 00 00  ....Exif..MM.*..
0010  00 08 00 09 01 00 00 04 00 00 00 01 00 00 04 b5  ................
0020  01 10 00 02 00 00 00 0b 00 00 00 7a 01 01 00 04  ...........z....
0030  00 00 00 01 00 00 06 40 01 0f 00 02 00 00 00 07  .......@........
0040  00 00 00 85 01 31 00 02 00 00 00 1c 00 00 00 8c  .....1..........
0050  88 25 00 04 00 00 00 01 00 00 03 1a 87 69 00 04  .%...........i..
0060  00 00 00 01 00 00 00 bc 01 12 00 03 00 00 00 01  ................
0070  00 00 00 00 01 32 00 02 00 00 00 14 00 00 00 a8  .....2..........
0080  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
0090  00 00 00 00 00 00 4d 65 64 69 61 54 65 6b 20 43  ......MediaTek C
00a0  61 6d 65 72 61 20 41 70 70 6c 69 63 61 74 69 6f  amera Applicatio
00b0  6e 00 32 30 32 36 3a 31 30 3a 32 31 20 31 35 3a  n.2026:10:21 15:
00c0  32 31 3a 31 31 00 00 1b 90 00 00 02 00 00 00 05  21:11...........
00d0  00 00 02 06 92 04 00 0a 00 00 00 01 00 00 02 0b  ................
00e0  88 22 00 03 00 00 00 01 00 00 00 00 92 05 00 05  ."..............
00f0  00 00 00 01 00 00 02 13 92 03 00 0a 00 00 00 01  ................
0100  00 00 02 1b 90 03 00 02 00 00 00 14 00 00 02 23  ...............#
0110  a0 00 00 02 00 00 00 05 00 00 02 37 92 91 00 02  ...........7....
0120  00 00 00 04 34 38 31 00 a4 03 00 03 00 00 00 01  ....481.........
0130  00 00 00 00 a0 05 00 04 00 00 00 01 00 00 02 78  ...............x
0140  88 32 00 04 00 00 00 01 00 00 00 00 a4 02 00 03  .2..............
0150  00 00 00 01 00 00 00 00 82 9a 00 05 00 00 00 01  ................
0160  00 00 02 3c 92 09 00 03 00 00 00 01 00 10 00 00  ...<............
0170  92 90 00 02 00 00 00 04 34 38 31 00 82 9d 00 05  ........481.....
0180  00 00 00 01 00 00 02 44 88 27 00 03 00 00 00 01  .......D.'......
0190  01 1b 00 00 a4 05 00 03 00 00 00 01 00 00 00 00  ................
01a0  92 92 00 02 00 00 00 04 34 38 31 00 a4 04 00 05  ........481.....
01b0  00 00 00 01 00 00 02 4c 90 04 00 02 00 00 00 14  .......L........
01c0  00 00 02 54 92 01 00 0a 00 00 00 01 00 00 02 68  ...T...........h
01d0  92 07 00 03 00 00 00 01 00 02 00 00 92 0a 00 05  ................
01e0  00 00 00 01 00 00 02 70 88 30 00 03 00 00 00 01  .......p.0......
01f0  00 00 00 00 a4 06 00 03 00 00 00 01 00 00 00 00  ................
0200  92 08 00 03 00 00 00 01 00 ff 00 00 00 00 00 00  ................
0210  30 32 32 30 00 00 00 00 00 00 00 00 0a 00 00 00  0220............
0220  00 00 00 00 64 00 00 00 00 00 00 00 0a 32 30 32  ....d........202
0230  36 3a 31 30 3a 32 31 20 31 35 3a 32 31 3a 31 31  6:10:21 15:21:11
0240  00 30 31 30 30 00 00 00 0b 5f 00 01 7a e9 00 00  .0100...._..z...
0250  00 09 00 00 00 05 00 00 00 01 00 00 00 01 32 30  ..............20
0260  32 36 3a 31 30 3a 32 31 20 31 35 3a 32 31 3a 31  26:10:21 15:21:1
0270  31 00 00 00 13 b4 00 00 03 e8 00 00 10 aa 00 00  1...............
0280  03 e8 00 01 00 01 00 02 00 00 00 04 52 39 38 00  ............R98.
0290  00 00 00 00 00 06 01 10 00 02 00 00 00 0b 00 00  ................
02a0  02 d8 01 0f 00 02 00 00 00 07 00 00 02 e3 01 31  ...............1
02b0  00 02 00 00 00 1c 00 00 02 ea 01 0e 00 02 00 00  ................
02c0  00 01 00 00 00 00 01 12 00 03 00 00 00 01 00 00  ................
02d0  00 00 01 32 00 02 00 00 00 14 00 00 03 06 00 00  ...2............
02e0  00 00 32 32 31 32 30 52 4e 38 36 47 00 58 69 61  ..22120RN86G.Xia
02f0  6f 6d 69 00 4d 65 64 69 61 54 65 6b 20 43 61 6d  omi.MediaTek Cam
0300  65 72 61 20 41 70 70 6c 69 63 61 74 69 6f 6e 00  era Application.
0310  32 30 32 36 3a 31 30 3a 32 31 20 31 35 3a 32 31  2026:10:21 15:21
0320  3a 31 31 00 00 04 00 01 00 02 00 00 00 02 4e 00  :11...........N.
0330  00 00 00 02 00 05 00 00 00 03 00 00 03 50 00 03  .............P..
0340  00 02 00 00 00 02 45 00 00 00 00 04 00 05 00 00  ......E.........
0350  00 03 00 00 03 68 00 00 00 00 00 00 00 00 00 00  .....h..........
0360  00 01 00 00 00 00 00 00 00 01 00 00 00 00 00 00  ................
0370  00 01 00 00 00 00 00 00 00 01 00 00 00 00 00 00  ................
0380  00 01 00 00 00 00 00 00 00 01                    ..........
```

## How it was made

1. The APP1 segment was copied byte for byte from the real photo
   (Xiaomi 22120RN86G, posted from the review-72 build; Make and Model
   in IFD0 were already emptied by the old in-place code, their copies in
   the orphan area were not).
2. It had no thumbnail (IFD0 next = 0), no GPS block, no maker note and no
   serial-number tag, so nothing needed replacing or zeroing.
3. A GPS block of dummy values (GPSLatitudeRef N, GPSLatitude 0/1 0/1 0/1,
   GPSLongitudeRef E, GPSLongitude 0/1 0/1 0/1) was appended at TIFF
   offset 794, after the orphan area, and IFD0's empty ImageDescription
   entry (0x010E, one NUL) was replaced by a GPSInfo pointer to it, so IFD0
   keeps 9 entries and no other byte moves (the APP1 length field grows
   from 802 to 904 for the appended block).
4. The sideways variant sets Orientation to 6.
5. The picture is `Image.new("L", (64, 48), 128)` saved by Pillow at
   quality 75; the APP1 goes right after its SOI.

The script:

```python
"""Builds test/fixtures/xiaomi_exif.jpg and xiaomi_exif_sideways.jpg.

The APP1 (EXIF) segment of the real Xiaomi 22120RN86G photo, copied byte
for byte, with two changes: the empty ImageDescription entry in IFD0 is
replaced by a GPSInfo pointer to a GPS block of dummy values (0 N, 0 E)
appended after the orphan area; and, in the sideways variant, Orientation
is 6. The picture is a blank 64x48 grey JPEG made with Pillow.
"""
import io
import struct
import sys

from PIL import Image

src, out_dir = sys.argv[1], sys.argv[2]
b = open(src, 'rb').read()
assert b[2:4] == b'\xff\xe1' and b[6:12] == b'Exif\0\0'
L = struct.unpack('>H', b[4:6])[0]
tiff = bytearray(b[12:2 + 2 + L])  # the TIFF data after "Exif\0\0"
assert tiff[:4] == b'MM\x00\x2a'

ifd0 = struct.unpack('>I', tiff[4:8])[0]
n = struct.unpack('>H', tiff[ifd0:ifd0 + 2])[0]


def entry_at(tag):
    for e in range(n):
        at = ifd0 + 2 + 12 * e
        if struct.unpack('>H', tiff[at:at + 2])[0] == tag:
            return at
    raise KeyError(hex(tag))


# Nothing to zero or replace: the block has no serial-number tag, no
# maker note and no thumbnail (IFD0's next block is 0).
assert struct.unpack('>I', tiff[ifd0 + 2 + 12 * n:ifd0 + 6 + 12 * n])[0] == 0

# The GPS block, at the end (even offset).
while len(tiff) % 2:
    tiff.append(0)
gps = len(tiff)
entries = 4
values = gps + 2 + entries * 12 + 4
zero3 = struct.pack('>IIIIII', 0, 1, 0, 1, 0, 1)
block = struct.pack('>H', entries)
block += struct.pack('>HHI', 0x0001, 2, 2) + b'N\0\0\0'
block += struct.pack('>HHII', 0x0002, 5, 3, values)
block += struct.pack('>HHI', 0x0003, 2, 2) + b'E\0\0\0'
block += struct.pack('>HHII', 0x0004, 5, 3, values + 24)
block += b'\0\0\0\0' + zero3 + zero3
tiff += block

# ImageDescription (0x010E, one empty byte) becomes GPSInfo (0x8825).
at = entry_at(0x010E)
tiff[at:at + 12] = struct.pack('>HHII', 0x8825, 4, 1, gps)


def jpeg(orientation):
    t = bytearray(tiff)
    o = entry_at(0x0112)
    if orientation is not None:
        t[o + 8:o + 10] = struct.pack('>H', orientation)
    seg = b'Exif\0\0' + bytes(t)
    app1 = b'\xff\xe1' + struct.pack('>H', len(seg) + 2) + seg
    buf = io.BytesIO()
    Image.new('L', (64, 48), 128).save(buf, 'JPEG', quality=75)
    grey = buf.getvalue()
    return b'\xff\xd8' + app1 + grey[2:], app1


plain, app1 = jpeg(None)
sideways, app1_sideways = jpeg(6)
open(out_dir + '/xiaomi_exif.jpg', 'wb').write(plain)
open(out_dir + '/xiaomi_exif_sideways.jpg', 'wb').write(sideways)
print(len(plain), len(sideways), len(app1))
```
