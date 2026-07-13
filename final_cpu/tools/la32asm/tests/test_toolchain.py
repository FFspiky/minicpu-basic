import struct
import unittest

from la32asm.assembler import Assembler, AssemblyError
from la32asm.image import Image, ImageError, ImageType
from la32asm.protocol import Downloader, Frame, FrameType


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
        bss = result.image.segments[-1]
        self.assertEqual(len(bss.data), 0)
        self.assertGreaterEqual(bss.memory_size, 12)


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


if __name__ == "__main__":
    unittest.main()
