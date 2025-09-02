# ======================================================
# 第一阶段：构建环境准备（包含所有依赖和完整源码）
# ======================================================
FROM ubuntu:22.04 AS builder

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
    # 清理预装的不需要的包
    rm -rf /etc/apt/sources.list.d/* /usr/share/dotnet /usr/local/lib/android /opt/ghc && \
    # 更新源并安装核心编译依赖（移除了一些非必需工具）
    apt-get -qq update && \
    apt-get -qq install -f -y && \
    apt-get -qq install -y --no-install-recommends \
        # 基础编译工具
        build-essential gcc-multilib g++-multilib binutils \
        # 编译必备工具链
        autoconf automake autopoint bison flex gettext gawk \
        # 库文件
        libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
        libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev \
        libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev \
        libtool zlib1g-dev zstd \
        # 文件处理工具
        bzip2 cpio p7zip p7zip-full patch rsync squashfs-tools unzip \
        # 系统工具
        ccache cmake curl device-tree-compiler git pkgconf \
        # 编程语言支持
        python2.7 python3 python3-pyelftools python3-setuptools libpython3-dev \
        # 网络工具（最小化）
        wget \
        # 以下工具在某些场景可能有用，但非核心编译必需
        # ack antlr3 aria2 asciidoc fastjar gperf haveged \
        # help2man intltool lrzsz mkisofs msmtp nano ninja-build \
        # qemu-utils scons subversion swig texinfo uglifyjs upx-ucl \
        # vim xmlto xxd \
    && \
    # 安装完成后立即清理以减小层体积
    apt-get -qq autoremove --purge && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/* \
           /tmp/* /var/tmp/* /usr/share/man/* /usr/share/info/* \
           /usr/share/swift /usr/share/miniconda /usr/local/lib/android \
           /var/spool /usr/lib/systemd /usr/lib/python*/test \
           /usr/lib/jvm/*/src.zip /usr/lib/jvm/*/demo && \
    # 设置时区
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 创建工作目录
    mkdir -p -m 777 $SRC_OPENWRT_DIR $DEFAULT_DIR

# 单独的层用于源码克隆和校验，便于缓存
RUN set -e && \
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
    # 校验源码完整性
    if [ ! -d "$SRC_OPENWRT_DIR/.git" ]; then \
        echo "❌ 源码克隆失败，未找到.git目录" && exit 1; \
    fi && \
    echo "=== 校验源码完整性 ===" && \
    LOCAL_COMMIT=$(cd $SRC_OPENWRT_DIR && git rev-parse HEAD) && \
    echo "本地Commit: $LOCAL_COMMIT" && \
    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then \
        echo "❌ 源码哈希不一致 (本地: $LOCAL_COMMIT, 远程: $REMOTE_COMMIT)" && exit 1; \
    fi && \
    # 检查源码体积
    SRC_SIZE_MB=$(du -sm $SRC_OPENWRT_DIR | awk '{print $1}') && \
    echo "源码体积: $SRC_SIZE_MB MB" && \
    if [ $SRC_SIZE_MB -lt $MIN_SRC_SIZE_MB ]; then \
        echo "❌ 源码体积过小 ($SRC_SIZE_MB MB < $MIN_SRC_SIZE_MB MB)，可能不完整" && exit 1; \
    fi && \
    # 优化git仓库以减小体积
    cd $SRC_OPENWRT_DIR && \
    git gc --aggressive --prune=now && \
    echo "=== 源码克隆及校验完成，体积: $(du -sh $SRC_OPENWRT_DIR | cut -f1) ==="

# ======================================================
# 第二阶段：精简运行环境（只包含必要的编译环境和源码）
# ======================================================
FROM ubuntu:22.04 AS final

# 从构建阶段复制必要的环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    FORCE_UNSAFE_CONFIGURE=1 \
    REPO_URL=https://github.com/padavanonly/immortalwrt-mt798x-6.6 \
    REPO_BRANCH=openwrt-24.10-6.6 \
    DEFAULT_DIR=/opt/build \
    SRC_OPENWRT_DIR=/opt/openwrt

# 命令失败时立即终止构建
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -e && \
    # 清理预装的不需要的包
    rm -rf /etc/apt/sources.list.d/* /usr/share/dotnet /usr/local/lib/android /opt/ghc && \
    # 只安装运行时必需的最小依赖集
    apt-get -qq update && \
    apt-get -qq install -f -y && \
    apt-get -qq install -y --no-install-recommends \
        # 最小编译工具集
        build-essential gcc-multilib g++-multilib \
        # 必需的库文件
        libc6-dev-i386 libncurses5-dev libncursesw5-dev \
        libreadline-dev libssl-dev zlib1g-dev zstd \
        # 必需的系统工具
        ccache cmake curl git \
        # 必需的编程语言
        python2.7 python3 \
        # 网络工具
        wget \
    && \
    # 清理以减小体积
    apt-get -qq autoremove --purge && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/* \
           /tmp/* /var/tmp/* && \
    # 设置时区
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 创建工作目录
    mkdir -p -m 777 $SRC_OPENWRT_DIR $DEFAULT_DIR

# 从构建阶段复制已经准备好的源码到最终镜像
COPY --from=builder $SRC_OPENWRT_DIR $SRC_OPENWRT_DIR

# 工作目录
WORKDIR $DEFAULT_DIR