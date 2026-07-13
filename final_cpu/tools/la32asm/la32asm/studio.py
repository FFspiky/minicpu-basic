from __future__ import annotations

import json
from pathlib import Path
import struct
import subprocess
import sys
import threading
import time

from pydantic import BaseModel

from .assembler import Assembler
from .image import ImageType
from .protocol import Downloader, FrameType

FINAL_CPU = Path(__file__).resolve().parents[3]
BUILD = FINAL_CPU / "tools" / "la32asm" / "build"
STATIC = FINAL_CPU / "tools" / "la32asm" / "studio"
SERIAL_LOCK = threading.Lock()
BUILD_LOCK = threading.Lock()
COMPILER = "/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc"


class PortRequest(BaseModel):
    port: str


class InstallRequest(BaseModel):
    port: str
    slot: int
    image: str | None = None


class SlotRequest(BaseModel):
    port: str
    slot: int


class SourceRequest(BaseModel):
    source: str


class RunSourceRequest(BaseModel):
    source: str
    port: str


def _serial(port_name: str):
    try:
        import serial
    except ImportError as error:
        raise RuntimeError("pyserial is required") from error
    return serial.Serial(port_name, 115200, timeout=0.5)


def _dtr(port):
    port.dtr=False;time.sleep(.05);port.dtr=True;time.sleep(.05);port.dtr=False


def _wsl_path(path: Path) -> str:
    absolute = path.resolve()
    drive = absolute.drive[0].lower()
    tail = absolute.as_posix().split(":", 1)[1]
    return f"/mnt/{drive}{tail}"


def _compile_c(source: Path, output: Path) -> str:
    arguments = [
        COMPILER, "-S", "-march=loongarch32r", "-mabi=ilp32s", "-msoft-float",
        "-ffreestanding", "-fno-builtin", "-fno-pic", "-fno-pie",
        "-fno-asynchronous-unwind-tables", "-fno-unwind-tables",
        "-fno-stack-protector", "-Wall", "-Werror=implicit-function-declaration",
        "-Werror=int-conversion", "-Werror=incompatible-pointer-types",
        "-Os", _wsl_path(source), "-o", _wsl_path(output),
    ]
    command = " ".join(subprocess.list2cmdline([part]) for part in arguments)
    completed = subprocess.run(
        ["wsl", "bash", "-lc", command], capture_output=True,
    )
    if completed.returncode:
        detail = (completed.stderr or completed.stdout).decode("utf-8", "replace").strip()
        # Some Windows/WSL versions prepend a UTF-16 diagnostic to otherwise
        # UTF-8 GCC stderr.  Keep the actionable compiler diagnostics.
        gcc_start = detail.find("/mnt/")
        if gcc_start >= 0:
            detail = detail[gcc_start:]
        raise RuntimeError(detail or f"GCC exited with code {completed.returncode}")
    return ""


def build_racing() -> dict:
    BUILD.mkdir(parents=True, exist_ok=True)
    source = FINAL_CPU / "sw" / "game" / "racing_game.c"
    generated = BUILD / "racing_game.s"
    linux_source = "/mnt/d/CPU_DESIGN/final_cpu/sw/game/racing_game.c"
    linux_output = "/mnt/d/CPU_DESIGN/final_cpu/tools/la32asm/build/racing_game.s"
    command = (
        "/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc -S "
        "-march=loongarch32r -mabi=ilp32s -msoft-float -ffreestanding "
        "-fno-builtin -fno-pic -fno-pie -fno-stack-protector -Os "
        f"{linux_source} -o {linux_output}"
    )
    subprocess.run(["wsl", "bash", "-lc", command], check=True, capture_output=True)
    result = Assembler().assemble_files(
        [FINAL_CPU / "sw" / "game" / "start.S", generated],
        name="Racing Game", image_type=ImageType.GAME, entry="_start"
    )
    image_path = BUILD / "racing.la32img"
    image_path.write_bytes(result.image.pack())
    (BUILD / "racing.lst").write_text(result.listing, encoding="utf-8")
    report = {
        "c_source": source.read_text(encoding="utf-8"),
        "assembly": generated.read_text(encoding="utf-8"),
        "listing": result.listing,
        "image": str(image_path),
        "image_size": len(result.image.pack()),
        "symbols": result.symbols,
    }
    (BUILD / "racing-report.json").write_text(json.dumps(report, ensure_ascii=False), encoding="utf-8")
    return report


