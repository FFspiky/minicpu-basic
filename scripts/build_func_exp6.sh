#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/loongarch32r/bin:$PATH"

cd /mnt/d/CPU_DESIGN/cdp_ede_local-master/mycpu_env/func

make clean
make EXP=6

echo "Generated files:"
ls -lh obj/inst_ram.coe obj/inst_ram.mif obj/data_ram.coe obj/data_ram.mif obj/test.s
