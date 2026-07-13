from __future__ import annotations

import argparse
import json
from pathlib import Path
import shlex
import struct
import subprocess
import sys

from .assembler import Assembler, AssemblyError
from .image import Image, ImageType
from .protocol import Downloader, FrameType


def _type(value: str) -> ImageType:
    try:
        return ImageType[value.upper()]
    except KeyError as error:
        raise argparse.ArgumentTypeError("type must be generic, game or selftest") from error


def _open_serial(port: str, baud: int = 115200):
    try:
        import serial
    except ImportError as error:
        raise RuntimeError("serial commands require pyserial: python -m pip install pyserial") from error
    handle = serial.Serial(port, baudrate=baud, timeout=0.5)
    return handle


def _send_break_reset(handle) -> None:
    """Request the board monitor through the UART RX data path."""
    handle.send_break(duration=0.05)


def command_assemble(args) -> int:
    inputs = []
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    for raw in args.inputs:
        source = Path(raw)
        if source.suffix.lower() != ".c":
            inputs.append(source)
            continue
        generated = output.with_name(f"{source.stem}.gcc.s")
        gcc_args = [
            args.compiler, "-S", "-march=loongarch32r", "-mabi=ilp32s",
            "-msoft-float", "-ffreestanding", "-fno-builtin", "-fno-pic",
            "-fno-pie", "-fno-asynchronous-unwind-tables", "-fno-unwind-tables",
            "-fno-stack-protector", args.optimize,
        ]
        if sys.platform == "win32":
            def wsl_path(path: Path) -> str:
                absolute = path.resolve()
                drive = absolute.drive[0].lower()
                tail = absolute.as_posix().split(":", 1)[1]
                return f"/mnt/{drive}{tail}"
            command = " ".join(shlex.quote(part) for part in gcc_args + [wsl_path(source), "-o", wsl_path(generated)])
            subprocess.run(["wsl", "bash", "-lc", command], check=True)
        else:
            subprocess.run(gcc_args + [str(source), "-o", str(generated)], check=True)
        inputs.append(generated)
        print(f"gcc -S: {source} -> {generated}")
    assembler = Assembler(args.base)
    result = assembler.assemble_files(
        inputs,
        name=args.name,
        image_type=args.type,
        entry=args.entry,
        end_pc=args.end_pc,
    )
    output.write_bytes(result.image.pack())
    stem = output.with_suffix("")
    stem.with_suffix(".bin").write_bytes(result.binary)
    stem.with_suffix(".mif").write_text(result.mif(args.mif_words), encoding="ascii")
    stem.with_suffix(".coe").write_text(result.coe(), encoding="ascii")
    stem.with_suffix(".lst").write_text(result.listing, encoding="utf-8")
    stem.with_suffix(".map").write_text(
        "".join(f"{address:08x} {name}\n" for name, address in sorted(result.symbols.items(), key=lambda item: item[1])),
        encoding="utf-8",
    )
    report = {
        "name": result.image.name,
        "type": result.image.image_type.name,
        "entry": result.image.entry,
        "end_pc": result.image.end_pc,
        "image_bytes": len(result.image.pack()),
        "segments": [
            {"address": s.load_address, "file_size": len(s.data), "memory_size": s.memory_size, "flags": int(s.flags)}
            for s in result.image.segments
        ],
        "symbols": result.symbols,
    }
    stem.with_suffix(".json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"built {output} ({len(result.image.pack())} bytes)")
    return 0


def command_gcc(args) -> int:
    tool = args.compiler
    command = [
        tool, "-S", "-march=loongarch32r", "-mabi=ilp32s", "-msoft-float",
        "-ffreestanding", "-fno-builtin", "-fno-pic", "-fno-pie",
        "-fno-asynchronous-unwind-tables", "-fno-unwind-tables",
        "-fno-stack-protector", args.optimize, args.input, "-o", args.output,
    ]
    if args.wsl:
        quoted = " ".join(subprocess.list2cmdline([part]) for part in command)
        command = ["wsl", "bash", "-lc", quoted]
    subprocess.run(command, check=True)
    return 0


def command_transfer(args, operation: FrameType) -> int:
    blob = Path(args.image).read_bytes()
    Image.unpack(blob)
    with _open_serial(args.port, args.baud) as port:
        if not args.no_reset:
            _send_break_reset(port)
        downloader = Downloader(port, retries=args.retries, timeout=args.timeout)
        if not args.no_reset:
            downloader.wait_ready(max(5.0, args.timeout * args.retries))
        downloader.transfer_image(blob, operation, getattr(args, "slot", 0))
    print("transfer complete")
    return 0


def command_board(args, operation: FrameType) -> int:
    with _open_serial(args.port, args.baud) as port:
        if not args.no_reset:
            _send_break_reset(port)
        downloader = Downloader(port, retries=args.retries, timeout=args.timeout)
        if not args.no_reset:
            downloader.wait_ready(max(5.0, args.timeout * args.retries))
        if operation == FrameType.SCAN_DIRECTORIES:
            response = downloader.request(
                operation,
                struct.pack("<HH", args.start_block, args.count),
                timeout=30.0,
                retries=1,
            )
        else:
            response = downloader.slot_command(
                operation, getattr(args, "slot", None)
            )
    if operation == FrameType.LIST:
        Path(args.output).write_bytes(response.payload)
        print(f"saved board directory to {args.output}")
    elif operation == FrameType.DIAGNOSTICS:
        layout = struct.Struct("<13I")
        if len(response.payload) != layout.size:
            raise RuntimeError(f"unexpected diagnostics size: {len(response.payload)}")
        values = layout.unpack(response.payload)
        signed = lambda value: value if value < 0x80000000 else value - 0x100000000
        names = (
            "version", "nand_id0", "nand_id1", "scan_read_errors",
            "first_scan_error_block", "bad_block_count", "directory_block0",
            "directory_block1", "directory_result0", "directory_result1",
            "selected_generation", "selected_valid_mask", "init_result",
        )
        result = dict(zip(names, values))
        for name in ("directory_result0", "directory_result1", "init_result"):
            result[name] = signed(result[name])
        for name in ("nand_id0", "nand_id1", "selected_valid_mask"):
            result[name] = f"0x{result[name]:08x}"
        print(json.dumps(result, indent=2))
    elif operation == FrameType.SCAN_DIRECTORIES:
        header_layout = struct.Struct("<11I")
        candidate_layout = struct.Struct("<III")
        expected_size = header_layout.size + 16 * candidate_layout.size
        if len(response.payload) != expected_size:
            raise RuntimeError(f"unexpected directory scan size: {len(response.payload)}")
        values = header_layout.unpack_from(response.payload)
        names = (
            "version", "start_block", "scanned_blocks", "raw_read_failures",
            "page_magic_failures", "ecc_failures", "page_crc_failures",
            "directory_magic_failures", "directory_crc_failures",
            "valid_candidates", "stored_candidates",
        )
        result = dict(zip(names, values))
        result["candidates"] = []
        offset = header_layout.size
        for _ in range(min(result["stored_candidates"], 16)):
            block, generation, valid_mask = candidate_layout.unpack_from(response.payload, offset)
            result["candidates"].append({
                "block": block,
                "generation": generation,
                "valid_mask": f"0x{valid_mask:04x}",
            })
            offset += candidate_layout.size
        print(json.dumps(result, indent=2))
    else:
        print("board command complete")
    return 0


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="la32asm", description="final_cpu LA32R toolchain")
    sub = parser.add_subparsers(dest="command", required=True)
    assemble = sub.add_parser("assemble", aliases=["build"])
    assemble.add_argument("inputs", nargs="+")
    assemble.add_argument("-o", "--output", required=True)
    assemble.add_argument("--name", default="program")
    assemble.add_argument("--type", type=_type, default=ImageType.GENERIC)
    assemble.add_argument("--entry", default="_start")
    assemble.add_argument("--end-pc", default="0")
    assemble.add_argument("--base", type=lambda x: int(x, 0), default=0x1C010000)
    assemble.add_argument("--mif-words", type=int, default=262144)
    assemble.add_argument("--compiler", default="/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc")
    assemble.add_argument("--optimize", default="-Os")
    assemble.set_defaults(func=command_assemble)

    gcc = sub.add_parser("gcc")
    gcc.add_argument("input")
    gcc.add_argument("-o", "--output", required=True)
    gcc.add_argument("--compiler", default="/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc")
    gcc.add_argument("--optimize", default="-Os")
    gcc.add_argument("--wsl", action="store_true", default=sys.platform == "win32")
    gcc.set_defaults(func=command_gcc)

    for name, operation in (("install", FrameType.INSTALL), ("run-temporary", FrameType.RUN_TEMPORARY)):
        command = sub.add_parser(name)
        command.add_argument("image")
        command.add_argument("--port", required=True)
        command.add_argument("--baud", type=int, default=115200)
        command.add_argument("--timeout", type=float, default=0.5)
        command.add_argument("--retries", type=int, default=5)
        command.add_argument("--no-reset", action="store_true")
        if name == "install": command.add_argument("--slot", type=int, choices=range(16), required=True)
        command.set_defaults(func=lambda args, op=operation: command_transfer(args, op))
    for name, operation in (("list", FrameType.LIST), ("remove", FrameType.REMOVE),
                            ("verify", FrameType.VERIFY), ("format", FrameType.FORMAT),
                            ("diag", FrameType.DIAGNOSTICS),
                            ("scan-dirs", FrameType.SCAN_DIRECTORIES)):
        command = sub.add_parser(name)
        command.add_argument("--port", required=True)
        command.add_argument("--baud", type=int, default=115200)
        command.add_argument("--timeout", type=float, default=0.5)
        command.add_argument("--retries", type=int, default=5)
        command.add_argument("--no-reset", action="store_true")
        if name in ("remove", "verify"):
            command.add_argument("--slot", type=int, choices=range(16), required=True)
        if name == "list": command.add_argument("-o", "--output", default="board-directory.bin")
        if name == "scan-dirs":
            command.add_argument("--start-block", type=int, choices=range(1024), default=0)
            command.add_argument("--count", type=int, choices=range(1,65), default=32)
        command.set_defaults(func=lambda args, op=operation: command_board(args, op))
    studio = sub.add_parser("studio")
    studio.add_argument("--host", default="127.0.0.1")
    studio.add_argument("--port", type=int, default=8765)
    def run_studio(args):
        from .studio import run
        run(args.host,args.port)
        return 0
    studio.set_defaults(func=run_studio)
    return parser


def main(argv=None) -> int:
    try:
        args = make_parser().parse_args(argv)
        return args.func(args)
    except (AssemblyError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
