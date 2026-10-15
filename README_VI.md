[English](README.md)

# KernelSU Action cho Begonia

GitHub Action + build Docker local cho Redmi Note 8 Pro (`begonia`, MT6785, kernel `4.14`) tích hợp [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU).

## Toolchain (đã verify)

| Thành phần | Nguồn |
|---|---|
| Clang 22 | [ZyCromerZ/Clang](https://github.com/ZyCromerZ/Clang) `22.0.0git-20250928` |
| GCC 64-bit | `konanguyen/aarch64-linux-android-4.9` (`CROSS_COMPILE`) |
| GCC 32-bit | `konanguyen/arm-linux-androideabi-4.9` (`CROSS_COMPILE_ARM32`) |
| Kernel | `konanguyen/android_kernel_xiaomi_begonia@Suzaku-bka` |
| AnyKernel3 | `konanguyen/AnyKernel3_begonia` (check device `begonia`) |

Lưu ý: `CC=clang`, toolchain GCC chỉ làm backend (`--gcc-toolchain`, assembler, linker, `libgcc`). Không cần binary `gcc`.

## Dùng GitHub Action

1. Fork repo này.
2. Sửa `config.env` (source, branch, defconfig, `ENABLE_KERNELSU`, ...).
3. Tab `Actions` → `Build Kernel` → `Run workflow`.
4. Artifact: `Image.gz-dtb`, zip `AnyKernel3` (và `dtbo`/`boot.img` nếu bật). Flash zip qua TWRP/OrangeFox.

### Các tùy chọn `config.env`

| Key | Ý nghĩa | Ví dụ |
|---|---|---|
| `KERNEL_SOURCE` / `KERNEL_SOURCE_BRANCH` | Repo và branch kernel | `.../android_kernel_xiaomi_begonia`, `Suzaku-bka` |
| `KERNEL_CONFIG` | Tên defconfig | `begonia_user_defconfig` |
| `ARCH` | Kiến trúc | `arm64` |
| `KERNEL_FILE` | File image output, khớp `BOARD_KERNEL_IMAGE_NAME` | `Image.gz-dtb` |
| `EXTRA_BUILD_COMMAND` | Flag make thêm, cách nhau bằng space | `LD=ld.lld` |
| `DISABLE-LTO` | `true` để tắt LTO khi build lỗi | `false` |
| `ENABLE_KERNELSU` | Chạy `setup.sh` của ReSukiSU | `true` |
| `APPLY_KSU_PATCH` | Chạy `patches.sh` + `CONFIG_KSU=y` (idempotent) | `true` |
| `ADD_KPROBES_CONFIG` | Tự chèn kprobes vào defconfig | `false` |
| `ADD_OVERLAYFS_CONFIG` | Tự chèn overlayfs vào defconfig | `false` |
| `DISABLE_CC_WERROR` | Ép `CONFIG_CC_WERROR=n` | `true` |
| `MAKE_BOOT_IMAGE` / `SOURCE_BOOT_IMAGE` | Đóng lại `boot.img` từ boot image gốc | rỗng / URL |

## Build Docker local (môi trường giống hệt CI)

```bash
# Build image (tải Clang + GCC + source một lần)
docker compose build

# Build kernel đầy đủ, output ra ./out/ (đã gitignore)
docker compose run --rm kernel

ls -lh out/arch/arm64/boot/Image.gz-dtb
```

Lệnh Docker thuần tương đương nằm trong `Dockerfile` và `build-test.sh`.

## Kết quả đã verify

* `Image.gz-dtb` (19M) build sạch với `-j$(nproc --all)`.
* `CONFIG_KSU=y`, binary `Image` chứa symbol `kernelsu.*`.
* `out/AnyKernel3-begonia-KSU.zip` (21M) flash qua recovery.

## Cảnh báo :warning:

Nếu dùng source của người khác để build, chỉ dùng cá nhân, không chia sẻ lại — tôn trọng công sức tác giả.

## Credits

* [AnyKernel3](https://github.com/osm0sis/AnyKernel3)
* [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)
* [ZyCromerZ Clang](https://github.com/ZyCromerZ/Clang)
* [AOSP](https://android.googlesource.com)
* [tiann/KernelSU](https://github.com/tiann/KernelSU)
* [xiaoxindada](https://github.com/xiaoxindada)
* [xiaoleGun](https://github.com/xiaoleGun)
