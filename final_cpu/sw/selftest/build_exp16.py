"""Build the relocated pipeline EXP16 test with the custom LA32R assembler."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

SELFTEST = Path(__file__).resolve().parent
FINAL_CPU = SELFTEST.parents[1]
sys.path.insert(0, str(FINAL_CPU / "tools" / "la32asm"))

from la32asm.assembler import Assembler  # noqa: E402
from la32asm.image import ImageType  # noqa: E402


def wsl_path(path: Path) -> str:
    absolute = path.resolve()
    return f"/mnt/{absolute.drive[0].lower()}{absolute.as_posix().split(':', 1)[1]}"


def main() -> int:
    source = SELFTEST / "trace_exp16"
    generated = SELFTEST / "build" / "trace_exp16"
    if sys.platform == "win32":
        subprocess.run(["wsl", "bash", wsl_path(source / "preprocess.sh"), wsl_path(generated)], check=True)
    else:
        subprocess.run(["bash", str(source / "preprocess.sh"), str(generated)], check=True)

    inputs = [generated / "00_start.s", generated / "01_init.s"]
    for number in range(1, 59):
        matches = list(generated.glob(f"n{number}_*.s"))
        if len(matches) != 1:
            raise RuntimeError(f"expected one generated source for n{number}, found {len(matches)}")
        inputs.append(matches[0])

    result = Assembler().assemble_files(
        inputs, name="Pipeline EXP16", image_type=ImageType.SELFTEST,
        entry="_start", end_pc="test_finish",
    )
    stem = SELFTEST / "build" / "trace_exp16"
    image = result.image.pack()
    stem.with_suffix(".la32img").write_bytes(image)
    stem.with_suffix(".bin").write_bytes(result.binary)
    stem.with_suffix(".mif").write_text(result.mif(), encoding="ascii")
    stem.with_suffix(".lst").write_text(result.listing, encoding="utf-8")
    stem.with_suffix(".map").write_text(
        "".join(f"{address:08x} {name}\n" for name, address in sorted(result.symbols.items(), key=lambda item: item[1])),
        encoding="utf-8",
    )
    stem.with_suffix(".json").write_text(json.dumps({
        "name": result.image.name,
        "type": result.image.image_type.name,
        "entry": result.image.entry,
        "end_pc": result.image.end_pc,
        "image_bytes": len(image),
        "tests": "n1-n58",
        "machine_code_generator": "la32asm",
        "gnu_as_ld_objcopy_used": False,
    }, indent=2), encoding="utf-8")
    print(f"built {stem.with_suffix('.la32img')} ({len(image)} bytes, n1-n58)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
