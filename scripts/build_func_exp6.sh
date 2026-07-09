#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/loongarch32r/bin:$PATH"

EXP_ID="${1:-${EXP:-6}}"
ENV_DIR="${2:-${CPU_ENV_DIR:-cdp_ede_local-master}}"
REPO_ROOT="/mnt/d/CPU_DESIGN"

case "${ENV_DIR}" in
    /*)
        FUNC_DIR="${ENV_DIR}/mycpu_env/func"
        ;;
    *)
        FUNC_DIR="${REPO_ROOT}/${ENV_DIR}/mycpu_env/func"
        ;;
esac

if [ ! -d "${FUNC_DIR}" ]; then
    echo "CPU environment not found: ${FUNC_DIR}" >&2
    exit 1
fi

cd "${FUNC_DIR}"

make clean
make EXP="${EXP_ID}"

echo "Generated EXP=${EXP_ID} files in ${ENV_DIR}:"
ls -lh obj/inst_ram.coe obj/inst_ram.mif obj/data_ram.coe obj/data_ram.mif obj/test.s
