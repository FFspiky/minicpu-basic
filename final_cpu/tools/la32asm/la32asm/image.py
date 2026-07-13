"""LA32IMG v1 container used by the board boot monitor."""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import struct
import zlib

MAGIC = b"LA32IMG\0"
VERSION = 1
APP_START = 0x1C010000
APP_END = 0x1C0F0000
STACK_TOP = 0x1C100000


class ImageError(ValueError):
    pass


class ImageType(IntEnum):
    GENERIC = 0
    GAME = 1
    SELFTEST = 2


class SegmentFlags(IntEnum):
    READ = 1
    WRITE = 2
    EXEC = 4


@dataclass(frozen=True)
class Segment:
    load_address: int
    data: bytes
    memory_size: int
    flags: int

    def validate(self) -> None:
        if self.load_address & 3:
            raise ImageError("segment load address is not word aligned")
        if self.memory_size < len(self.data):
            raise ImageError("segment memory_size is smaller than file data")
        if self.load_address < APP_START or self.load_address + self.memory_size > APP_END:
            raise ImageError("segment is outside the application RAM window")


# magic, version, header_size, type, flags, entry, end_pc, stack_top,
# ram_required, segment_count, payload_size, name[32], build_id, header_crc,
# image_crc
_HEADER = struct.Struct("<8sHHIIIIIIII32sIII")
# flags, load_address, file_size, memory_size, payload_offset, crc32
_SEGMENT = struct.Struct("<IIIIII")


@dataclass
class Image:
    name: str
    image_type: ImageType
    entry: int
    segments: list[Segment]
    end_pc: int = 0
    stack_top: int = STACK_TOP
    flags: int = 0
    build_id: int = 0

    def validate(self) -> None:
        if not self.segments:
            raise ImageError("image has no segments")
        if self.entry & 3:
            raise ImageError("entry is not word aligned")
        if len(self.name.encode("utf-8")) > 31:
            raise ImageError("program name is longer than 31 UTF-8 bytes")
        ranges: list[tuple[int, int]] = []
        entry_ok = False
        for segment in self.segments:
            segment.validate()
            start = segment.load_address
            end = start + segment.memory_size
            for other_start, other_end in ranges:
                if start < other_end and other_start < end:
                    raise ImageError("image segments overlap")
            ranges.append((start, end))
            if (segment.flags & SegmentFlags.EXEC) and start <= self.entry < end:
                entry_ok = True
        if not entry_ok:
            raise ImageError("entry is not inside an executable segment")

    def pack(self) -> bytes:
        self.validate()
        payload = bytearray()
        segment_rows = bytearray()
        for segment in self.segments:
            while len(payload) & 3:
                payload.append(0)
            offset = len(payload)
            payload.extend(segment.data)
            segment_rows.extend(
                _SEGMENT.pack(
                    int(segment.flags),
                    segment.load_address,
                    len(segment.data),
                    segment.memory_size,
                    offset,
                    zlib.crc32(segment.data) & 0xFFFFFFFF,
                )
            )
        header_size = _HEADER.size + len(segment_rows)
        ram_required = max(
            segment.load_address + segment.memory_size for segment in self.segments
        ) - APP_START
        encoded_name = self.name.encode("utf-8") + b"\0"
        encoded_name = encoded_name.ljust(32, b"\0")
        header_without_crcs = _HEADER.pack(
            MAGIC,
            VERSION,
            header_size,
            int(self.image_type),
            self.flags,
            self.entry,
            self.end_pc,
            self.stack_top,
            ram_required,
            len(self.segments),
            len(payload),
            encoded_name,
            self.build_id,
            0,
            0,
        ) + bytes(segment_rows)
        header_crc = zlib.crc32(header_without_crcs) & 0xFFFFFFFF
        image_crc = zlib.crc32(header_without_crcs + payload) & 0xFFFFFFFF
        header = _HEADER.pack(
            MAGIC,
            VERSION,
            header_size,
            int(self.image_type),
            self.flags,
            self.entry,
            self.end_pc,
            self.stack_top,
            ram_required,
            len(self.segments),
            len(payload),
            encoded_name,
            self.build_id,
            header_crc,
            image_crc,
        )
        return header + bytes(segment_rows) + bytes(payload)

    @classmethod
    def unpack(cls, blob: bytes) -> "Image":
        if len(blob) < _HEADER.size:
            raise ImageError("truncated LA32IMG header")
        fields = list(_HEADER.unpack_from(blob))
        magic, version, header_size = fields[:3]
        if magic != MAGIC or version != VERSION:
            raise ImageError("invalid LA32IMG magic or version")
        if header_size < _HEADER.size or header_size > len(blob):
            raise ImageError("invalid LA32IMG header size")
        segment_count = fields[9]
        payload_size = fields[10]
        if header_size != _HEADER.size + segment_count * _SEGMENT.size:
            raise ImageError("segment table size does not match header")
        if header_size + payload_size != len(blob):
            raise ImageError("payload size does not match image length")
        expected_header_crc, expected_image_crc = fields[13], fields[14]
        zeroed = fields[:]
        zeroed[13] = zeroed[14] = 0
        unsigned_header = _HEADER.pack(*zeroed) + blob[_HEADER.size:header_size]
        payload = blob[header_size:]
        if zlib.crc32(unsigned_header) & 0xFFFFFFFF != expected_header_crc:
            raise ImageError("header CRC mismatch")
        if zlib.crc32(unsigned_header + payload) & 0xFFFFFFFF != expected_image_crc:
            raise ImageError("image CRC mismatch")
        segments: list[Segment] = []
        for index in range(segment_count):
            row = _SEGMENT.unpack_from(blob, _HEADER.size + index * _SEGMENT.size)
            flags, address, file_size, memory_size, offset, expected_crc = row
            if offset + file_size > len(payload):
                raise ImageError("segment payload range is invalid")
            data = payload[offset:offset + file_size]
            if zlib.crc32(data) & 0xFFFFFFFF != expected_crc:
                raise ImageError("segment CRC mismatch")
            segments.append(Segment(address, data, memory_size, flags))
        image = cls(
            name=fields[11].split(b"\0", 1)[0].decode("utf-8"),
            image_type=ImageType(fields[3]),
            entry=fields[5],
            segments=segments,
            end_pc=fields[6],
            stack_top=fields[7],
            flags=fields[4],
            build_id=fields[12],
        )
        image.validate()
        return image
