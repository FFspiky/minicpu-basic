#!/usr/bin/env bash
set -euo pipefail

url="https://gitee.com/loongson-edu/la32r-toolchains/releases/download/v0.0.3/loongson-gnu-toolchain-8.3-x86_64-loongarch32r-linux-gnusf-v2.0.tar.xz"
archive="/tmp/la32r-toolchain.tar.xz"
target="/opt/loongarch32r"

mkdir -p "$target"

if [ ! -s "$archive" ]; then
  wget -O "$archive" "$url"
fi

echo "Archive top-level:"
tar -tf "$archive" | sed -n '1,10p'

tar -xf "$archive" -C "$target" --strip-components=1

cat > /etc/profile.d/loongarch32r.sh <<'EOF'
export PATH=/opt/loongarch32r/bin:$PATH
EOF
chmod 0644 /etc/profile.d/loongarch32r.sh

/opt/loongarch32r/bin/loongarch32r-linux-gnusf-gcc --version | head -n 1
