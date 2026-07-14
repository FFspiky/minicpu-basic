"""Reliable framed serial protocol shared with the boot monitor."""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import struct
import time
import zlib

SOF = 0x7E
SYNC_BYTE = 0x55
DEFAULT_SYNC_BYTES = 8
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
    DIAGNOSTICS = 14
    SCAN_DIRECTORIES = 15
    RUN_START = 16
    UI_STATUS = 17


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
    def __init__(
        self,
        serial_port,
        retries: int = 5,
        timeout: float = 0.5,
        sync_bytes: int = DEFAULT_SYNC_BYTES,
    ):
        if sync_bytes < 0:
            raise ValueError("sync_bytes must not be negative")
        self.serial = serial_port
        self.retries = retries
        self.timeout = timeout
        self.sync_bytes = sync_bytes
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
        copies: int = 1,
    ) -> Frame:
        if copies < 1:
            raise ValueError("copies must be positive")
        frame = Frame(frame_type, self.sequence, payload)
        response_timeout = self.timeout if timeout is None else timeout
        attempt_count = self.retries if retries is None else retries
        for _ in range(attempt_count):
            packed = frame.pack()
            if copies == 1:
                # The physical 50 MHz board occasionally samples the first
                # start bit outside its reliable RX phase window.  A short
                # 0x55 train gives the synchronizer several harmless edges
                # immediately before the one real frame.  The monitor seeks
                # SOF and ignores these bytes, and combining both parts in one
                # host write prevents an OS scheduling gap between them.
                self.serial.write(bytes([SYNC_BYTE]) * self.sync_bytes + packed)
            else:
                # Copies are used only for commands documented as idempotent.
                # Do not add a preamble between adjacent copies: DATA uses two
                # back-to-back frames and END/RUN_START use three.
                for _ in range(copies):
                    self.serial.write(packed)
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
            # frame CRC and transmits its ACK it momentarily does not drain the
            # 512-byte RX FIFO, so sending the next sequence early could still
            # mix acknowledgements with queued duplicate frames.
            # DATA writes are idempotent: both copies carry the same sequence,
            # offset and bytes.  Three continuous copies were fast on short
            # images but accumulated receive pressure during a 532636-byte
            # physical-board transfer and eventually produced NACK 04.  Two
            # copies passed 800 frames beyond that failure point.  A DATA ACK
            # is immediate, so a short retry window avoids spending 0.75 s on
            # a phase-lost group without changing the long END timeout.
            self.request(
                FrameType.DATA,
                struct.pack("<I", offset) + chunk,
                timeout=min(self.timeout, 0.25),
                copies=2,
            )
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
        # Programming cost grows with page count.  Small images should retry a
        # lost DONE promptly, while the largest supported images still get a
        # bounded window for synchronous program/readback.  END is idempotent
        # in the monitor, so same-sequence retransmission cannot install twice.
        # Send adjacent copies as well as timed retries: on RUN_TEMPORARY the
        # monitor flushes DONE before starting the application, so one accepted
        # copy is sufficient and queued duplicates cannot pre-empt the reply.
        page_count = (len(image) + 2047) // 2048
        commit_timeout = max(5.0, 2.0 + page_count * 0.15)
        self.request(
            FrameType.END,
            struct.pack("<I", zlib.crc32(image) & 0xFFFFFFFF),
            timeout=commit_timeout,
            retries=self.retries,
            copies=3,
        )
        # Every accepted END copy produces the same cached DONE.  The first
        # one completes request(), but later replies may still be in the USB
        # serial buffer.  The monitor has not started a temporary application
        # yet, so allow those short frames to arrive and discard them before
        # RUN_START; otherwise they would be displayed as application output.
        time.sleep(0.05)
        reset_input = getattr(self.serial, "reset_input_buffer", None)
        if reset_input is not None:
            reset_input()
        if operation == FrameType.RUN_TEMPORARY:
            # END only validates the RAM image.  Keep the monitor available
            # until DONE has actually reached us, then send a one-way start
            # command and immediately return to the caller's output capture.
            # Adjacent copies make the command robust to the board RX phase;
            # after the first copy starts the application, later copies are
            # harmless bytes in an RX FIFO the generic runtime does not read.
            start = Frame(FrameType.RUN_START, self.sequence).pack()
            for _ in range(3):
                self.serial.write(start)
            self.sequence = (self.sequence + 1) & 0xFFFF
        if progress:
            progress("done", total_frames, total_frames, len(image), len(image))

    def slot_command(self, operation: FrameType, slot: int | None = None) -> Frame:
        payload = b"" if slot is None else bytes([slot])
        if operation == FrameType.FORMAT:
            # FORMAT is deliberately not repeated: a lost reply must not
            # silently launch a second full-device erase.
            return self.request(operation, payload, timeout=120.0, retries=1)
        if operation == FrameType.VERIFY:
            # The largest seven-block image verifies in several seconds on
            # the physical board.  Fifteen seconds covers that work without
            # turning one lost request into a four-minute apparent hang.
            return self.request(operation, payload, timeout=15.0, retries=2)
        if operation == FrameType.REMOVE:
            # REMOVE updates one directory copy and is not safely repeatable
            # when the first ACK is lost.
            return self.request(operation, payload, timeout=10.0, retries=1)
        if operation == FrameType.SCAN_DIRECTORIES:
            return self.request(operation, payload, timeout=30.0, retries=1)
        return self.request(operation, payload)