def build_generic(source_text: str) -> dict:
    if not source_text.strip():
        raise ValueError("C source is empty")
    if len(source_text.encode("utf-8")) > 64 * 1024:
        raise ValueError("C source exceeds the 64 KiB Studio limit")
    BUILD.mkdir(parents=True, exist_ok=True)
    source = BUILD / "playground.c"
    generated = BUILD / "playground.gcc.s"
    runtime_source = FINAL_CPU / "sw" / "generic" / "runtime.c"
    runtime_assembly = BUILD / "generic-runtime.gcc.s"
    source.write_text(source_text, encoding="utf-8")
    compiler_messages = _compile_c(source, generated)
    _compile_c(runtime_source, runtime_assembly)
    result = Assembler().assemble_files(
        [FINAL_CPU / "sw" / "generic" / "start.S", generated, runtime_assembly],
        name="C Playground", image_type=ImageType.GENERIC, entry="_start",
    )
    image_path = BUILD / "playground.la32img"
    image_blob = result.image.pack()
    image_path.write_bytes(image_blob)
    listing_path = BUILD / "playground.lst"
    listing_path.write_text(result.listing, encoding="utf-8")
    (BUILD / "playground.bin").write_bytes(result.binary)
    (BUILD / "playground.mif").write_text(result.mif(), encoding="ascii")
    return {
        "c_source": source_text,
        "assembly": generated.read_text(encoding="utf-8"),
        "runtime_assembly": runtime_assembly.read_text(encoding="utf-8"),
        "listing": result.listing,
        "image": str(image_path),
        "binary": str(BUILD / "playground.bin"),
        "image_size": len(image_blob),
        "symbols": result.symbols,
        "compiler_messages": compiler_messages,
    }


def run_generic(source_text: str, port_name: str) -> dict:
    with BUILD_LOCK:
        report = build_generic(source_text)
        image = Path(report["image"]).read_bytes()
    output = bytearray()
    completed = False
    with SERIAL_LOCK, _serial(port_name) as port:
        _dtr(port)
        downloader = Downloader(port)
        downloader.wait_ready(5.0)
        downloader.transfer_image(image, FrameType.RUN_TEMPORARY)
        deadline = time.monotonic() + 5.0
        while time.monotonic() < deadline:
            chunk = port.read(1)
            if not chunk:
                continue
            if chunk == b"\x04":
                completed = True
                break
            output.extend(chunk)
            if len(output) >= 64 * 1024:
                break
    report["output"] = output.decode("utf-8", "replace")
    report["completed"] = completed
    if not completed:
        report["output"] += "\n[Studio: output capture timed out or exceeded 64 KiB]"
    return report


def build_selftest() -> dict:
    BUILD.mkdir(parents=True, exist_ok=True)
    script=FINAL_CPU/"sw"/"selftest"/"build_exp16.py"
    subprocess.run([sys.executable,str(script)],check=True)
    product=FINAL_CPU/"sw"/"selftest"/"build"/"trace_exp16.la32img"
    report=json.loads(product.with_suffix(".json").read_text(encoding="utf-8"))
    image_path=BUILD/"selftest.la32img"
    image_path.write_bytes(product.read_bytes())
    source=FINAL_CPU/"sw"/"selftest"/"trace_exp16"/"start.S"
    generated=FINAL_CPU/"sw"/"selftest"/"build"/"trace_exp16"/"00_start.s"
    listing_path=product.with_suffix(".lst")
    listing_text=listing_path.read_text(encoding="utf-8")
    preview_limit=600_000
    if len(listing_text)>preview_limit:
        listing_text=(listing_text[:preview_limit]+"\n\n"
                      f"--- 页面预览已截断：完整listing共{listing_path.stat().st_size}字节 ---\n"
                      f"完整文件：{listing_path}")
    manifest=("Pipeline EXP16 完整流水线上板测试\n"
              "测试范围：n1-n58\n"
              "输入文件：start.S、init.S、n1...n58（共60个汇编文件）\n"
              "入口：0x1c010000\n动态结束PC：0x1c010100\n"
              "机器码生成器：自研la32asm\nGNU as/ld/objcopy：未调用\n\n")
    return {"c_source":manifest+source.read_text(encoding="utf-8"),
            "assembly":generated.read_text(encoding="utf-8"),
            "listing":listing_text,"listing_path":str(listing_path),
            "image":str(image_path),"image_size":image_path.stat().st_size,
            "report":report}


