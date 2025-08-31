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
rm -rf feeds/packages/lang/golang
mkdir -p feeds/packages/lang/golang
if git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang; then
    echo "✅ 成功更新golang包"
else
    echo "❌ 更新golang包失败"
    exit 1
fi

# 修改插件名字
grep -rl '"终端"' . | xargs -r sed -i 's?"终端"?"TTYD"?g'
if grep -r '"TTYD 终端"' . > /dev/null; then
    grep -rl '"TTYD 终端"' . | xargs -r sed -i 's?"TTYD 终端"?"TTYD"?g'
fi
# 网络存储
if grep -r '"网络存储"' . > /dev/null; then
    grep -rl '"网络存储"' . | xargs -r sed -i 's?"网络存储"?"NAS"?g'
fi
if grep -r '"实时流量监测"' . > /dev/null; then
    grep -rl '"实时流量监测"' . | xargs -r sed -i 's?"实时流量监测"?"流量"?g'
fi
if grep -r '"KMS 服务器"' . > /dev/null; then
    grep -rl '"KMS 服务器"' . | xargs -r sed -i 's?"KMS 服务器"?"KMS激活"?g'
fi
if grep -r '"USB 打印服务器"' . > /dev/null; then
    grep -rl '"USB 打印服务器"' . | xargs -r sed -i 's?"USB 打印服务器"?"打印服务"?g'
fi
if grep -r '"Web 管理"' . > /dev/null; then
    grep -rl '"Web 管理"' . | xargs -r sed -i 's?"Web 管理"?"Web管理"?g'
fi
if grep -r '"管理权"' . > /dev/null; then
    grep -rl '"管理权"' . | xargs -r sed -i 's?"管理权"?"账号管理"?g'
fi
if grep -r '"带宽监控"' . > /dev/null; then
    grep -rl '"带宽监控"' . | xargs -r sed -i 's?"带宽监控"?"监控"?g'
fi

# 解决 libxcrypt 因 -Werror=format-nonliteral 导致的编译错误
LIBXCRYPT_MAKEFILE="feeds/packages/libs/libxcrypt/Makefile"
if [ -f "$LIBXCRYPT_MAKEFILE" ]; then
    sed -i '/CFLAGS="\$(TARGET_CFLAGS) -Wno-format-nonliteral"/d' "$LIBXCRYPT_MAKEFILE"
    # 向 CONFIGURE_ARGS 中注入 CFLAGS，禁用格式非字面量警告
    sed -i '/CONFIGURE_ARGS +=/a \	CFLAGS="\$(TARGET_CFLAGS) -Wno-format-nonliteral" \\' "$LIBXCRYPT_MAKEFILE"
    if grep -q 'CFLAGS="\$(TARGET_CFLAGS) -Wno-format-nonliteral"' "$LIBXCRYPT_MAKEFILE"; then
        echo "✅ 成功为 libxcrypt 注入 CFLAGS：-Wno-format-nonliteral"
    else
        echo "❌ libxcrypt Makefile 修改失败" >&2
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
    echo "✅ .config文件存在，配置行数: $(wc -l .config | awk '{print $1}')"
else
    echo "❌ 未找到.config文件" >&2
    exit 1
fi

# 删除重复配置项
if [ -f ".config" ]; then
    echo "正在清理.config文件中的重复配置..."
    awk '!a[$0]++' .config > .config.tmp && mv .config.tmp .config
    echo "✅ .config文件清理完成"
fi

# 显示最终配置文件信息
echo "✅ diy-part2.sh 执行完成"