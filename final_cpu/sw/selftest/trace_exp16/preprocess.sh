#!/usr/bin/env bash
set -euo pipefail

src=$(cd "$(dirname "$0")" && pwd)
out=${1:-"$src/../build/trace_exp16"}
cc=${LA32_GCC:-/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc}
flags=(-I"$src/include" -nostdinc -nostdlib -D_KERNEL -fno-builtin
       -D__loongarch32 -DMEMSTART=0x10000000 -DMEMSIZE=0x04000
       -DCPU_COUNT_PER_US=1000 -DGUEST -DEXP=16)

rm -rf "$out"
mkdir -p "$out"
"$cc" "${flags[@]}" -S "$src/start.S" > "$out/00_start.s"
"$cc" "${flags[@]}" -S "$src/init.S" > "$out/01_init.s"

while IFS= read -r source; do
    name=$(basename "$source" .S)
    "$cc" "${flags[@]}" -S "$source" > "$out/$name.s"
    # Each original file was a separate ELF object and therefore had its own
    # local inst_error symbol.  The custom static assembler consumes all
    # sources together, so namespace that one repeated local label.
    sed -i "s/\\<inst_error\\>/${name}_inst_error/g" "$out/$name.s"
done < <(find "$src/inst" -name 'n*.S' | sort -V)

# GCC's assembler preprocessor keeps GAS semicolon statement separators on a
# single physical line.  Normalize them for the line-oriented custom parser.
find "$out" -name '*.s' -exec sed -i 's/;/\n/g' {} +

echo "generated $(find "$out" -name '*.s' | wc -l) assembly files in $out"
