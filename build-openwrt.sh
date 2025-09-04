# ======================================================
# 函数列表 - 所有需要导出的函数
# ======================================================
ALL_FUNCTIONS=(log_info log_error log_warn log_success log_separator log_highlight log_debug init_env prepare_source load_custom_feeds update_install_feeds load_custom_config download_packages compile_firmware)
# ======================================================
# 日志函数 - 添加颜色支持
# ======================================================
# 参数1: 颜色代码(r:红色, g:绿色, y:黄色, b:蓝色, z:紫色, l:青色)
# 参数2: 日志内容
function echo_color() {
case "$1" in
    r) local Color="\033[0;31m";; # 红色
    g) local Color="\033[0;32m";; # 绿色
    y) local Color="\033[0;33m";; # 黄色
    b) local Color="\033[0;34m";; # 蓝色
    z) local Color="\033[0;35m";; # 紫色
    l) local Color="\033[0;36m";; # 青色
    *) local Color="\033[0;0m";;  # 默认色
esac
if [ "$NO_COLOR" != "true" ]; then
    echo -e "${Color}${2}\033[0m"
else
    echo -e "${2}"
fi
}

# 信息日志函数
# 参数1: 日志内容
# 参数2: 可选，时间显示控制(0=不显示时间, 1=显示时间，默认1)
function log_info() {
local show_time=${2:-1}
if [ "$show_time" -eq 1 ]; then
    echo_color "g" "[$(date +'%m-%d %H:%M:%S')] $1"
else
    echo_color "g" "$1"
fi
}

# 错误日志函数
# 参数1: 错误内容
# 参数2: 可选，时间显示控制(0=不显示时间, 1=显示时间，默认1)
# 返回值: 1 (表示错误)
function log_error() {
local show_time=${2:-1}
if [ "$show_time" -eq 1 ]; then
    echo_color "r" "[$(date +'%m-%d %H:%M:%S')] ❌ $1" >&2
else
    echo_color "r" "❌ $1" >&2
fi
return 1
}

# 警告日志函数
# 参数1: 警告内容
# 参数2: 可选，时间显示控制(0=不显示时间, 1=显示时间，默认1)
function log_warn() {
local show_time=${2:-1}
if [ "$show_time" -eq 1 ]; then
    echo_color "y" "[$(date +'%m-%d %H:%M:%S')] ⚠️ $1"
else
    echo_color "y" "⚠️ $1"
fi
}

# 成功提示函数
# 参数1: 成功内容
# 参数2: 可选，时间显示控制(0=不显示时间, 1=显示时间，默认1)
function log_success() {
local show_time=${2:-1}
if [ "$show_time" -eq 1 ]; then
    echo_color "g" "[$(date +'%m-%d %H:%M:%S')] ✅ $1"
else
    echo_color "g" "✅ $1"
fi
}

# 分隔线输出函数
# 参数1: 标题内容(可选)
# 参数2: 可选，时间显示控制(0=不显示时间, 1=显示时间，默认1)
function log_separator() {
local title="$1"
local show_time=${2:-1}
if [ -n "$title" ]; then
    if [ "$show_time" -eq 1 ]; then
        echo_color "b" "\n===== $title $(date +'%m-%d %H:%M:%S') ====="
    else
        echo_color "b" "\n===== $title ====="
    fi
else
    echo_color "b" "\n======================================="
fi
}

# 调试信息输出函数(默认不显示，通过DEBUG环境变量控制)
# 参数1: 调试内容
# 参数2: 可选，时间显示控制(0=不显示时间, 1=显示时间，默认1)
function log_debug() {
if [ "$DEBUG" = "true" ]; then
    local show_time=${2:-1}
    if [ "$show_time" -eq 1 ]; then
        echo_color "z" "[DEBUG $(date +'%m-%d %H:%M:%S')] $1"
    else
        echo_color "z" "[DEBUG] $1"
    fi
fi
}

# 突出提示日志函数
# 参数1: 提示内容
# 参数2: 可选，时间显示控制(0=不显示时间, 1=显示时间，默认1)
function log_highlight() {
local show_time=${2:-1}
if [ "$show_time" -eq 1 ]; then
    echo_color "z" "[$(date +'%m-%d %H:%M:%S')] $1"
else
    echo_color "z" "$1"
fi
}

