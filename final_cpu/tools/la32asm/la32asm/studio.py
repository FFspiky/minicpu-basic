from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shlex
import struct
import subprocess
import sys
import threading
import time

from pydantic import BaseModel

from .assembler import Assembler
from .image import Image, ImageType
from .protocol import Downloader, FrameType

FINAL_CPU = Path(__file__).resolve().parents[3]
BUILD = FINAL_CPU / "tools" / "la32asm" / "build"
STATIC = FINAL_CPU / "tools" / "la32asm" / "studio"
SERIAL_LOCK = threading.Lock()
BUILD_LOCK = threading.Lock()
PROGRESS_LOCK = threading.Lock()
COMPILER = os.environ.get(
    "LA32_GCC", "/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc"
)
MONITOR_READY_TIMEOUT = 180.0
TRANSFER_RETRIES = 20
TRANSFER_TIMEOUT = 0.75
# The UART uses a fixed divisor rather than auto-baud, so a long 0x55 train
# provides no calibration benefit.  More importantly, it can fill the 16-byte
# board FIFO while the monitor is scanning NAND after reset.  Keep an opt-in
# diagnostic preamble, but send none during normal Studio operation.
UART_SYNC_BYTES = int(os.environ.get("LA32_UART_SYNC_BYTES", "0"))
SELFTEST_CAPTURE_TIMEOUT = 300.0
VGA_EVENT_PATTERN = re.compile(r"^VGA:(RUNNING|DONE|PASSED|FAILED)\r?\n?", re.MULTILINE)

_PROGRESS = {
    "active": False,
    "operation": "idle",
    "phase": "idle",
    "detail": "等待操作",
    "current": 0,
    "total": 0,
    "bytes_sent": 0,
    "bytes_total": 0,
    "percent": 0.0,
    "started_at": 0.0,
    "updated_at": 0.0,
    "error": "",
}


def _progress_begin(operation: str, detail: str, bytes_total: int = 0) -> None:
    now = time.time()
    with PROGRESS_LOCK:
        _PROGRESS.update({
            "active": True,
            "operation": operation,
            "phase": "connecting",
            "detail": detail,
            "current": 0,
            "total": 0,
            "bytes_sent": 0,
            "bytes_total": bytes_total,
            "percent": 0.0,
            "started_at": now,
            "updated_at": now,
            "error": "",
        })


def _progress_update(
    phase: str,
    detail: str,
    current: int = 0,
    total: int = 0,
    bytes_sent: int = 0,
    bytes_total: int = 0,
) -> None:
    with PROGRESS_LOCK:
        values = {
            "phase": phase,
            "detail": detail,
            "updated_at": time.time(),
        }
        if total:
            values.update({
                "current": current,
                "total": total,
                "percent": 100.0 * current / total,
            })
        if bytes_total:
            values.update({"bytes_sent": bytes_sent, "bytes_total": bytes_total})
        _PROGRESS.update(values)


def _progress_finish(detail: str, error: str = "") -> None:
    with PROGRESS_LOCK:
        _PROGRESS.update({
            "active": False,
            "phase": "error" if error else "complete",
            "detail": detail,
            "percent": _PROGRESS["percent"] if error else 100.0,
            "updated_at": time.time(),
            "error": error,
        })


def _progress_snapshot() -> dict:
    with PROGRESS_LOCK:
        result = dict(_PROGRESS)
    result["elapsed"] = max(0.0, time.time() - result["started_at"]) if result["started_at"] else 0.0
    return result


def _transfer_progress(operation: FrameType):
    def update(phase, current, total, bytes_sent, bytes_total):
        if phase == "prepare":
            detail = "板端已连接，正在建立镜像传输"
        elif phase == "transfer":
            detail = f"正在发送并确认数据帧 {current}/{total}"
        elif phase == "commit" and operation == FrameType.INSTALL:
            detail = "镜像发送完成，正在擦除、写入并校验NAND"
        elif phase == "commit":
            detail = "镜像发送完成，正在校验并启动程序"
        else:
            detail = "板端已确认镜像"
        _progress_update(phase, detail, current, total, bytes_sent, bytes_total)
    return update


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


