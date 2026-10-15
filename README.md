[Tiếng Việt](README_VI.md)

# KernelSU Action For Begonia

GitHub Action + local Docker build for the Redmi Note 8 Pro (`begonia`, MT6785, kernel `4.14`) with [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU).

## Toolchain (verified)

| Component | Source |
|---|---|
| Clang 22 | [ZyCromerZ/Clang](https://github.com/ZyCromerZ/Clang) `22.0.0git-20250928` |
| GCC 64-bit | `konanguyen/aarch64-linux-android-4.9` (`CROSS_COMPILE`) |
| GCC 32-bit | `konanguyen/arm-linux-androideabi-4.9` (`CROSS_COMPILE_ARM32`) |
| Kernel | `konanguyen/android_kernel_xiaomi_begonia@Suzaku-bka` |
| AnyKernel3 | `konanguyen/AnyKernel3_begonia` (device-checked for `begonia`) |

Note: `CC=clang`, the GCC toolchains are only used as backend (`--gcc-toolchain`, assembler, linker, `libgcc`). The `gcc` driver binary itself is not required.

## Usage (GitHub Action)

1. Fork this repository.
2. Edit `config.env` (source, branch, defconfig, `ENABLE_KERNELSU`, ...).
3. Open the `Actions` tab → `Build Kernel` → `Run workflow`.
4. Artifacts: `Image.gz-dtb`, `AnyKernel3` flashable zip (and `dtbo`/`boot.img` when enabled). Flash the zip in TWRP/OrangeFox.

### `config.env` options

| Key | Meaning | Example |
|---|---|---|
| `KERNEL_SOURCE` / `KERNEL_SOURCE_BRANCH` | Kernel repo and branch | `.../android_kernel_xiaomi_begonia`, `Suzaku-bka` |
| `KERNEL_CONFIG` | Defconfig name | `begonia_user_defconfig` |
| `ARCH` | Target arch | `arm64` |
| `KERNEL_FILE` | Output image, matches `BOARD_KERNEL_IMAGE_NAME` | `Image.gz-dtb` |
| `EXTRA_BUILD_COMMAND` | Extra make flags, space separated | `LD=ld.lld` |
| `DISABLE-LTO` | Set `true` to disable LTO when it breaks the build | `false` |
| `ENABLE_KERNELSU` | Run ReSukiSU `setup.sh` | `true` |
| `APPLY_KSU_PATCH` | Apply `patches.sh` manual hooks + `CONFIG_KSU=y` (idempotent) | `true` |
| `ADD_KPROBES_CONFIG` | Inject kprobes options into defconfig | `false` |
| `ADD_OVERLAYFS_CONFIG` | Inject overlayfs option into defconfig | `false` |
| `DISABLE_CC_WERROR` | Force `CONFIG_CC_WERROR=n` | `true` |
| `MAKE_BOOT_IMAGE` / `SOURCE_BOOT_IMAGE` | Repack `boot.img` from a working source boot image | empty / URL |

## Usage (local Docker, same environment as CI)

```bash
# Build the image (downloads Clang + GCC + kernel source once)
docker compose build

# Full kernel build, output goes to ./out/ (gitignored)
docker compose run --rm kernel

# Follow logs
tail -f /tmp/opencode/begonia-kernel-ksu.log  # or plain: docker compose run --rm kernel
ls -lh out/arch/arm64/boot/Image.gz-dtb
```

Equivalent plain Docker commands are in `Dockerfile` and `build-test.sh`.

## Verified result

* `Image.gz-dtb` (19M) builds clean with `-j$(nproc --all)`.
* `CONFIG_KSU=y`, `Image` binary contains `kernelsu.*` symbols.
* `out/AnyKernel3-begonia-KSU.zip` (21M) flashable via recovery.

## Warning :warning:

If you build from someone else's kernel source, keep the result for personal use and do not redistribute — respect the author's work.

## Credits

* [AnyKernel3](https://github.com/osm0sis/AnyKernel3)
* [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)
* [ZyCromerZ Clang](https://github.com/ZyCromerZ/Clang)
* [AOSP](https://android.googlesource.com)
* [tiann/KernelSU](https://github.com/tiann/KernelSU)
* [xiaoxindada](https://github.com/xiaoxindada)
* [xiaoleGun](https://github.com/xiaoleGun)