# ======================================================
# 初始化环境函数（仅主机编译使用）
# 功能: 安装编译依赖、设置时区、创建工作目录
# ======================================================
init_env() {
log_info "开始初始化编译环境..."
# 更新系统并安装依赖
sudo -E apt-get -qq update
sudo -E apt-get -qq install \
    ack antlr3 aria2 asciidoc autoconf automake autopoint binutils bison \
    build-essential bzip2 ccache cmake cpio curl device-tree-compiler \
    fastjar flex gawk gettext gcc-multilib g++-multilib git gperf haveged \
    help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
    libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev \
    libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz mkisofs msmtp \
    nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 \
    python3-pyelftools python3-setuptools libpython3-dev qemu-utils rsync \
    scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip \
    vim wget xmlto xxd zlib1g-dev

# 清理系统
sudo -E apt-get -qq autoremove --purge
sudo -E apt-get -qq clean
# 设置时区
sudo timedatectl set-timezone "$TZ"
# 设置工作目录权限
sudo mkdir -p "$WORK_DIR"
sudo chown -R $USER:$GROUPS "$WORK_DIR"
log_success "编译环境初始化完成！"
log_info "工作目录：$WORK_DIR"
}

# ======================================================
# 克隆源码函数
# 功能: 从远程仓库克隆源码并验证完整性
# ======================================================
# 参数: 最小源码大小(MB，可选)
prepare_source() {
local min_src_size_mb=${1:-150}

log_info "开始准备源码..."
sudo mkdir -p "$SOURCE_DIR"
# 获取远程源码哈希
log_info "获取远程源码哈希：$REPO_URL ($REPO_BRANCH)"
REMOTE_COMMIT=$(git ls-remote $REPO_URL $REPO_BRANCH | awk '{print $1}')
if [ -z "$REMOTE_COMMIT" ]; then
    log_error "无法获取远程仓库哈希值"
    return 1
fi
log_info "远程最新Commit: $REMOTE_COMMIT"

# 克隆源码，带重试机制
rm -rf "$SOURCE_DIR"
for i in {1..3};
do
    git clone --depth 1 --single-branch -b $REPO_BRANCH $REPO_URL "$SOURCE_DIR" && break
    log_errir "克隆失败，重试第$i次..." && sleep 5
done

# 检查克隆是否成功
if [ ! -d "$SOURCE_DIR/.git" ]; then
    log_error "源码克隆失败，未找到.git目录"
    return 1
fi

# 校验源码完整性
log_info "校验源码完整性..."
LOCAL_COMMIT=$(git -C "$SOURCE_DIR" rev-parse HEAD)
log_info "本地Commit: $LOCAL_COMMIT"

if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    log_error "源码哈希不一致 (本地: $LOCAL_COMMIT, 远程: $REMOTE_COMMIT)"
    return 1
fi

# 校验源码体积
SRC_SIZE_MB=$(du -sm "$SOURCE_DIR" | awk '{print $1}')
log_info "源码体积: $SRC_SIZE_MB MB"
if [ $SRC_SIZE_MB -lt $min_src_size_mb ]; then
    log_error "源码体积过小 ($SRC_SIZE_MB MB < $min_src_size_mb MB)，可能不完整"
    return 1
fi

log_success "源码准备完成: $(du -sh "$SOURCE_DIR" | cut -f1)"
}

# ======================================================
# 加载自定义feeds
# 功能: 替换feeds配置文件并执行diy-part1.sh脚本
# ======================================================
load_custom_feeds() {
log_info "开始加载自定义feeds..."
# 检查并替换feeds配置文件
if [ -e "$WORK_DIR/feeds.conf.default" ]; then
    cp -f "$WORK_DIR/feeds.conf.default" "$SOURCE_DIR/feeds.conf.default" && \
        log_success "已替换feeds配置文件"
    if [ $? -ne 0 ]; then
        log_error "复制feeds配置文件失败！"
        return 1
    fi
fi
# 执行diy-part1.sh并进行错误处理
if [ -f "$WORK_DIR/$DIY_P1_SH" ]; then
    chmod +x "$WORK_DIR/$DIY_P1_SH" && log_info "执行diy-part1.sh..."
    WORKDIR=$(pwd)
    cd "$SOURCE_DIR"
    "$WORKDIR/$DIY_P1_SH"
    if [ $? -ne 0 ]; then
        log_error "diy-part1.sh执行失败！"
        return 1
    fi
else
    log_error "diy-part1.sh脚本不存在"
    return 1
fi
log_success "加载自定义feeds完成！"
}

