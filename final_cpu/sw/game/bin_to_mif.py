#!/usr/bin/env python3
import argparse
from pathlib import Path


def words_from_binary(data):
    padded = bytearray(data)
    while len(padded) % 4:
        padded.append(0)
    for i in range(0, len(padded), 4):
        word = padded[i:i + 4]
        yield "".join(f"{byte:08b}" for byte in reversed(word))


def write_mif(bin_path, mif_path, words):
    data = Path(bin_path).read_bytes()
    lines = list(words_from_binary(data))
    if len(lines) > words:
        raise SystemExit(f"image uses {len(lines)} words, RAM limit is {words}")
    lines.extend(["0" * 32] * (words - len(lines)))
    Path(mif_path).write_text("\n".join(lines) + "\n", encoding="ascii")


def write_coe(bin_path, coe_path, words):
    data = bytearray(Path(bin_path).read_bytes())
    while len(data) % 4:
        data.append(0)
    word_count = len(data) // 4
    if word_count > words:
        raise SystemExit(f"image uses {word_count} words, RAM limit is {words}")

    hex_words = []
    for i in range(0, len(data), 4):
        word = data[i:i + 4]
        hex_words.append("".join(f"{byte:02x}" for byte in reversed(word)))
    hex_words.extend(["00000000"] * (words - word_count))

    with Path(coe_path).open("w", encoding="ascii", newline="\n") as out:
        out.write("memory_initialization_radix = 16;\n")
        out.write("memory_initialization_vector =\n")
        out.write(",\n".join(hex_words))
        out.write(";\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("binary")
    parser.add_argument("--mif", required=True)
    parser.add_argument("--coe", required=True)
    parser.add_argument("--words", type=int, default=262144)
    args = parser.parse_args()

    write_mif(args.binary, args.mif, args.words)
    write_coe(args.binary, args.coe, args.words)


if __name__ == "__main__":
    main()

