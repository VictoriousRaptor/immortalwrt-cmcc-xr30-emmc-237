# ImmortalWrt 24.10 for CMCC RAX3000M (eMMC)

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE)

## 项目简介

本项目是基于以下两个核心项目构建的定制固件编译环境：
1. [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) - GitHub Actions 在线编译框架
2. [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6) - ImmortalWrt 24.10（Linux内核6.6）固件源码

- 专门为中国移动RAX3000M路由器（eMMC存储版本）定制，提供自动化编译、自定义插件和优化功能。
- 编译其他设备
   - 1.替换.config配置文件或更改其相关设备内容
   - 2.通过‘make menuconfig’选择对应设备
   ### 注意：需要在.github\workflows\build-openwrt.yml文件里的env环境变量中`DEVICE_NAME`的`cmcc_rax3000m-emmc`设备机型改为要编译的机型

## 特性

- **自动化编译**：使用GitHub Actions实现自动构建流程
- **最新固件**：基于237大佬的ImmortalWrt 24.10和Linux内核6.6
- **中文界面**：默认LuCI中文界面，优化用户体验

## 准备工作

### 1. 必要条件

- GitHub账号
- 基本的Git操作知识
- 了解OpenWrt固件编译的基本概念

### 2. 配置GitHub

#### 获取REPO_TOKEN

1. 登录GitHub账号，点击右上角头像，选择`Settings`
2. 在左侧菜单选择`Developer settings` -> `Personal access tokens` -> `Tokens (classic)`
3. 点击`Generate new token`按钮
4. 填写`Note`（如"ImmortalWrt Build Token"）
5. 选择权限：
   - `repo` - 全选
   - `workflow`
6. 点击`Generate token`按钮
7. **复制并保存生成的Token**（离开页面后将无法再次查看）

#### Fork仓库

1. 访问[本仓库](https://github.com/您的用户名/immortalwrt24.10-6.6-cmcc_rax3000m-emmc-237-1)
2. 点击右上角的`Fork`按钮，将仓库复制到您的GitHub账号

#### 添加REPO_TOKEN

1. 进入您Fork后的仓库页面
2. 点击`Settings` -> `Secrets and variables` -> `Actions`
3. 点击`New repository secret`按钮
4. `Name`填写为`REPO_TOKEN`
5. `Secret`粘贴之前复制的Token
6. 点击`Add secret`按钮保存

## 使用教程

### GitHub Actions 自动编译

#### 修改配置文件

1. 修改`.config`文件（固件编译配置）：
   - 可以直接编辑现有`.config`文件
   - 或者上传您自己生成的配置文件

2. 修改自定义脚本：
   - `diy-part1.sh`：更新feeds之前的自定义操作（添加软件源等）
   - `diy-part2.sh`：更新feeds之后的自定义操作（修改默认设置、主题等）

#### 开始编译

1. 进入仓库的`Actions`页面
2. 选择`Build OpenWrt` workflow
3. 点击`Run workflow`按钮，选择好配置
   - `编译方式`：选择编译环境
      - `Host`：在本地环境编译
      - `Docker`：在Docker容器中编译，已集成依赖和固件源码
   - LAN IP：设置路由器LAN口IP地址
   - 默认主题：选择默认的Web管理界面主题
   - 主机名：设置路由器的主机名
   - SSH：是否通过SSH连接到Actions
   - 缓存加速编译：是否启用缓存加速编译
   - 清理编译：是否在编译前清理旧的编译文件
4. 点击`Run workflow`开始编译过程
5. 编译过程通常需要1-3小时，取决于配置的复杂度

#### 下载固件

1. 编译完成后，在Actions页面找到已完成的Workflow运行
2. 点击进入详情页面
3. 在页面底部的`Artifacts`部分下载编译好的固件

## 自定义配置说明

### 配置文件说明

- `.config`：包含固件编译的所有配置选项，决定了编译哪些软件包和功能
- `diy-part1.sh`：添加第三方feed源和包的脚本
  ```bash
  # 示例：添加istore和nas相关源
  add_feed "istore" "https://github.com/linkease/istore.git;main"
  add_feed "nas_luci" "https://github.com/linkease/nas-packages-luci.git;main"
  ```
- `diy-part2.sh`：更新golang包
  ```bash
  # 示例：更新golang包
  rm -rf feeds/packages/lang/golang
  mkdir -p feeds/packages/lang/golang
  git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang
  ```

### 自定义.config文件

如果您想完全自定义固件配置，可以：

1. 基于现有`.config`文件修改
2. 使用`make menuconfig`交互式配置（本地环境）
3. 从[padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6)获取默认配置


### Web界面升级

1. 登录路由器Web管理界面（默认：`http://192.168.1.1`）
2. 进入`系统` -> `备份/升级`
3. 选择编译好的固件文件，点击`刷写固件`按钮
4. 等待刷机完成并自动重启

## 项目结构

```
├── .github/workflows/   # GitHub Actions工作流配置
│   ├── build-image.yml  # 构建镜像工作流
│   ├── build-openwrt.yml # 构建OpenWrt固件工作流
│   └── update-checker.yml # 更新检查工作流
├── Dockerfile           # Docker镜像配置
├── .config              # OpenWrt编译配置文件
├── build-openwrt.sh     # 主要构建脚本
├── diy-part1.sh         # 自定义脚本（更新feeds前）
├── diy-part2.sh         # 自定义脚本（更新feeds后）
└── README.md            # 项目说明文档
```
## 引用项目

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) - GitHub Actions在线编译模板
- [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6) - ImmortalWrt固件源码
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) - 开源路由器固件项目
- [Microsoft Azure](https://azure.microsoft.com) - 提供GitHub Actions运行环境
- [GitHub Actions](https://github.com/features/actions) - 自动化工作流平台

## 许可证

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [项目维护者]