# ======================================================
# 更新并安装feeds
# 功能: 更新OpenWrt源码的feeds并安装所有包
# ======================================================
update_install_feeds() {
log_info "开始更新并安装feeds..."

# 更新feeds，带重试机制
cd "$SOURCE_DIR"
for i in {1..3}; do 
    ./scripts/feeds update -a && break || (log_errir "更新feeds失败，重试第$i次" && sleep 10)
done
# 安装feeds
./scripts/feeds install -a -j$(nproc)

log_success "feeds安装完成！"
}

# ======================================================
# 加载自定义配置
# 功能: 加载自定义配置文件并执行diy-part2.sh脚本
# ======================================================
load_custom_config() {

log_info "开始加载自定义配置..."
# 复制files目录
if [ -d "$WORK_DIR/files" ]; then
    cp -r "$WORK_DIR/files" "$SOURCE_DIR/files" && log_success "已复制自定义files目录"
fi
# 执行diy-part2.sh并进行错误处理
WORKDIR=$(pwd)
cd "$SOURCE_DIR"
if [ -f "$WORKDIR/$DIY_P2_SH" ]; then
    log_info "执行diy-part2.sh..."
    chmod +x "$WORKDIR/$DIY_P2_SH"
    "$WORKDIR/$DIY_P2_SH"
    if [ $? -ne 0 ]; then
        log_error "diy-part2.sh执行失败！"
        return 1
    fi
else
    log_error "diy-part2.sh脚本不存在"
    return 1
fi
# 检查配置文件是否存在
if [ ! -f ".config" ]; then
    log_error "未找到配置文件 .config，终止编译！"
    return 1
fi
log_info ".config配置行数: $(wc -l ".config" | awk '{print $1}')"
# 设置用户输入的参数
if [ -n "$LAN_IP" ]; then
    log_info "设置LAN IP地址为: $LAN_IP"
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/${LAN_IP}/g" $(find "./feeds/luci/modules/luci-mod-system" -type f -name 'flash.js')
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/${LAN_IP}/g" "./package/base-files/files/bin/config_generate"
fi
if [ -n "$DEFAULT_THEME" ]; then
    log_info "设置默认主题为: $DEFAULT_THEME"
    sed -i "s/luci-theme-bootstrap/luci-theme-${DEFAULT_THEME}/g" "./feeds/luci/collections/luci/Makefile"
fi
if [ -n "$HOSTNAME" ]; then
    log_info "设置默认主机名为: $HOSTNAME"
    sed -i "s/set system.@system\[-1\].hostname='ImmortalWrt'/set system.@system[-1].hostname='${HOSTNAME}'/g" "./package/base-files/files/bin/config_generate"
    sed -i "s/'hostname:string:OpenWrt'/'hostname:string:${HOSTNAME}'/g" "./package/base-files/files/etc/init.d/system"
    sed -i "s/echo OpenWrt-failsafe/echo ${HOSTNAME}-failsafe/g" "./package/base-files/files/lib/preinit/10_indicate_failsafe"
fi
if [ "$HIGH_POWER_5G" = "true" ] || [ "$HIGH_POWER_5G" = true ] || [ "$HIGH_POWER_5G" = "1" ]; then
    log_info "5G高功率25db设置中..."
    rm -f "./package/mtk/drivers/mt_wifi/files/mt7981-default-eeprom/e2p"
    if [ $? -eq 0 ]; then
       log_success "删除 e2p 成功"
    else
       log_error "删除 e2p 失败"
    fi
    EEPROM_FILE="./package/mtk/drivers/mt_wifi/files/mt7981-default-eeprom/MT7981_iPAiLNA_EEPROM.bin"
    if [ -f "$EEPROM_FILE" ]; then
       mkdir -p "./files/lib/firmware"
    ln -sf "./lib/firmware/MT7981_iPAiLNA_EEPROM.bin" "./files/lib/firmware/e2p"
      if test -L "./files/lib/firmware/e2p"; then log_success "符号链接已创建"; else log_error "符号链接创建失败"; fi
    else
       log_error "$EEPROM_FILE 不存在，无法创建符号链接"
      exit 1
    fi
    EEPROM_FILE=$(find "./package" -name MT7981_iPAiLNA_EEPROM.bin 2>/dev/null | head -n 1)
    if [ -z "$EEPROM_FILE" ]; then
        log_error "未找到 EEPROM 文件"
        exit 1
    fi
    EXPECTED_CONTENT=$(printf '\x2B%.0s' {1..20})
    CURRENT_CONTENT_RAW=$(dd if="$EEPROM_FILE" bs=1 skip=$((0x445)) count=20 2>&1)
    READ_EXIT_CODE=$?
    printf '%s' "$CURRENT_CONTENT_RAW" | grep -E 'records (in|out)|bytes copied' | while IFS= read -r line; do
        [ -n "$line" ] && log_info "$line"
    done
    if [ $READ_EXIT_CODE -ne 0 ]; then
        log_error "读取EEPROM文件失败: $EEPROM_FILE"
    fi
    ACTUAL_EEPROM_DATA=$(printf '%s' "$CURRENT_CONTENT_RAW" | tail -c 20)
    if [ "$ACTUAL_EEPROM_DATA" != "$EXPECTED_CONTENT" ]; then
        DD_WRITE_OUTPUT=$(echo -n "$EXPECTED_CONTENT" | dd of="$EEPROM_FILE" bs=1 seek=$((0x445)) count=20 conv=notrunc 2>&1)
        WRITE_EXIT_CODE=$?
        printf '%s' "$DD_WRITE_OUTPUT" | while IFS= read -r line; do
            [ -n "$line" ] && log_info "$line"
        done
        if [ $WRITE_EXIT_CODE -eq 0 ]; then
            log_success "EEPROM 文件已更新: $EEPROM_FILE"
        else
            log_error "EEPROM 文件更新失败: $EEPROM_FILE"
        fi
    else
        log_success "EEPROM 文件无需修改: $EEPROM_FILE"
    fi
    
    log_success "5G高功率25db设置完成"
fi
log_success "自定义配置加载完成！"
}

