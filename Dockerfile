# 基于ubuntu:22.04镜像构建
FROM ubuntu:22.04

ARG BUILD_TRIGGER=""

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    FORCE_UNSAFE_CONFIGURE=1 \
    REPO_URL=https://github.com/padavanonly/immortalwrt-mt798x-6.6 \
    REPO_BRANCH=openwrt-24.10-6.6 \
    DEFAULT_DIR=/opt/build \
    SRC_OPENWRT_DIR=/opt/openwrt \
    MIN_SRC_SIZE_MB=150


# 命令失败时立即终止构建
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -e && \
    echo "Build trigger: $BUILD_TRIGGER" && \
    rm -rf /etc/apt/sources.list.d/* /usr/share/dotnet /usr/local/lib/android /opt/ghc && \
    apt-get -qq update && \
    apt-get -qq install -f -y && \
    # 安装编译依赖
    apt-get -qq install -y --no-install-recommends \
        ack antlr3 aria2 asciidoc autoconf automake autopoint binutils bison \
        build-essential bzip2 ccache cmake cpio curl device-tree-compiler \
        fastjar flex gawk gettext gcc-multilib g++-multilib git gperf haveged \
        help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
        libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev \
        libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz mkisofs msmtp \
        nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 \
        python3-pyelftools python3-setuptools libpython3-dev qemu-utils rsync \
        scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip \
        vim wget xmlto xxd zlib1g-dev zstd && \
    apt-get -qq autoremove --purge && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/* \
           /tmp/* /var/tmp/* /usr/share/man/* /usr/share/info/* \
           /usr/share/swift /usr/share/miniconda /usr/local/lib/android \
           /var/spool /usr/lib/systemd /usr/lib/python*/test \
           /usr/lib/jvm/*/src.zip /usr/lib/jvm/*/demo && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    mkdir -p $SRC_OPENWRT_DIR && \
    chmod 777 $SRC_OPENWRT_DIR && \
    mkdir -p $DEFAULT_DIR && \
    chmod 777 $DEFAULT_DIR && \
    echo "=== 获取远程源码哈希: $REPO_URL ($REPO_BRANCH) ===" && \
    REMOTE_COMMIT=$(git ls-remote $REPO_URL $REPO_BRANCH | awk '{print $1}') && \
    if [ -z "$REMOTE_COMMIT" ]; then \
        echo "❌ 无法获取远程仓库哈希值" && exit 1; \
    fi && \
    echo "远程最新Commit: $REMOTE_COMMIT" && \
    echo "=== 开始拉取源码 ===" && \
    rm -rf $SRC_OPENWRT_DIR && \
    for i in {1..3}; do \
        git clone --depth 1 --single-branch -b $REPO_BRANCH $REPO_URL $SRC_OPENWRT_DIR && break; \
        echo "克隆失败，重试第$i次..." && sleep 5; \
    done && \
    if [ ! -d "$SRC_OPENWRT_DIR/.git" ]; then \
        echo "❌ 源码克隆失败，未找到.git目录" && exit 1; \
    fi && \
    echo "=== 校验源码完整性 ===" && \
    LOCAL_COMMIT=$(cd $SRC_OPENWRT_DIR && git rev-parse HEAD) && \
    echo "本地Commit: $LOCAL_COMMIT" && \
    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then \
        echo "❌ 源码哈希不一致 (本地: $LOCAL_COMMIT, 远程: $REMOTE_COMMIT)" && exit 1; \
    fi && \
    SRC_SIZE_MB=$(du -sm $SRC_OPENWRT_DIR | awk '{print $1}') && \
    echo "源码体积: $SRC_SIZE_MB MB" && \
    if [ $SRC_SIZE_MB -lt $MIN_SRC_SIZE_MB ]; then \
        echo "❌ 源码体积过小 ($SRC_SIZE_MB MB < $MIN_SRC_SIZE_MB MB)，可能不完整" && exit 1; \
    fi && \
    cd $SRC_OPENWRT_DIR && \
    rm -rf .git/logs .git/objects/pack .git/hooks .git/info && \
    echo "=== 源码克隆及校验完成，体积: $(du -sh $SRC_OPENWRT_DIR | cut -f1) ==="

# 工作目录
WORKDIR $DEFAULT_DIR