def parse_directory(payload: bytes) -> list[dict]:
    if len(payload) < 1072:
        raise ValueError("board directory response is truncated")
    magic, generation, mask, _ = struct.unpack_from("<IIHH", payload)
    rows=[]; offset=12; slot_struct=struct.Struct("<32sIIBBH7H")
    for slot in range(16):
        name,size,crc,image_type,blocks,_,*physical=slot_struct.unpack_from(payload,offset)
        rows.append({"slot":slot,"valid":bool(mask&(1<<slot)),"name":name.split(b"\0",1)[0].decode("utf-8","replace"),
                     "size":size,"crc":f"{crc:08x}","type":image_type,"blocks":physical[:blocks]})
        offset+=slot_struct.size
    return rows


def create_app():
    try:
        from fastapi import FastAPI, HTTPException
        from fastapi.responses import FileResponse
    except ImportError as error:
        raise RuntimeError("Studio requires fastapi, uvicorn, pydantic and pyserial") from error

    app=FastAPI(title="LA32 Studio")

    @app.get("/")
    def index(): return FileResponse(STATIC / "index.html")
    @app.get("/api/ports")
    def ports():
        try:
            from serial.tools import list_ports
            return [{"device":p.device,"description":p.description} for p in list_ports.comports()]
        except Exception as e: raise HTTPException(500,str(e))
    @app.post("/api/build/racing")
    def build():
        try:return build_racing()
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/build/selftest")
    def build_test():
        try:return build_selftest()
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/build/generic")
    def build_user_program(req:SourceRequest):
        try:
            with BUILD_LOCK:return build_generic(req.source)
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/run/generic")
    def run_user_program(req:RunSourceRequest):
        try:return run_generic(req.source,req.port)
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/slots")
    def slots(req:PortRequest):
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                _dtr(port);downloader=Downloader(port);downloader.wait_ready(5.0)
                response=downloader.slot_command(FrameType.LIST)
            return parse_directory(response.payload)
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/install")
    def install(req:InstallRequest):
        try:
            image=Path(req.image or BUILD/"racing.la32img").read_bytes()
            with SERIAL_LOCK,_serial(req.port) as port:
                _dtr(port);downloader=Downloader(port);downloader.wait_ready(5.0)
                downloader.transfer_image(image,FrameType.INSTALL,req.slot)
            return {"ok":True}
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/remove")
    def remove(req:SlotRequest):
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                _dtr(port);downloader=Downloader(port);downloader.wait_ready(5.0)
                downloader.slot_command(FrameType.REMOVE,req.slot)
            return {"ok":True}
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/verify")
    def verify(req:SlotRequest):
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                _dtr(port);downloader=Downloader(port);downloader.wait_ready(5.0)
                downloader.slot_command(FrameType.VERIFY,req.slot)
            return {"ok":True}
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/format")
    def format_store(req:PortRequest):
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                _dtr(port);downloader=Downloader(port);downloader.wait_ready(5.0)
                downloader.slot_command(FrameType.FORMAT)
            return {"ok":True}
        except Exception as e:raise HTTPException(500,str(e))
    return app


def run(host="127.0.0.1",port=8765):
    import uvicorn
    uvicorn.run(create_app(),host=host,port=port)
