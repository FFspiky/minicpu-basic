import pathlib
import shutil
import subprocess
import tempfile
import unittest

from la32asm.assembler import Assembler
from la32asm.image import ImageType


FINAL_CPU = pathlib.Path(__file__).resolve().parents[3]


class RacingIntegrationTest(unittest.TestCase):
    def test_gcc_assembly_matches_existing_gnu_binary(self):
        if shutil.which("wsl") is None:
            self.skipTest("WSL is not available")
        with tempfile.TemporaryDirectory() as directory:
            output = pathlib.Path(directory) / "racing_game.s"
            resolved = str(output.resolve())
            linux_output = "/mnt/" + resolved[0].lower() + resolved[2:].replace("\\", "/")
            command = (
                "cd /mnt/d/CPU_DESIGN/final_cpu/sw/game && "
                "/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc -S "
                "-march=loongarch32r -mabi=ilp32s -msoft-float -ffreestanding "
                "-fno-builtin -fno-pic -fno-pie -fno-stack-protector -Os "
                f"racing_game.c -o {linux_output}"
            )
            subprocess.run(["wsl", "bash", "-lc", command], check=True)
            result = Assembler().assemble_files(
                [FINAL_CPU / "sw" / "game" / "start.S", output],
                name="Racing Game", image_type=ImageType.GAME
            )
            golden = (FINAL_CPU / "sw" / "game" / "obj" / "racing_game.bin").read_bytes()
            self.assertEqual(result.binary, golden)


if __name__ == "__main__":
    unittest.main()
