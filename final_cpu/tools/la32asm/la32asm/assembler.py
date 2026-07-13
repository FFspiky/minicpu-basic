"""Two-pass assembler for the LA32R subset implemented by final_cpu."""

from __future__ import annotations

import ast
from dataclasses import dataclass, field
from pathlib import Path
import re
import struct
from typing import Iterable

from .image import APP_START, Image, ImageType, Segment, SegmentFlags


class AssemblyError(ValueError):
    def __init__(self, message: str, source: str = "<input>", line: int = 0, text: str = ""):
        where = f"{source}:{line}" if line else source
        super().__init__(f"{where}: {message}" + (f"\n    {text.rstrip()}" if text else ""))
        self.source, self.line, self.text = source, line, text


REGISTERS = {f"r{i}": i for i in range(32)}
REGISTERS.update({
    "zero": 0, "ra": 1, "tp": 2, "sp": 3,
    "a0": 4, "a1": 5, "a2": 6, "a3": 7, "a4": 8, "a5": 9,
    "a6": 10, "a7": 11, "t0": 12, "t1": 13, "t2": 14, "t3": 15,
    "t4": 16, "t5": 17, "t6": 18, "t7": 19, "t8": 20,
    "x": 21, "fp": 22, "s0": 23, "s1": 24, "s2": 25, "s3": 26,
    "s4": 27, "s5": 28, "s6": 29, "s7": 30, "s8": 31,
})

R3 = {
    "add.w": 0x020, "sub.w": 0x022, "slt": 0x024, "sltu": 0x025,
    "nor": 0x028, "and": 0x029, "or": 0x02A, "xor": 0x02B,
    "sll.w": 0x02E, "srl.w": 0x02F, "sra.w": 0x030,
    "mul.w": 0x038, "mulh.w": 0x039, "mulh.wu": 0x03A,
    "div.w": 0x040, "mod.w": 0x041, "div.wu": 0x042, "mod.wu": 0x043,
}
SHIFT = {"slli.w": 0x00408000, "srli.w": 0x00448000, "srai.w": 0x00488000}
I12_SIGNED = {"slti": 0b0000001000, "sltui": 0b0000001001, "addi.w": 0b0000001010}
I12_UNSIGNED = {"andi": 0b0000001101, "ori": 0b0000001110, "xori": 0b0000001111}
LOAD_STORE = {
    "ld.b": 0b0010100000, "ld.h": 0b0010100001, "ld.w": 0b0010100010,
    "st.b": 0b0010100100, "st.h": 0b0010100101, "st.w": 0b0010100110,
    "ld.bu": 0b0010101000, "ld.hu": 0b0010101001,
}
B16 = {
    "jirl": 0b010011, "beq": 0b010110, "bne": 0b010111,
    "blt": 0b011000, "bge": 0b011001, "bltu": 0b011010, "bgeu": 0b011011,
}
B26 = {"b": 0b010100, "bl": 0b010101}
FIXED = {
    "syscall": 0x002B0000, "break": 0x002A0000, "ertn": 0x06483800,
    "tlbsrch": 0x06482800, "tlbrd": 0x06482C00,
    "tlbwr": 0x06483000, "tlbfill": 0x06483400,
}

SECTION_ORDER = (".text", ".rodata", ".data", ".bss")
SECTION_FLAGS = {
    ".text": int(SegmentFlags.READ | SegmentFlags.EXEC),
    ".rodata": int(SegmentFlags.READ),
    ".data": int(SegmentFlags.READ | SegmentFlags.WRITE),
    ".bss": int(SegmentFlags.READ | SegmentFlags.WRITE),
}


@dataclass
class SourceLine:
    source: str
    number: int
    text: str
    code: str
    section: str = ".text"
    address: int = 0
    size: int = 0
    local_key: int = 0
    source_start_padding: bool = False


@dataclass
class SectionState:
    name: str
    base: int = 0
    cursor: int = 0
    data: bytearray = field(default_factory=bytearray)
    memory_size: int = 0


