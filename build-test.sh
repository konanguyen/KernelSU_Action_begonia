#!/bin/bash
set -e
JOBS=$(nproc --all)
cd /workspace/android-kernel
export PATH=/workspace/clang/bin:/workspace/gcc-64/bin:/workspace/gcc-32/bin:$PATH
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export CLANG_TRIPLE=aarch64-linux-gnu-
export KBUILD_COMPILER_STRING="$(clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export KBUILD_BUILD_HOST=WuxinBuilds
export KBUILD_BUILD_USER=konanguyen

echo "=== compiler check (clang + gcc-toolchain backend) ==="
which clang
which aarch64-linux-android-elfedit
which aarch64-linux-android-as
which aarch64-linux-android-ld
which arm-linux-androideabi-elfedit
clang --version | head -n 2

echo "=== ReSukiSU setup (ENABLE_KERNELSU=true) ==="
if [ ! -d KernelSU ]; then
  curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
fi

echo "=== defconfig (${JOBS} jobs) ==="
make -j${JOBS} O=out ARCH=arm64 CC=clang begonia_user_defconfig

# APPLY_KSU_PATCH=true from config.env (idempotent, skips existing hooks)
bash /workspace/patches.sh
if grep -q "CONFIG_KSU" arch/arm64/configs/begonia_user_defconfig; then
  sed -i 's/# CONFIG_KSU is not set/CONFIG_KSU=y/g' arch/arm64/configs/begonia_user_defconfig
  sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/begonia_user_defconfig
else
  echo "CONFIG_KSU=y" >> arch/arm64/configs/begonia_user_defconfig
fi

# DISABLE_CC_WERROR=true from config.env
echo "CONFIG_CC_WERROR=n" >> arch/arm64/configs/begonia_user_defconfig || true

echo "=== build (${JOBS} jobs) ==="
make -j${JOBS} O=out ARCH=arm64 CC=clang \
  CROSS_COMPILE=aarch64-linux-android- \
  CROSS_COMPILE_ARM32=arm-linux-androideabi- \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  LD=ld.lld