class RunImageRequest(BaseModel):
    image: str
    port: str


def _serial(port_name: str):
    try:
        import serial
    except ImportError as error:
        raise RuntimeError("pyserial is required") from error
    return serial.Serial(port_name, 115200, timeout=0.5)


def _break_reset(port):
    """Request a warm reset by holding the UART receive line in BREAK."""
    # The board's USB-UART bridge did not reliably propagate a 50 ms BREAK.
    # One second is verified on the physical board and this function is
    # called at most once, only after a non-mutating monitor probe times out.
    port.send_break(duration=1.0)


def _sync_uart(port):
    """Optionally send a diagnostic 0x55 preamble; fixed-baud mode needs none."""
    if UART_SYNC_BYTES:
        port.write(b"\x55" * UART_SYNC_BYTES)
        port.flush()


def _probe_monitor(port, timeout=0.2) -> Downloader | None:
    """Probe with a short, non-mutating invalid-slot VERIFY/NACK exchange."""
    probe = Downloader(port, retries=1, timeout=timeout)
    try:
        probe.request(
            FrameType.VERIFY, bytes([0xFF]), timeout=timeout, retries=1
        )
        return probe
    except RuntimeError:
        # Slot 255 is invalid by construction; its well-formed NACK proves the
        # monitor is alive without requesting the 1072-byte directory frame.
        return probe
    except (TimeoutError, ValueError):
        return None


def _boot_monitor(port) -> Downloader:
    """Attach to a running menu or a monitor reset at any time in the window."""
    port.reset_input_buffer()
    _sync_uart(port)
    _progress_update("connecting", "正在探测Boot Monitor；若应用仍在运行，请复位一次")

    # READY is emitted only once during monitor startup.  If Studio opens the
    # COM port after the VGA menu is already visible, that frame is gone even
    # though the monitor is ready.  LIST is a harmless liveness probe and the
    # v1 monitor echoes our sequence number without keeping sequence state.
    probe = _probe_monitor(port)
    if probe is not None:
        # The probe intentionally uses one short attempt.  Never reuse that
        # diagnostic Downloader for an image transfer: doing so disabled the
        # protocol's retries and made installs fail at a random frame number.
        _progress_update("connected", "Boot Monitor已响应")
        return Downloader(
            port, retries=TRANSFER_RETRIES, timeout=TRANSFER_TIMEOUT
        )

    # A failed probe normally means an application owns the CPU.  Issue one
    # (and only one) warm reset, then accept either its READY frame or a later
    # monitor probe.  Never repeat BREAK inside the wait loop: a monitor that
    # is legitimately scanning NAND must be allowed to finish initialization.
    _progress_update("reset", "Boot Monitor未响应，正在执行一次UART BREAK复位")
    _break_reset(port)
    deadline = time.monotonic() + MONITOR_READY_TIMEOUT
    downloader = Downloader(port, retries=1, timeout=0.25)
    while time.monotonic() < deadline:
        try:
            downloader.wait_ready(min(0.25, deadline - time.monotonic()))
            _progress_update("connected", "已收到Boot Monitor READY")
            return Downloader(
                port, retries=TRANSFER_RETRIES, timeout=TRANSFER_TIMEOUT
            )
        except TimeoutError:
            pass
        probe = _probe_monitor(port, timeout=0.25)
        if probe is not None:
            _progress_update("connected", "Boot Monitor已响应")
            return Downloader(
                port, retries=TRANSFER_RETRIES, timeout=TRANSFER_TIMEOUT
            )
    raise TimeoutError(
        "board did not enter the boot monitor; reset once only if an application is running"
    )


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
    command = " ".join(shlex.quote(part) for part in arguments)
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
    _compile_c(source, generated)
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


def _decode_runtime_output(payload: bytes) -> tuple[str, list[str]]:
    decoded = payload.decode("utf-8", "replace")
    events = VGA_EVENT_PATTERN.findall(decoded)
    return VGA_EVENT_PATTERN.sub("", decoded), events


