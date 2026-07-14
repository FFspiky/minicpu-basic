import os
import pathlib
import shlex
import shutil
import subprocess
import tempfile
import unittest

from la32asm.assembler import Assembler
from la32asm.image import ImageType


FINAL_CPU = pathlib.Path(__file__).resolve().parents[3]


def wsl_path(path: pathlib.Path) -> str:
    resolved = str(path.resolve())
    return "/mnt/" + resolved[0].lower() + resolved[2:].replace("\\", "/")


class RacingIntegrationTest(unittest.TestCase):
    def test_gcc_assembly_matches_existing_gnu_binary(self):
        if shutil.which("wsl") is None:
            self.skipTest("WSL is not available")
        golden_path = FINAL_CPU / "sw" / "game" / "obj" / "racing_game.bin"
        if not golden_path.exists():
            self.skipTest("GNU racing golden binary has not been generated")
        with tempfile.TemporaryDirectory() as directory:
            output = pathlib.Path(directory) / "racing_game.s"
            linux_output = wsl_path(output)
            linux_game = wsl_path(FINAL_CPU / "sw" / "game")
            compiler = os.environ.get(
                "LA32_GCC", "/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc"
            )
            command = (
                f"cd {shlex.quote(linux_game)} && {shlex.quote(compiler)} -S "
                "-march=loongarch32r -mabi=ilp32s -msoft-float -ffreestanding "
                "-fno-builtin -fno-pic -fno-pie -fno-stack-protector -Os "
                f"racing_game.c -o {shlex.quote(linux_output)}"
            )
            subprocess.run(["wsl", "bash", "-lc", command], check=True)
            result = Assembler().assemble_files(
                [FINAL_CPU / "sw" / "game" / "start.S", output],
                name="Racing Game", image_type=ImageType.GAME
            )
            golden = golden_path.read_bytes()
            self.assertEqual(result.binary, golden)


if __name__ == "__main__":
    unittest.main()