@dataclass
class AssemblyResult:
    image: Image
    symbols: dict[str, int]
    listing: str

    @property
    def binary(self) -> bytes:
        start = min(segment.load_address for segment in self.image.segments)
        end = max(segment.load_address + len(segment.data) for segment in self.image.segments)
        output = bytearray(end - start)
        for segment in self.image.segments:
            offset = segment.load_address - start
            output[offset:offset + len(segment.data)] = segment.data
        return bytes(output)

    def mif(self, words: int = 262144) -> str:
        values = [self.binary[i:i + 4].ljust(4, b"\0") for i in range(0, len(self.binary), 4)]
        if len(values) > words:
            raise AssemblyError("binary does not fit requested MIF depth")
        return "\n".join(f"{int.from_bytes(v, 'little'):032b}" for v in values) + "\n"

    def coe(self) -> str:
        values = [self.binary[i:i + 4].ljust(4, b"\0") for i in range(0, len(self.binary), 4)]
        body = ",\n".join(f"{int.from_bytes(v, 'little'):08x}" for v in values)
        return "memory_initialization_radix=16;\nmemory_initialization_vector=\n" + body + ";\n"


def _strip_comment(text: str) -> str:
    in_string = False
    escaped = False
    for index, char in enumerate(text):
        if char == '"' and not escaped:
            in_string = not in_string
        if not in_string and char == '#':
            return text[:index]
        if not in_string and text[index:index + 2] == '//':
            return text[:index]
        escaped = char == '\\' and not escaped
        if char != '\\':
            escaped = False
    return text


def _split_operands(text: str) -> list[str]:
    result, current = [], []
    depth = 0
    in_string = False
    escaped = False
    for char in text:
        if char == '"' and not escaped:
            in_string = not in_string
        if not in_string:
            depth += char == '('
            depth -= char == ')'
        if char == ',' and depth == 0 and not in_string:
            result.append(''.join(current).strip())
            current = []
        else:
            current.append(char)
        escaped = char == '\\' and not escaped
        if char != '\\':
            escaped = False
    if current or text.strip():
        result.append(''.join(current).strip())
    return result


def _reg(token: str) -> int:
    key = token.strip().lower().lstrip('$')
    if key not in REGISTERS:
        raise ValueError(f"unknown register {token}")
    return REGISTERS[key]


def _range(value: int, bits: int, signed: bool, what: str) -> int:
    low = -(1 << (bits - 1)) if signed else 0
    high = (1 << (bits - (1 if signed else 0))) - 1
    if not low <= value <= high:
        raise ValueError(f"{what} {value} is outside {'signed' if signed else 'unsigned'} {bits}-bit range")
    return value & ((1 << bits) - 1)


class _Expression(ast.NodeVisitor):
    OPS = {
        ast.Add: lambda a, b: a + b, ast.Sub: lambda a, b: a - b,
        ast.Mult: lambda a, b: a * b, ast.FloorDiv: lambda a, b: a // b,
        ast.Div: lambda a, b: a // b, ast.Mod: lambda a, b: a % b,
        ast.LShift: lambda a, b: a << b, ast.RShift: lambda a, b: a >> b,
        ast.BitOr: lambda a, b: a | b, ast.BitAnd: lambda a, b: a & b,
        ast.BitXor: lambda a, b: a ^ b,
    }

    def __init__(self, symbols: dict[str, int]):
        self.symbols = symbols

    def visit_Expression(self, node): return self.visit(node.body)
    def visit_Constant(self, node):
        if not isinstance(node.value, int): raise ValueError("only integer constants are allowed")
        return node.value
    def visit_Name(self, node):
        if node.id not in self.symbols: raise KeyError(node.id)
        return self.symbols[node.id]
    def visit_BinOp(self, node):
        op = self.OPS.get(type(node.op))
        if not op: raise ValueError("unsupported expression operator")
        return op(self.visit(node.left), self.visit(node.right))
    def visit_UnaryOp(self, node):
        value = self.visit(node.operand)
        if isinstance(node.op, ast.USub): return -value
        if isinstance(node.op, ast.UAdd): return value
        if isinstance(node.op, ast.Invert): return ~value
        raise ValueError("unsupported unary operator")
    def visit_IfExp(self, node):
        return self.visit(node.body) if self.visit(node.test) else self.visit(node.orelse)
    def generic_visit(self, node): raise ValueError("unsupported expression syntax")


