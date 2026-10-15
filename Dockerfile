FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV WORKSPACE=/workspace
ENV ARCH=arm64
ENV SUBARCH=arm64

# Same packages as .github/workflows/build-kernel.yml + gcc compat libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ccache automake flex lzop bison gperf build-essential \
    zip curl wget zlib1g-dev g++-multilib libxml2-utils bzip2 \
    libbz2-dev libbz2-1.0 squashfs-tools pngcrush schedtool dpkg-dev \
    liblz4-tool make optipng libssl-dev pwgen libswitch-perl \
    policycoreutils minicom libxml-sax-base-perl libxml-simple-perl \
    bc libc6-dev-i386 libncurses6 libx11-dev lib32z-dev libgl1-mesa-dev \
    xsltproc unzip device-tree-compiler python3 perl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Clang 22 - same URL as workflow (no -q so progress shows in plain logs)
RUN mkdir -p clang && \
    wget --progress=dot:giga https://github.com/ZyCromerZ/Clang/releases/download/22.0.0git-20250928-release/Clang-22.0.0git-20250928.tar.gz && \
    tar -C clang/ -zxf Clang-22.0.0git-20250928.tar.gz && \
    rm Clang-22.0.0git-20250928.tar.gz

# GCC 4.9 pair from konanguyen (fix for missing CROSS_COMPILE in workflow)
RUN git clone --depth=1 https://github.com/konanguyen/aarch64-linux-android-4.9 gcc-64 && \
    git clone --depth=1 https://github.com/konanguyen/arm-linux-androideabi-4.9 gcc-32

# Kernel source - same as config.env
RUN git clone --depth=1 https://github.com/konanguyen/android_kernel_xiaomi_begonia -b Suzaku-bka android-kernel

ENV PATH=/workspace/clang/bin:/workspace/gcc-64/bin:/workspace/gcc-32/bin:$PATH
ENV CROSS_COMPILE=aarch64-linux-android-
ENV CROSS_COMPILE_ARM32=arm-linux-androideabi-
ENV CLANG_TRIPLE=aarch64-linux-gnu-
ENV KBUILD_BUILD_HOST=WuxinBuilds
ENV KBUILD_BUILD_USER=konanguyen

COPY build-test.sh /workspace/build-test.sh
RUN chmod +x /workspace/build-test.sh

CMD ["/bin/bash"]
