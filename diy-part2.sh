#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 更新golang包
golangdir="feeds/packages/lang/golang"
rm -rf "$golangdir"
mkdir -p "$golangdir"
GIT_CLONE_OUTPUT=$(git clone https://github.com/sbwml/packages_lang_golang -b 24.x "$golangdir" 2>&1)
CLONE_EXIT_CODE=$?
if [ $CLONE_EXIT_CODE -eq 0 ]; then
    echo -e "✅ golang 包更新成功"
else
    echo -e "❌ golang 包更新失败：$GIT_CLONE_OUTPUT"
    exit 1
fi
# 修改插件名字
# 参数1: 原名称
# 参数2: 新名称
update_name(){  
    local old_name=$1  
    local new_name=$2  
    if grep -r "$old_name" . > /dev/null; then  
        echo -e "✅ 找到 $old_name，开始替换为 $new_name"  
        grep -rl "$old_name" . | xargs -r sed -i "s?$old_name?$new_name?g"  
    else  
        echo -e "ℹ️ 未找到 $old_name，跳过替换"  
    fi  
}
# 替换插件名字
update_name "终端" "TTYD"
update_name "TTYD 终端" "TTYD"
update_name "网络存储" "NAS"
update_name "实时流量监测" "流量监测"
update_name "KMS 服务器" "KMS"
update_name "USB 打印服务器" "打印服务"
update_name "Web 管理" "Web管理"
update_name "管理权" "账号管理"
update_name "带宽监控" "监控"

# 解决 libxcrypt 因 -Werror=format-nonliteral 导致的编译错误
LIBXCRYPT_MAKEFILE="feeds/packages/libs/libxcrypt/Makefile"
if [ -f "$LIBXCRYPT_MAKEFILE" ]; then
    sed -i '/CFLAGS="\$(TARGET_CFLAGS) -Wno-format-nonliteral"/d' "$LIBXCRYPT_MAKEFILE"
    # 向 CONFIGURE_ARGS 中注入 CFLAGS，禁用格式非字面量警告
    sed -i '/CONFIGURE_ARGS +=/a \	CFLAGS="\$(TARGET_CFLAGS) -Wno-format-nonliteral" \\' "$LIBXCRYPT_MAKEFILE"
    if grep -q 'CFLAGS="\$(TARGET_CFLAGS) -Wno-format-nonliteral"' "$LIBXCRYPT_MAKEFILE"; then
        echo "✅ 设置libxcrypt编译参数为忽略警告"
    else
        echo "❌ 设置libxcrypt编译参数失败" >&2
        exit 1
    fi
else
    echo "ℹ️ 未找到 libxcrypt 的 Makefile，跳过修改"
fi

# 解决 quickstart 插件编译提示不支持压缩
if [ -f "package/feeds/nas_luci/luci-app-quickstart/Makefile" ]; then
    # 修正路径，从nas_luci源中查找该插件
    sed -i 's/DEPENDS:=+luci-base/DEPENDS:=+luci-base\n    NO_MINIFY=1/' "package/feeds/nas_luci/luci-app-quickstart/Makefile"
    echo "✅ 成功修改 quickstart 插件配置"
else
    echo "ℹ️ 未找到 quickstart 插件的 Makefile，跳过修改"
fi

# 验证配置文件是否存在
if [ -f ".config" ]; then
    echo "✅ .config文件配置行数: $(wc -l .config | awk '{print $1}')"
else
    echo "ℹ️ 未找到.config文件" >&2
    exit 1
fi

# 删除重复配置项
if [ -f ".config" ]; then
    echo "正在清理.config文件中的重复配置..."
    awk '!a[$0]++' .config > .config.tmp && mv .config.tmp .config
    echo "✅ .config文件清理完成，行数: $(wc -l .config | awk '{print $1}')"
fi

# 显示最终配置文件信息
echo "✅ diy-part2.sh 执行完成"