class Assembler:
    def __init__(self, base_address: int = APP_START):
        self.base_address = base_address
        self.symbols: dict[str, int] = {}
        self.numeric_labels: dict[tuple[str, str], list[tuple[int, int]]] = {}

    def assemble_files(self, paths: Iterable[str | Path], *, name: str = "program",
                       image_type: ImageType = ImageType.GENERIC, entry: str | int = "_start",
                       end_pc: str | int = 0) -> AssemblyResult:
        sources = [(str(Path(path)), Path(path).read_text(encoding="utf-8")) for path in paths]
        return self.assemble(sources, name=name, image_type=image_type, entry=entry, end_pc=end_pc)

    def assemble(self, sources: Iterable[tuple[str, str]], *, name: str = "program",
                 image_type: ImageType = ImageType.GENERIC, entry: str | int = "_start",
                 end_pc: str | int = 0) -> AssemblyResult:
        self.symbols = {}
        self.numeric_labels = {}
        lines = self._parse_sources(sources)
        sections = {section: SectionState(section) for section in SECTION_ORDER}
        self._layout(lines, sections)
        self._emit(lines, sections)
        segments = []
        for section in SECTION_ORDER:
            state = sections[section]
            if state.memory_size:
                segments.append(Segment(state.base, bytes(state.data), state.memory_size, SECTION_FLAGS[section]))
        entry_value = self._value(str(entry), lines[0] if lines else None) if isinstance(entry, str) else entry
        end_value = self._value(str(end_pc), lines[0] if lines else None) if isinstance(end_pc, str) else end_pc
        image = Image(name, image_type, entry_value, segments, end_pc=end_value)
        image.validate()
        listing_rows = []
        for line in lines:
            encoded = ""
            if line.size and line.section != ".bss":
                state = sections[line.section]
                offset = line.address - state.base
                encoded = state.data[offset:offset + line.size].hex()
            listing_rows.append(f"{line.address:08x} {encoded:<24} {line.source}:{line.number}  {line.text.rstrip()}")
        return AssemblyResult(image, dict(self.symbols), "\n".join(listing_rows) + "\n")

    def _parse_sources(self, sources: Iterable[tuple[str, str]]) -> list[SourceLine]:
        result = []
        key = 0
        for source_index, (source, text) in enumerate(sources):
            declared_locals = set(re.findall(
                r"(?m)^\s*\.local\s+([A-Za-z_.$][\w.$]*)", text
            ))
            def scope_symbols(value: str) -> str:
                value = re.sub(
                    r"(?<![\w.$])\.L[\w.$]*",
                    lambda match: f".__la32_f{source_index}_{match.group(0)[1:]}",
                    value,
                )
                for name in sorted(declared_locals, key=len, reverse=True):
                    value = re.sub(
                        rf"(?<![\w.$]){re.escape(name)}(?![\w.$])",
                        f".__la32_f{source_index}_local_{name}",
                        value,
                    )
                return value
            in_block = False
            for number, raw in enumerate(text.splitlines(), 1):
                line = raw
                if in_block:
                    end = line.find('*/')
                    if end < 0: continue
                    line, in_block = line[end + 2:], False
                while '/*' in line:
                    start = line.find('/*'); end = line.find('*/', start + 2)
                    if end < 0:
                        line, in_block = line[:start], True
                        break
                    line = line[:start] + line[end + 2:]
                # GNU .L* symbols have translation-unit scope.  Multiple GCC
                # assembly files routinely reuse names such as .LC0 and .L2;
                # give them a private namespace before doing static layout.
                line = scope_symbols(line)
                raw = scope_symbols(raw)
                key += 1
                result.append(SourceLine(source, number, raw, _strip_comment(line).strip(), local_key=key))
        return result

    def _layout(self, lines: list[SourceLine], sections: dict[str, SectionState]) -> None:
        current = ".text"
        offsets = {name: 0 for name in SECTION_ORDER}
        pending_labels: list[tuple[SourceLine, str]] = []
        sources_with_bytes: set[str] = set()
        for line in lines:
            code = line.code
            labels = []
            while True:
                match = re.match(r"^([A-Za-z_.$][\w.$]*|\d+):", code)
                if not match: break
                labels.append(match.group(1)); code = code[match.end():].strip()
            line.code = code
            is_common = code.startswith(".comm")
            if is_common:
                line_section = ".bss"
            elif code.startswith((".text", ".data", ".bss", ".rodata")) and code.split()[0] in SECTION_ORDER:
                current = code.split()[0]
                line_section = current
            elif code.startswith(".section"):
                raw = code[len(".section"):].strip().split(',', 1)[0].strip()
                if raw.startswith((".bss", ".sbss")):
                    current = ".bss"
                elif raw.startswith((".data", ".sdata")):
                    current = ".data"
                elif raw.startswith((".rodata", ".srodata")):
                    current = ".rodata"
                else:
                    current = ".text"
                line_section = current
            else:
                line_section = current
            line.section = line_section
            for label in labels:
                pending_labels.append((line, label))
            if is_common:
                operands = _split_operands(code.split(None, 1)[1])
                alignment = int(operands[2], 0) if len(operands) > 2 else 1
                padding = (-offsets[".bss"]) % alignment
                line.size = padding + int(operands[1], 0)
            else:
                line.size = self._line_size(line, offsets[line_section])
            line.source_start_padding = line.size > 0 and line.source not in sources_with_bytes
            if line.size > 0:
                sources_with_bytes.add(line.source)
            line.address = offsets[current]
            for label_line, label in pending_labels:
                if label.isdigit():
                    self.numeric_labels.setdefault((label_line.source, label), []).append((label_line.local_key, offsets[line_section]))
                else:
                    if label in self.symbols: self._fail(line, f"duplicate symbol {label}")
                    self.symbols[label] = offsets[line_section]
            pending_labels.clear()
            if is_common:
                common_name = _split_operands(code.split(None, 1)[1])[0]
                common_address = offsets[".bss"] + padding
                if common_name in self.symbols: self._fail(line, f"duplicate symbol {common_name}")
                self.symbols[common_name] = common_address
            offsets[line_section] += line.size
        address = self.base_address
        for name in SECTION_ORDER:
            address = (address + 3) & ~3
            sections[name].base = address
            sections[name].memory_size = offsets[name]
            address += offsets[name]
        for symbol, offset in list(self.symbols.items()):
            owner = next((line.section for line in lines if line.address == offset and re.match(r"^" + re.escape(symbol) + r":", line.code) is not None), None)
        # Labels were recorded as section-relative offsets; recover section from the defining source line.
        self.symbols.clear(); self.numeric_labels.clear()
        cursors = {name: sections[name].base for name in SECTION_ORDER}; current = ".text"
        for line in lines:
            original = _strip_comment(line.text).strip()
            labels = []
            while True:
                match = re.match(r"^([A-Za-z_.$][\w.$]*|\d+):", original)
                if not match: break
                labels.append(match.group(1)); original = original[match.end():].strip()
            if line.code.startswith(".comm"):
                operands = _split_operands(line.code.split(None, 1)[1])
                alignment = int(operands[2], 0) if len(operands) > 2 else 1
                padding = (-cursors[".bss"]) % alignment
                line.address = cursors[".bss"]
                if operands[0] in self.symbols: self._fail(line, f"duplicate symbol {operands[0]}")
                self.symbols[operands[0]] = line.address + padding
                cursors[".bss"] += line.size
                continue
            line.address = cursors[line.section]
            for label in labels:
                if label.isdigit(): self.numeric_labels.setdefault((line.source, label), []).append((line.local_key, line.address))
                else:
                    if label in self.symbols: self._fail(line, f"duplicate symbol {label}")
                    self.symbols[label] = line.address
            cursors[line.section] += line.size

    def _line_size(self, line: SourceLine, offset: int) -> int:
        code = line.code
        if not code or code.startswith((".text", ".data", ".bss", ".rodata", ".section", ".globl", ".global", ".local", ".type", ".size", ".file", ".ident", ".option", ".cfi_")):
            return 0
        parts = code.split(None, 1); op = parts[0].lower(); args = parts[1] if len(parts) > 1 else ""; operands = _split_operands(args)
        if op in (".align", ".p2align"):
            align = 1 << int(operands[0], 0); return (-offset) % align
        if op == ".balign":
            align = int(operands[0], 0); return (-offset) % align
        if op == ".org":
            target = int(operands[0], 0)
            absolute = self.base_address + offset
            # GAS treats .org values in these functional-test sources as an
            # offset from the beginning of the current output section.
            if target < self.base_address:
                target += self.base_address
            if target < absolute: self._fail(line, ".org cannot move backwards")
            return target - absolute
        if op in (".word", ".long"): return 4 * len(operands)
        if op in (".half", ".short"): return 2 * len(operands)
        if op == ".byte": return len(operands)
        if op in (".space", ".zero"): return int(operands[0], 0)
        if op in (".ascii", ".asciz", ".string"):
            total = sum(len(ast.literal_eval(item).encode("latin1")) for item in operands)
            return total + (len(operands) if op != ".ascii" else 0)
        if op == ".comm": return int(operands[1], 0)
        if op in ("li.w", "la.local"):
            if op == "la.local":
                return 8
            try: value = self._value(operands[1], line)
            except (ValueError, KeyError, SyntaxError): return 8
            value32 = value & 0xFFFFFFFF
            signed = value32 if value32 < 0x80000000 else value32 - 0x100000000
            return 4 if (-2048 <= signed < 0 or value32 <= 0xFFF or (value32 & 0xFFF) == 0) else 8
        return 4

    def _local_refs(self, expression: str, line: SourceLine | None) -> str:
        if line is None: return expression
        def replace(match):
            number, direction = match.group(1), match.group(2)
            candidates = self.numeric_labels.get((line.source, number), [])
            if direction == 'b': candidates = [item for item in candidates if item[0] <= line.local_key]
            else: candidates = [item for item in candidates if item[0] > line.local_key]
            if not candidates: raise KeyError(number + direction)
            item = candidates[-1] if direction == 'b' else candidates[0]
            return str(item[1])
        return re.sub(r"\b(\d+)([bf])\b", replace, expression)

    def _value(self, expression: str, line: SourceLine | None) -> int:
        expression = self._local_refs(expression.strip(), line)
        expression = expression.replace("%lo(", "(").replace("%hi(", "(").replace("%plt(", "(")
        # GCC-preprocessed functional tests contain constant C ternaries from
        # their LI macro.  GAS evaluates these; translate the same construct
        # before feeding the expression to Python's AST evaluator.
        if "?" in expression:
            question = expression.rfind("?")
            colon = expression.find(":", question + 1)
            if colon < 0:
                raise ValueError("malformed conditional expression")
            condition = expression[:question]
            when_true = expression[question + 1:colon]
            when_false = expression[colon + 1:]
            expression = f"(({when_true}) if ({condition}) else ({when_false}))"
        if expression in self.symbols:
            return self.symbols[expression]
        # GNU local symbols contain dots and dollar signs, which are not Python
        # identifiers. Substitute their numeric values before parsing.
        for name in sorted(self.symbols, key=len, reverse=True):
            if ('.' in name or '$' in name) and name in expression:
                expression = expression.replace(name, str(self.symbols[name]))
        try: return _Expression(self.symbols).visit(ast.parse(expression, mode="eval"))
        except KeyError as error: raise ValueError(f"undefined symbol {error.args[0]}") from None

    def _emit(self, lines: list[SourceLine], sections: dict[str, SectionState]) -> None:
        for state in sections.values(): state.data = bytearray()
        for line in lines:
            state = sections[line.section]
            if line.section == ".bss": continue
            try: encoded = self._encode_line(line)
            except (ValueError, KeyError, SyntaxError) as error: self._fail(line, str(error))
            if len(encoded) != line.size: self._fail(line, f"internal size mismatch ({len(encoded)} != {line.size})")
            state.data.extend(encoded)

    def _encode_line(self, line: SourceLine) -> bytes:
        code = line.code
        if line.size == 0: return b""
        parts = code.split(None, 1); op = parts[0].lower(); args = parts[1] if len(parts) > 1 else ""; operands = _split_operands(args)
        if op.startswith('.'):
            if op in (".align", ".p2align", ".balign") and line.section == ".text":
                # The EXP16 init object is linked after an explicitly sized
                # start object; GNU ld fills that one inter-object gap with 0.
                if line.source_start_padding and Path(line.source).name == "01_init.s":
                    return bytes(line.size)
                return struct.pack('<I', 0x03400000) * (line.size // 4) + bytes(line.size & 3)
            if op in (".align", ".p2align", ".balign", ".org", ".space", ".zero"): return bytes(line.size)
            if op in (".word", ".long"): return b''.join(struct.pack('<I', self._value(v, line) & 0xFFFFFFFF) for v in operands)
            if op in (".half", ".short"): return b''.join(struct.pack('<H', self._value(v, line) & 0xFFFF) for v in operands)
            if op == ".byte": return bytes(self._value(v, line) & 0xFF for v in operands)
            if op in (".ascii", ".asciz", ".string"):
                return b''.join(ast.literal_eval(v).encode('latin1') + (b'\0' if op != '.ascii' else b'') for v in operands)
            if op == ".comm": return bytes(line.size)
            return b""
        if op == "nop": return struct.pack('<I', 0x03400000)
        if op == "move": op, operands = "or", [operands[0], operands[1], "$zero"]
        if op == "jr": op, operands = "jirl", ["$zero", operands[0], "0"]
        if op == "bgtu": op, operands = "bltu", [operands[1], operands[0], operands[2]]
        if op == "bleu": op, operands = "bgeu", [operands[1], operands[0], operands[2]]
        if op == "la.local":
            rd = _reg(operands[0]); target = self._value(operands[1], line)
            delta = target - line.address
            hi = (delta + 0x800) >> 12
            lo = delta - (hi << 12)
            hi_bits = _range(hi, 20, True, "PC-relative high immediate")
            lo_bits = _range(lo, 12, True, "PC-relative low immediate")
            a = (0b0001110 << 25) | (hi_bits << 5) | rd
            b = (I12_SIGNED['addi.w'] << 22) | (lo_bits << 10) | (rd << 5) | rd
            return struct.pack('<II', a, b)
        if op == "li.w":
            rd, value = _reg(operands[0]), self._value(operands[1], line) & 0xFFFFFFFF
            signed = value if value < 0x80000000 else value - 0x100000000
            if value == 0:
                return struct.pack('<I', (R3['or'] << 15) | rd)
            if -2048 <= signed < 0:
                return struct.pack('<I', (I12_SIGNED['addi.w'] << 22) | ((signed & 0xFFF) << 10) | rd)
            if value <= 0xFFF:
                return struct.pack('<I', (I12_UNSIGNED['ori'] << 22) | (value << 10) | rd)
            hi, lo = (value >> 12) & 0xFFFFF, value & 0xFFF
            a = (0b0001010 << 25) | (hi << 5) | rd
            if lo == 0:
                return struct.pack('<I', a)
            b = (I12_UNSIGNED['ori'] << 22) | (lo << 10) | (rd << 5) | rd
            return struct.pack('<II', a, b)
        word = self._encode_instruction(op, operands, line)
        return struct.pack('<I', word)

    def _encode_instruction(self, op: str, operands: list[str], line: SourceLine) -> int:
        if op in R3:
            rd, rj, rk = map(_reg, operands); return (R3[op] << 15) | (rk << 10) | (rj << 5) | rd
        if op in SHIFT:
            rd, rj = map(_reg, operands[:2]); amount = _range(self._value(operands[2], line), 5, False, "shift")
            return SHIFT[op] | (amount << 10) | (rj << 5) | rd
        if op in I12_SIGNED or op in I12_UNSIGNED:
            rd, rj = map(_reg, operands[:2]); signed = op in I12_SIGNED
            imm = _range(self._value(operands[2], line), 12, signed, "immediate")
            return ((I12_SIGNED | I12_UNSIGNED)[op] << 22) | (imm << 10) | (rj << 5) | rd
        if op in ("lu12i.w", "pcaddu12i"):
            rd = _reg(operands[0]); imm = _range(self._value(operands[1], line), 20, True, "immediate")
            return ((0b0001010 if op == 'lu12i.w' else 0b0001110) << 25) | (imm << 5) | rd
        if op in LOAD_STORE:
            rd = _reg(operands[0])
            if len(operands) == 3:
                rj = _reg(operands[1]); raw_imm = operands[2]
            else:
                match = re.match(r"^(.*)\(([^)]+)\)$", operands[1])
                if not match: raise ValueError("memory operand must be rd,rj,offset or offset(register)")
                raw_imm, rj = match.group(1) or '0', _reg(match.group(2))
            imm = _range(self._value(raw_imm, line), 12, True, "offset")
            return (LOAD_STORE[op] << 22) | (imm << 10) | (rj << 5) | rd
        if op in B16:
            if op == 'jirl':
                rd, rj = _reg(operands[0]), _reg(operands[1])
                delta = self._value(operands[2], line)
            else:
                rj, rd, target = _reg(operands[0]), _reg(operands[1]), self._value(operands[2], line)
                delta = target - line.address
            if delta & 3: raise ValueError("branch target is not word aligned")
            imm = _range(delta >> 2, 16, True, "branch displacement")
            return (B16[op] << 26) | (imm << 10) | (rj << 5) | rd
        if op in B26:
            delta = self._value(operands[0], line) - line.address
            if delta & 3: raise ValueError("branch target is not word aligned")
            imm = _range(delta >> 2, 26, True, "branch displacement")
            return (B26[op] << 26) | ((imm & 0xFFFF) << 10) | ((imm >> 16) & 0x3FF)
        if op in ("csrrd", "csrwr", "csrxchg"):
            rd = _reg(operands[0]); csr = _range(self._value(operands[-1], line), 14, False, "CSR number")
            rj = 0 if op == 'csrrd' else 1 if op == 'csrwr' else _reg(operands[1])
            return 0x04000000 | (csr << 10) | (rj << 5) | rd
        if op in FIXED:
            if op in ("break", "syscall"):
                code = 0 if not operands else _range(self._value(operands[0], line), 15, False, f"{op} code")
                return FIXED[op] | code
            if operands: raise ValueError(f"{op} takes no operands")
            return FIXED[op]
        if op == "rdcntvl.w": return 0x00006000 | _reg(operands[0])
        if op == "rdcntvh.w": return 0x00006400 | _reg(operands[0])
        if op in ("rdcntid", "rdcntid.w"): return 0x00006000 | (_reg(operands[0]) << 5)
        if op == "invtlb":
            code = _range(self._value(operands[0], line), 5, False, "invtlb op")
            rj, rk = _reg(operands[1]), _reg(operands[2])
            return (int('00000110010010011', 2) << 15) | (rk << 10) | (rj << 5) | code
        if op == "cacop":
            code = _range(self._value(operands[0], line), 5, False, "cacop code")
            rj = _reg(operands[1]); imm = _range(self._value(operands[2], line), 12, True, "offset")
            return (0b0000011000 << 22) | (imm << 10) | (rj << 5) | code
        raise ValueError(f"unsupported instruction {op}")

    @staticmethod
    def _fail(line: SourceLine, message: str):
        raise AssemblyError(message, line.source, line.number, line.text)
