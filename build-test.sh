#!/bin/bash
set -e
JOBS=$(nproc --all)
ENABLE_SUSFS=${ENABLE_SUSFS:-false}
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

echo "=== BakaSU setup (ENABLE_KERNELSU=true) ==="
if [ ! -d KernelSU ]; then
  curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" | bash
fi

if [ "$ENABLE_SUSFS" = true ]; then
  echo "=== SUSFS setup ==="
  bash /workspace/susfs/convert-hooks.sh
  bash /workspace/susfs/apply-susfs.sh
  sed -i '/CONFIG_KSU_MANUAL_HOOK/d; /CONFIG_KSU_MANUAL_HOOK_AUTO_/d' arch/arm64/configs/begonia_user_defconfig
  echo "CONFIG_KSU_SUSFS=y" >> arch/arm64/configs/begonia_user_defconfig
  echo "# CONFIG_KSU_SUSFS_SUS_MAP is not set" >> arch/arm64/configs/begonia_user_defconfig
fi

# NOTE: defconfig-file edits must happen BEFORE `make defconfig` below,
# otherwise they never land in out/.config.
# ADD_OVERLAYFS_CONFIG=true from config.env (required for magic mount)
if ! grep -q "CONFIG_OVERLAY_FS" arch/arm64/configs/begonia_user_defconfig; then
echo "CONFIG_OVERLAY_FS=y" >> arch/arm64/configs/begonia_user_defconfig
fi

# DISABLE_CC_WERROR=true from config.env
if ! grep -q "CONFIG_CC_WERROR" arch/arm64/configs/begonia_user_defconfig; then
echo "CONFIG_CC_WERROR=n" >> arch/arm64/configs/begonia_user_defconfig
fi

echo "=== defconfig (${JOBS} jobs) ==="
make -j${JOBS} O=out ARCH=arm64 CC=clang begonia_user_defconfig
grep -E "CONFIG_KSU_SUSFS=y|CONFIG_KSU_MANUAL_HOOK=y|CONFIG_OVERLAY_FS=y|CONFIG_CC_WERROR" out/.config || true

# APPLY_KSU_PATCH=true from config.env (idempotent, skips existing hooks;
# not needed with SUSFS since convert-hooks.sh already handled them)
if [ "$ENABLE_SUSFS" != true ]; then
bash /workspace/patches.sh
fi
if grep -q "CONFIG_KSU" arch/arm64/configs/begonia_user_defconfig; then
  sed -i 's/# CONFIG_KSU is not set/CONFIG_KSU=y/g' arch/arm64/configs/begonia_user_defconfig
  sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/begonia_user_defconfig
else
  echo "CONFIG_KSU=y" >> arch/arm64/configs/begonia_user_defconfig
fi

echo "=== build (${JOBS} jobs, retry on parallel-build flakes) ==="
for i in 1 2 3; do
make -j${JOBS} O=out ARCH=arm64 CC=clang \
  CROSS_COMPILE=aarch64-linux-android- \
  CROSS_COMPILE_ARM32=arm-linux-androideabi- \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  LD=ld.lld && break
echo "build attempt $i failed, retrying..."
sleep 5
done
# fail the script if the final image is still missing
[ -f out/arch/arm64/boot/Image.gz-dtb ]
