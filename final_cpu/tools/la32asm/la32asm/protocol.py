"""Reliable framed serial protocol shared with the boot monitor."""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import struct
import time
import zlib

SOF = 0x7E
MAX_DATA = 256
_PREFIX = struct.Struct("<BHH")


class FrameType(IntEnum):
    READY = 1
    HEADER = 2
    DATA = 3
    END = 4
    ACK = 5
    NACK = 6
    DONE = 7
    LIST = 8
    INSTALL = 9
    REMOVE = 10
    VERIFY = 11
    RUN_TEMPORARY = 12
    FORMAT = 13


@dataclass(frozen=True)
class Frame:
    frame_type: FrameType
    sequence: int
    payload: bytes = b""

    def pack(self) -> bytes:
        if len(self.payload) > 0xFFFF:
            raise ValueError("frame payload is too large")
        body = _PREFIX.pack(int(self.frame_type), self.sequence & 0xFFFF, len(self.payload)) + self.payload
        return bytes([SOF]) + body + struct.pack("<I", zlib.crc32(body) & 0xFFFFFFFF)

    @classmethod
    def unpack(cls, blob: bytes) -> "Frame":
        if len(blob) < 1 + _PREFIX.size + 4 or blob[0] != SOF:
            raise ValueError("invalid or truncated frame")
        frame_type, sequence, size = _PREFIX.unpack_from(blob, 1)
        expected = 1 + _PREFIX.size + size + 4
        if len(blob) != expected:
            raise ValueError("frame length mismatch")
        body = blob[1:-4]
        if zlib.crc32(body) & 0xFFFFFFFF != struct.unpack_from("<I", blob, len(blob) - 4)[0]:
            raise ValueError("frame CRC mismatch")
        return cls(FrameType(frame_type), sequence, blob[1 + _PREFIX.size:-4])


def read_frame(serial_port, timeout: float = 0.5) -> Frame:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        byte = serial_port.read(1)
        if byte == bytes([SOF]):
            prefix = serial_port.read(_PREFIX.size)
            if len(prefix) != _PREFIX.size:
                break
            _, _, length = _PREFIX.unpack(prefix)
            rest = serial_port.read(length + 4)
            if len(rest) != length + 4:
                break
            return Frame.unpack(byte + prefix + rest)
    raise TimeoutError("timed out waiting for a protocol frame")


class Downloader:
    def __init__(self, serial_port, retries: int = 5, timeout: float = 0.5):
        self.serial = serial_port
        self.retries = retries
        self.timeout = timeout
        self.sequence = 0

    def wait_ready(self, timeout: float = 5.0) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                frame = read_frame(self.serial, min(self.timeout, deadline - time.monotonic()))
            except TimeoutError:
                continue
            if frame.frame_type == FrameType.READY:
                self.sequence = frame.sequence
                return
        raise TimeoutError("board did not enter the boot monitor")

    def request(
        self,
        frame_type: FrameType,
        payload: bytes = b"",
        *,
        timeout: float | None = None,
        retries: int | None = None,
    ) -> Frame:
        frame = Frame(frame_type, self.sequence, payload)
        response_timeout = self.timeout if timeout is None else timeout
        attempt_count = self.retries if retries is None else retries
        for _ in range(attempt_count):
            self.serial.write(frame.pack())
            deadline = time.monotonic() + response_timeout
            while time.monotonic() < deadline:
                try:
                    response = read_frame(
                        self.serial,
                        max(0.001, deadline - time.monotonic()),
                    )
                except (TimeoutError, ValueError):
                    break

                # A physical reset can leave more than one READY frame in the
                # UART receive queue.  READY and stale replies are unsolicited
                # here: ignore them without retransmitting the current command.
                # Retransmission is only safe after the whole reply window has
                # expired.
                if response.frame_type == FrameType.READY:
                    continue
                if response.sequence != self.sequence:
                    continue
                if response.frame_type == FrameType.NACK:
                    raise RuntimeError(f"board rejected frame {self.sequence}: {response.payload.hex()}")
                if response.frame_type in (FrameType.ACK, FrameType.DONE):
                    self.sequence = (self.sequence + 1) & 0xFFFF
                    return response
        raise TimeoutError(f"no acknowledgement for frame {self.sequence}")

    def transfer_image(
        self,
        image: bytes,
        operation: FrameType,
        slot: int = 0,
        progress=None,
    ) -> None:
        if operation not in (FrameType.INSTALL, FrameType.RUN_TEMPORARY):
            raise ValueError("operation must be INSTALL or RUN_TEMPORARY")
        total_frames = (len(image) + MAX_DATA - 1) // MAX_DATA
        if progress:
            progress("prepare", 0, total_frames, 0, len(image))
        self.request(operation, struct.pack("<BI", slot, len(image)))
        self.request(FrameType.HEADER, image[: min(len(image), 512)])
        for frame_index, offset in enumerate(range(0, len(image), MAX_DATA), 1):
            chunk = image[offset:offset + MAX_DATA]
            # Keep stop-and-wait flow control: while the monitor computes the
            # frame CRC and transmits its ACK it does not drain the 16-byte RX
            # FIFO, so sending the next frame early could overflow the board.
            self.request(FrameType.DATA, struct.pack("<I", offset) + chunk)
            if progress:
                progress(
                    "transfer",
                    frame_index,
                    total_frames,
                    offset + len(chunk),
                    len(image),
                )
        # END performs image validation and, for INSTALL, synchronous NAND
        # erase/program/readback before the monitor replies.  It must not use
        # the sub-second per-frame timeout used by ordinary UART traffic.
        if progress:
            progress("commit", total_frames, total_frames, len(image), len(image))
        self.request(
            FrameType.END,
            struct.pack("<I", zlib.crc32(image) & 0xFFFFFFFF),
            timeout=120.0,
            retries=2,
        )
        if progress:
            progress("done", total_frames, total_frames, len(image), len(image))

    def slot_command(self, operation: FrameType, slot: int | None = None) -> Frame:
        payload = b"" if slot is None else bytes([slot])
        if operation in (FrameType.FORMAT, FrameType.VERIFY, FrameType.REMOVE):
            return self.request(operation, payload, timeout=120.0, retries=2)
        return self.request(operation, payload)