def run_image(image_path: str | Path, port_name: str) -> dict:
    image = Path(image_path).read_bytes()
    image_type = Image.unpack(image).image_type
    output = bytearray()
    completed = False
    terminal_status = ""
    _progress_begin("run", "正在连接板端运行环境", len(image))
    try:
        with SERIAL_LOCK, _serial(port_name) as port:
            downloader = _boot_monitor(port)
            downloader.transfer_image(
                image,
                FrameType.RUN_TEMPORARY,
                progress=_transfer_progress(FrameType.RUN_TEMPORARY),
            )
            _progress_update("output", "程序已启动，正在采集UART输出")
            deadline = time.monotonic() + (
                SELFTEST_CAPTURE_TIMEOUT if image_type == ImageType.SELFTEST else 5.0
            )
            while time.monotonic() < deadline:
                chunk = port.read(1)
                if not chunk:
                    continue
                if chunk == b"\x04":
                    completed = True
                    terminal_status = "DONE"
                    break
                output.extend(chunk)
                if image_type == ImageType.SELFTEST:
                    if b"VGA:PASSED\r\n" in output:
                        completed = True
                        terminal_status = "PASSED"
                        break
                    if b"VGA:FAILED\r\n" in output:
                        completed = True
                        terminal_status = "FAILED"
                        break
                if len(output) >= 64 * 1024:
                    break
    except Exception as error:
        _progress_finish("运行失败", str(error))
        raise
    program_output, events = _decode_runtime_output(bytes(output))
    if not events:
        events = ["RUNNING"]
    if terminal_status and terminal_status not in events:
        events.append(terminal_status)
    result = {
        "output": program_output,
        "completed": completed,
        "vga_events": events,
        "vga_status": terminal_status or events[-1],
    }
    if image_type == ImageType.SELFTEST:
        result["passed"] = terminal_status == "PASSED"
    if not completed:
        result["output"] += "\n[Studio: output capture timed out or exceeded 64 KiB]"
    _progress_finish("程序执行完成" if completed else "程序已启动，输出采集超时")
    return result


def run_generic(source_text: str, port_name: str) -> dict:
    with BUILD_LOCK:
        report = build_generic(source_text)
    report.update(run_image(report["image"], port_name))
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


DIRECTORY_HEADER = struct.Struct("<IIHH")
DIRECTORY_SLOT = struct.Struct("<32sIIBBH7H")
UI_STATUS = struct.Struct("<7I")


def _parse_directory_row(slot: int, mask: int, payload: bytes, offset: int) -> dict:
    name,size,crc,image_type,blocks,_,*physical=DIRECTORY_SLOT.unpack_from(payload,offset)
    return {"slot":slot,"valid":bool(mask&(1<<slot)),
            "name":name.split(b"\0",1)[0].decode("utf-8","replace"),
            "size":size,"crc":f"{crc:08x}","type":image_type,
            "blocks":physical[:blocks]}


def parse_directory(payload: bytes) -> list[dict]:
    if len(payload) < 1072:
        raise ValueError("board directory response is truncated")
    _, _, mask, _ = DIRECTORY_HEADER.unpack_from(payload)
    rows=[]; offset=DIRECTORY_HEADER.size
    for slot in range(16):
        rows.append(_parse_directory_row(slot,mask,payload,offset))
        offset+=DIRECTORY_SLOT.size
    return rows


def read_directory_slots(downloader: Downloader) -> list[dict]:
    """Read the directory as sixteen retryable 70-byte responses."""
    rows=[]; identity=None
    expected_size=DIRECTORY_HEADER.size+DIRECTORY_SLOT.size
    for requested_slot in range(16):
        response=downloader.slot_command(FrameType.LIST,requested_slot)
        if len(response.payload)!=expected_size:
            raise ValueError(
                f"board slot {requested_slot} response has {len(response.payload)} bytes; "
                f"expected {expected_size}"
            )
        magic,generation,mask,returned_slot=DIRECTORY_HEADER.unpack_from(response.payload)
        if returned_slot!=requested_slot:
            raise ValueError(
                f"board returned slot {returned_slot} while reading slot {requested_slot}"
            )
        current_identity=(magic,generation,mask)
        if identity is None: identity=current_identity
        elif current_identity!=identity:
            raise ValueError("board directory changed while it was being read")
        rows.append(_parse_directory_row(
            returned_slot,mask,response.payload,DIRECTORY_HEADER.size
        ))
    return rows


