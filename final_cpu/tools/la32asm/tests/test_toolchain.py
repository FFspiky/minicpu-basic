import struct
import unittest
from unittest.mock import patch

from la32asm.assembler import Assembler, AssemblyError
from la32asm.image import Image, ImageError, ImageType
from la32asm.protocol import Downloader, Frame, FrameType
from la32asm.cli import _connect_board, _send_break_reset
from la32asm.studio import (
    _boot_monitor, _probe_monitor, read_directory_slots, read_ui_status,
)


class AssemblerTests(unittest.TestCase):
    def assemble_words(self, source):
        result = Assembler().assemble([("test.S", source)], entry="_start")
        return list(struct.unpack("<" + "I" * (len(result.binary) // 4), result.binary))

    def test_core_encodings(self):
        words = self.assemble_words("""
_start:
    add.w $a0, $a1, $a2
    addi.w $sp, $sp, -16
    ori $a0, $zero, 0x123
    lu12i.w $t0, 0x12345
    ld.w $a1, 8($sp)
    st.w $a1, -4($sp)
""")
        self.assertEqual(words[0], (0x020 << 15) | (6 << 10) | (5 << 5) | 4)
        self.assertEqual(words[1], (0b0000001010 << 22) | (0xFF0 << 10) | (3 << 5) | 3)
        self.assertEqual(words[2], (0b0000001110 << 22) | (0x123 << 10) | 4)
        self.assertEqual(words[3], (0b0001010 << 25) | (0x12345 << 5) | 12)

    def test_labels_and_pseudo(self):
        words = self.assemble_words("""
_start:
    li.w $a0, 0x12345678
1:  addi.w $a0, $a0, -1
    bne $a0, $zero, 1b
    nop
""")
        self.assertEqual(len(words), 5)
        self.assertEqual(words[-1], 0x03400000)

    def test_rejects_out_of_range_immediate(self):
        with self.assertRaises(AssemblyError):
            self.assemble_words("_start: addi.w $a0, $zero, 4096")

    def test_exp16_gas_compatibility(self):
        words = self.assemble_words("""
_start:
    li.w $t0, 0
    li.w $t1, 1
    li.w $t2, -1
    jirl $zero, $ra, 0
    .org 0x20
1:  b 1b
""")
        self.assertEqual(words[0], 0x0015000C)
        self.assertEqual(words[1], 0x0380040D)
        self.assertEqual(words[2], 0x02BFFC0E)
        self.assertEqual(words[3], 0x4C000020)
        self.assertEqual(words[4:8], [0, 0, 0, 0])

    def test_gcc_local_symbols_are_scoped_per_source(self):
        result = Assembler().assemble([
            ("one.s", ".text\n_start: b .LC0\n.LC0: nop"),
            ("two.s", ".text\nhelper: b .LC0\n.LC0: nop"),
        ], entry="_start")
        self.assertIn(".__la32_f0_LC0", result.symbols)
        self.assertIn(".__la32_f1_LC0", result.symbols)

    def test_local_common_symbols_allocate_aligned_bss(self):
        result = Assembler().assemble([
            ("one.s", ".text\n_start: la.local $a0, value\n.local value\n.comm value,4,16"),
            ("two.s", ".text\nhelper: la.local $a0, value\n.local value\n.comm value,8,8"),
        ], entry="_start")
        names = [name for name in result.symbols if "local_value" in name]
        self.assertEqual(len(names), 2)
        self.assertTrue(all(result.symbols[name] % 8 == 0 for name in names))
        load_segment = result.image.segments[0]
        self.assertEqual(len(result.image.segments), 1)
        self.assertGreater(load_segment.memory_size, len(load_segment.data))
        self.assertGreaterEqual(load_segment.memory_size - len(load_segment.data), 12)

    def test_image_is_safe_for_in_place_monitor_loading(self):
        result = Assembler().assemble([("multi.s", """
.text
_start: la.local $a0, message
.rodata
message: .asciz "hello"
.data
.align 2
value: .word 7
.bss
.align 4
scratch: .space 32
""")], entry="_start")
        self.assertEqual(len(result.image.segments), 1)
        segment = result.image.segments[0]
        blob = result.image.pack()
        memory = bytearray(blob)
        memory.extend(b"\xaa" * (segment.memory_size + 64))
        header_size = len(blob) - len(segment.data)
        source = bytes(memory[header_size:header_size + len(segment.data)])
        memory[:len(source)] = source
        memory[len(source):segment.memory_size] = b"\0" * (segment.memory_size - len(source))
        self.assertEqual(bytes(memory[:len(segment.data)]), segment.data)
        self.assertEqual(memory[len(segment.data):segment.memory_size], b"\0" * (segment.memory_size - len(segment.data)))


class ImageTests(unittest.TestCase):
    def test_round_trip_and_corruption(self):
        result = Assembler().assemble([("x.S", "_start: addi.w $a0,$zero,1")], name="x", image_type=ImageType.GAME)
        blob = result.image.pack()
        parsed = Image.unpack(blob)
        self.assertEqual(parsed.name, "x")
        damaged = bytearray(blob); damaged[-1] ^= 1
        with self.assertRaises(ImageError): Image.unpack(bytes(damaged))


class ProtocolTests(unittest.TestCase):
    def test_frame_round_trip(self):
        frame = Frame(FrameType.DATA, 7, b"payload")
        self.assertEqual(Frame.unpack(frame.pack()), frame)

    def test_studio_reads_directory_as_short_per_slot_frames(self):
        class DirectoryDownloader:
            def __init__(self): self.requests = []
            def slot_command(self, operation, slot):
                self.requests.append((operation, slot))
                name = (f"slot-{slot}".encode() + bytes(32))[:32]
                record = struct.pack(
                    "<32sIIBBH7H", name, 1000 + slot, 0x12340000 + slot,
                    1, 1, 0, 20 + slot, 0, 0, 0, 0, 0, 0,
                )
                payload = struct.pack("<IIHH", 0x4C413332, 6, 3, slot) + record
                return Frame(FrameType.DONE, slot, payload)

        downloader = DirectoryDownloader()
        rows = read_directory_slots(downloader)
        self.assertEqual(
            downloader.requests,
            [(FrameType.LIST, slot) for slot in range(16)],
        )
        self.assertEqual(len(rows), 16)
        self.assertEqual(rows[0]["name"], "slot-0")
        self.assertEqual(rows[1]["blocks"], [21])
        self.assertTrue(rows[0]["valid"])
        self.assertTrue(rows[1]["valid"])
        self.assertFalse(rows[2]["valid"])

    def test_studio_rejects_inconsistent_short_directory_frames(self):
        class ChangingDirectoryDownloader:
            def slot_command(self, operation, slot):
                record = struct.pack("<32sIIBBH7H", b"", 0, 0, 0, 0, 0,
                                     0, 0, 0, 0, 0, 0, 0)
                return Frame(
                    FrameType.DONE, slot,
                    struct.pack("<IIHH", 0x4C413332, slot, 0, slot) + record,
                )

        with self.assertRaisesRegex(ValueError, "changed while"):
            read_directory_slots(ChangingDirectoryDownloader())

    def test_studio_decodes_vga_logical_status(self):
        class StatusDownloader:
            def request(self, operation):
                self.operation = operation
                return Frame(
                    FrameType.DONE, 4,
                    struct.pack("<7I", 1, 0, 2, 1, 7, 0, 0x1C020000),
                )

        downloader = StatusDownloader()
        status = read_ui_status(downloader)
        self.assertEqual(downloader.operation, FrameType.UI_STATUS)
        self.assertEqual(status["screen"], "PROGRAM MENU")
        self.assertEqual(status["status_text"], "READY")
        self.assertEqual(status["valid_mask"], "0x0007")
        self.assertTrue(status["selected_valid"])
        self.assertEqual(status["dynamic_end_pc"], "0x1c020000")

    def test_studio_decodes_program_running_and_done(self):
        class StatusDownloader:
            def __init__(self, value): self.value = value
            def request(self, operation):
                return Frame(
                    FrameType.DONE, 4,
                    struct.pack("<7I", 1, 3, 15, 0, 1, self.value, 0),
                )

        self.assertEqual(read_ui_status(StatusDownloader(3))["status_text"], "RUNNING")
        self.assertEqual(read_ui_status(StatusDownloader(4))["status_text"], "DONE")

    def test_downloader_waits_for_ready_after_boot_text(self):
        class SerialBytes:
            def __init__(self, data): self.data = bytearray(data)
            def read(self, size):
                chunk = self.data[:size]
                del self.data[:size]
                return bytes(chunk)
        stream = SerialBytes(b"LA32BOOT 1\r\n" + Frame(FrameType.READY, 23).pack())
        downloader = Downloader(stream, timeout=0.01)
        downloader.wait_ready(0.1)
        self.assertEqual(downloader.sequence, 23)

    def test_downloader_ignores_duplicate_ready_without_retransmitting(self):
        class SerialBytes:
            def __init__(self, data):
                self.data = bytearray(data)
                self.writes = []
            def read(self, size):
                chunk = self.data[:size]
                del self.data[:size]
                return bytes(chunk)
            def write(self, data):
                self.writes.append(bytes(data))
                return len(data)

        stream = SerialBytes(
            Frame(FrameType.READY, 0).pack()
            + Frame(FrameType.ACK, 0, b"\0").pack()
        )
        downloader = Downloader(stream, timeout=0.05)
        response = downloader.request(FrameType.LIST)
        self.assertEqual(response.frame_type, FrameType.ACK)
        self.assertEqual(downloader.sequence, 1)
        self.assertEqual(len(stream.writes), 1)

    def test_image_transfer_uses_256_byte_data_chunks(self):
        class TransferSerial:
            def __init__(self):
                self.data = bytearray()
                self.requests = []
            def write(self, data):
                request = Frame.unpack(bytes(data))
                self.requests.append(request)
                self.data.extend(Frame(FrameType.ACK, request.sequence, b"\0").pack())
                return len(data)
            def read(self, size):
                chunk = self.data[:size]
                del self.data[:size]
                return bytes(chunk)

        stream = TransferSerial()
        downloader = Downloader(stream, retries=2, timeout=0.05)
        progress = []
        downloader.transfer_image(
            bytes(1025), FrameType.INSTALL, 0,
            progress=lambda *event: progress.append(event),
        )
        data = [request for request in stream.requests if request.frame_type == FrameType.DATA]
        self.assertEqual(len(data), 15)
        self.assertEqual(
            [len(request.payload) for request in data[::3]],
            [260, 260, 260, 260, 5],
        )
        self.assertEqual(
            [struct.unpack_from("<I", request.payload)[0] for request in data[::3]],
            [0, 256, 512, 768, 1024],
        )
        for group in range(0, len(data), 3):
            self.assertEqual(data[group:group + 3], [data[group]] * 3)
        non_data = [
            request.frame_type for request in stream.requests
            if request.frame_type != FrameType.DATA
        ]
        self.assertEqual(non_data, [
            FrameType.INSTALL, FrameType.HEADER,
            FrameType.END, FrameType.END, FrameType.END,
        ])
        end = [request for request in stream.requests
               if request.frame_type == FrameType.END]
        self.assertEqual(end, [end[0]] * 3)
        self.assertEqual([event[0] for event in progress], [
            "prepare", "transfer", "transfer", "transfer", "transfer",
            "transfer", "commit", "done",
        ])
        self.assertEqual(progress[-1][1:], (5, 5, 1025, 1025))

    def test_temporary_run_starts_only_after_end_done(self):
        class TransferSerial:
            def __init__(self):
                self.data = bytearray()
                self.requests = []
                self.reset_count = 0
            def write(self, data):
                request = Frame.unpack(bytes(data))
                self.requests.append(request)
                if request.frame_type != FrameType.RUN_START:
                    self.data.extend(
                        Frame(FrameType.DONE, request.sequence, b"\0").pack()
                    )
                return len(data)
            def read(self, size):
                chunk = self.data[:size]
                del self.data[:size]
                return bytes(chunk)
            def reset_input_buffer(self):
                self.data.clear()
                self.reset_count += 1

        stream = TransferSerial()
        downloader = Downloader(stream, retries=2, timeout=0.05)
        downloader.transfer_image(
            bytes(16), FrameType.RUN_TEMPORARY, 15,
        )
        end_indexes = [index for index, request in enumerate(stream.requests)
                       if request.frame_type == FrameType.END]
        start_indexes = [index for index, request in enumerate(stream.requests)
                         if request.frame_type == FrameType.RUN_START]
        self.assertEqual(len(end_indexes), 3)
        self.assertEqual(len(start_indexes), 3)
        self.assertLess(max(end_indexes), min(start_indexes))
        starts = [stream.requests[index] for index in start_indexes]
        self.assertEqual(starts, [starts[0]] * 3)
        self.assertEqual(starts[0].sequence, 4)
        self.assertEqual(stream.reset_count, 1)

    def test_studio_attaches_to_existing_monitor_without_reset(self):
        class MonitorSerial:
            def __init__(self):
                self.data = bytearray()
                self.reset_count = 0
            def reset_input_buffer(self):
                self.data.clear()
                self.reset_count += 1
            def write(self, data):
                request = Frame.unpack(bytes(data))
                self.data.extend(Frame(FrameType.DONE, request.sequence, b"directory").pack())
                return len(data)
            def read(self, size):
                chunk = self.data[:size]
                del self.data[:size]
                return bytes(chunk)

        stream = MonitorSerial()
        with patch("la32asm.studio._sync_uart") as sync_uart, \
             patch("la32asm.studio._break_reset") as break_reset:
            downloader = _boot_monitor(stream)
        # _boot_monitor deliberately returns a fresh, fully retried
        # Downloader after the one-shot liveness probe.  The board protocol
        # is stateless with respect to sequence numbers, so transfers restart
        # at zero.
        self.assertEqual(downloader.sequence, 0)
        self.assertEqual(stream.reset_count, 1)
        sync_uart.assert_called_once_with(stream)
        break_reset.assert_not_called()

    def test_host_reset_uses_uart_break(self):
        class BreakSerial:
            def __init__(self):
                self.durations = []
                self.reset_count = 0
            def reset_input_buffer(self):
                self.reset_count += 1
            def send_break(self, duration):
                self.durations.append(duration)

        stream = BreakSerial()
        _send_break_reset(stream)
        self.assertEqual(stream.reset_count, 1)
        self.assertEqual(stream.durations, [0.05])

    def test_cli_attaches_to_running_monitor_without_break(self):
        class MonitorSerial:
            def __init__(self):
                self.data = bytearray()
                self.breaks = 0
                self.writes = 0
            def reset_input_buffer(self):
                self.data.clear()
            def send_break(self, duration):
                self.breaks += 1
            def write(self, data):
                self.writes += 1
                if self.writes == 1:
                    return len(data)
                request = Frame.unpack(bytes(data))
                self.data.extend(Frame(FrameType.NACK, request.sequence, b"\x07").pack())
                return len(data)
            def read(self, size):
                chunk = self.data[:size]
                del self.data[:size]
                return bytes(chunk)

        args = type("Args", (), {
            "retries": 5, "timeout": 0.5, "no_reset": False,
        })()
        stream = MonitorSerial()
        downloader = _connect_board(stream, args)
        self.assertEqual(stream.breaks, 0)
        self.assertEqual(stream.writes, 2)
        self.assertEqual(downloader.retries, 5)

    def test_monitor_probe_does_not_require_ready_banner(self):
        class MonitorSerial:
            def __init__(self):
                self.data = bytearray()
            def write(self, data):
                request = Frame.unpack(bytes(data))
                self.data.extend(Frame(FrameType.DONE, request.sequence, b"directory").pack())
                return len(data)
            def read(self, size):
                chunk = self.data[:size]
                del self.data[:size]
                return bytes(chunk)

        downloader = _probe_monitor(MonitorSerial(), timeout=0.01)
        self.assertIsNotNone(downloader)
        self.assertEqual(downloader.sequence, 1)


if __name__ == "__main__":
    unittest.main()