# ======================================================
# 下载软件包
# 功能: 下载编译所需的软件包
# ======================================================
download_packages() {
cd "$SOURCE_DIR"
log_info "执行make defconfig进行配置的验证与补全，会改变.config配置文件，如果编译比原.config配置文件少东西可以尝试删掉这个命令"
make defconfig
log_success "make defconfig执行完成"
# 下载软件包，带重试机制
log_info "开始下载软件包..."
for i in {1..3}; do 
    make download -j$(nproc) && break || (log_info "下载失败，重试第$i次" && sleep 10)
done

# 清理不完整的下载文件
find dl -size -1024c -exec ls -l {} \;
find dl -size -1024c -exec rm -f {} \;

log_info "已下载软件包大小: $(du -sh dl | cut -f1)"
log_success "软件包下载完成！"
}

# ======================================================
# 编译固件
# 功能: 使用多线程编译OpenWrt固件，仅返回编译结果状态码
# 返回值: 0表示成功
# ======================================================
compile_firmware() {
    log_info "开始编译固件（使用$(nproc)线程）..."
    cd "$SOURCE_DIR"
    if make -j$(nproc); then
        log_success "固件编译完成！"
        return 0
    else
        log_error "多线程编译失败，尝试单线程编译..."
        if make -j1 V=s; then
            log_success "单线程编译完成！"
            return 0
        else
            log_error "固件编译失败！"
            exit 1
        fi
    fi
}

export -f "${ALL_FUNCTIONS[@]}"
# ======================================================
# 主函数（如果直接运行脚本时使用）
# ======================================================
main() {
echo "请通过GitHub Actions工作流运行此脚本"
exit 0
}

# 如果脚本被直接运行，则执行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
main
fi