def read_ui_status(downloader: Downloader) -> dict:
    response=downloader.request(FrameType.UI_STATUS)
    if len(response.payload)!=UI_STATUS.size:
        raise ValueError(
            f"board UI status has {len(response.payload)} bytes; "
            f"expected {UI_STATUS.size}"
        )
    version,mode,active,selected,valid,status,end_pc=UI_STATUS.unpack(response.payload)
    screens=("PROGRAM MENU","RACING GAME","PIPELINE EXP16","GENERIC PROGRAM")
    return {"version":version,"system_mode":mode,
            "screen":screens[mode] if mode<len(screens) else "UNKNOWN",
            "active_slot":active,"selected_slot":selected,
            "selected_valid":selected<16 and bool(valid&(1<<selected)),
            "valid_mask":f"0x{valid:04x}","menu_status":status,
            "status_text":{0:"READY",3:"RUNNING",4:"DONE",0xff:"ERROR"}.get(
                status,"LOADING"
            ),
            "dynamic_end_pc":f"0x{end_pc:08x}"}


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
    @app.get("/api/progress")
    def progress(): return _progress_snapshot()
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
    @app.post("/api/run/image")
    def run_built_image(req:RunImageRequest):
        try:return run_image(req.image,req.port)
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/slots")
    def slots(req:PortRequest):
        _progress_begin("list", "正在连接板端并读取NAND目录")
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                downloader=_boot_monitor(port)
                _progress_update("directory", "正在接收NAND程序目录")
                result=read_directory_slots(downloader)
            _progress_finish("NAND目录读取完成")
            return result
        except Exception as e:
            _progress_finish("读取目录失败",str(e));raise HTTPException(500,str(e))
    @app.post("/api/status")
    def ui_status(req:PortRequest):
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                downloader=_boot_monitor(port)
                return read_ui_status(downloader)
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/install")
    def install(req:InstallRequest):
        image=Path(req.image or BUILD/"racing.la32img").read_bytes()
        _progress_begin("install",f"正在连接板端并准备安装到槽{req.slot}",len(image))
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                downloader=_boot_monitor(port)
                downloader.transfer_image(
                    image,FrameType.INSTALL,req.slot,
                    progress=_transfer_progress(FrameType.INSTALL),
                )
                _progress_update("directory","安装完成，正在刷新NAND目录")
                slots=read_directory_slots(downloader)
            result={"ok":True,"slots":slots}
            _progress_finish(f"程序已安装到槽{req.slot}")
            return result
        except Exception as e:
            _progress_finish("安装失败",str(e));raise HTTPException(500,str(e))
    @app.post("/api/remove")
    def remove(req:SlotRequest):
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                downloader=_boot_monitor(port)
                downloader.slot_command(FrameType.REMOVE,req.slot)
                slots=read_directory_slots(downloader)
            return {"ok":True,"slots":slots}
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/verify")
    def verify(req:SlotRequest):
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                downloader=_boot_monitor(port)
                downloader.slot_command(FrameType.VERIFY,req.slot)
            return {"ok":True}
        except Exception as e:raise HTTPException(500,str(e))
    @app.post("/api/format")
    def format_store(req:PortRequest):
        _progress_begin("format","正在连接板端并初始化NAND程序盘")
        try:
            with SERIAL_LOCK,_serial(req.port) as port:
                downloader=_boot_monitor(port)
                _progress_update("commit","正在擦除并写入双副本目录")
                downloader.slot_command(FrameType.FORMAT)
                _progress_update("directory","正在读取初始化后的目录")
                slots=read_directory_slots(downloader)
            result={"ok":True,"slots":slots}
            _progress_finish("程序盘初始化完成")
            return result
        except Exception as e:
            _progress_finish("初始化失败",str(e));raise HTTPException(500,str(e))
    return app


def run(host="127.0.0.1",port=8765):
    import uvicorn
    uvicorn.run(create_app(),host=host,port=port)
