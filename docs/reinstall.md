# NixOS 重装与恢复

本文记录可随仓库迁移的系统恢复流程。仓库母本描述软件和系统行为；磁盘布局、硬件和账户状态须在目标设备单独确认。

## 1. 重装前准备

在旧设备仍可用时，单独准备受保护的个人备份，并确认可读取。至少记录：

- 个人文件和项目的实际备份位置及恢复方式。
- Hermes 登录与 QQ 机器人重新授权步骤；不要把 OAuth 凭据或 API 密钥写进仓库。
- SSH/GPG 密钥、密码管理器、认证器、浏览器和 Tailscale 的独立恢复方式。
- 旧设备采用的磁盘布局、EFI 分区位置、文件系统和是否保留 Windows。不要把 UUID 或原硬件配置直接套到新设备。

## 2. 安装 NixOS

1. 从 NixOS 安装介质启动，确认目标磁盘、分区方案、EFI 挂载点、文件系统和是否保留其他系统。先备份目标磁盘上的资料。
2. 挂载目标系统至 `/mnt`，运行 `sudo nixos-generate-config --root /mnt`。保留新生成的 `hardware-configuration.nix`。
3. 将本仓库整个目录复制到安装环境可访问的位置。把入口复制为 `/mnt/etc/nixos/configuration.nix`，并将 `modules/`、`assets/` 一并复制到 `/mnt/etc/nixos/`。
4. 根据目标机器修改主机名、用户名、启动方式、Windows 探测、显示分辨率、硬件驱动和软件包。`system.stateVersion` 按安装器生成的配置及 NixOS 规则核对，不要机械沿用旧值。
5. 检查并构建目标配置，确认 EFI、根分区和用户设置无误后才执行 `sudo nixos-install`。
6. 首次进入桌面后，确认系统盘、引导菜单、联网和用户登录均可用。

## 3. 恢复开发环境

NixOS 构建时按模块安装开发工具。登录普通用户后，先用[家目录恢复步骤](storage-layout.md)建立目录骨架，再恢复偏好与脚本。

`home/config/` 中的文件是偏好模板，恢复前检查用户名、字体、扩展和目标路径。把 `user-dirs.dirs` 内容合并到新用户的 `~/.config/user-dirs.dirs`；其他配置按相对路径复制。Neovim 配置会安装插件，首次启动需要网络。

`scripts/` 中的脚本可复制至 `~/Workspace/Scripts/` 并设为可执行。`manage-hermes-sessions.sh` 需要 Hermes CLI、带 sqlite3 的 Python 和用户自己的 `~/.hermes/state.db`。`manage-system-generations.sh` 需要 NixOS、nix-env 和 sudo。

## 4. 恢复数据

恢复文档、项目、笔记库和应用导出。Obsidian、Hermes 和 Bot 的数据保留原有结构及应用引用路径。按需重新登录 Hermes、QQ、Tailscale 和浏览器，并逐项合并用户偏好。

## 5. 验收

确认启动菜单、桌面、网络及实际使用的服务正常，并用一个实际项目验证开发工具。恢复的项目和备份应各抽查几份文件。

验证合盖策略时，先接电合盖，再拔电。用 `systemctl status lid-close-suspend.timer` 查看 20 分钟倒计时，重新接电后确认定时器停止。电池供电时合盖也应启动计时，开盖应取消。

## 日常更新与回退

1. 将 `configuration.pending.nix` 复制为 `/etc/nixos/configuration.nix`，并更新同目录下的 `modules/` 和 `assets/`。保留目标机自己的 `hardware-configuration.nix`。复制和构建命令见[现机部署步骤](../README.md#在当前机器上部署)。
2. 检查本机差异，执行 `sudo nixos-rebuild build`。
3. 构建成功后执行 `sudo nixos-rebuild switch`，再检查新代次、桌面、网络、服务和关键电源行为。
4. 如果新代次不能正常使用，从 GRUB 历史代次启动，或按 NixOS 提供的代次回退流程恢复。旧代次确认不再需要前，不要清理它们。

## 数据与配置的边界

Git 仓库适合保存可审查的声明式配置、公开主题资源和通用恢复步骤。个人文档、家目录完整清单、dconf 全量导出、浏览器资料、应用数据库、Hermes 会话与密钥应存入加密或受访问控制的独立备份，并定期验证能否恢复。

目标设备验证完成后，再逐项决定是否恢复显示器布局、Nautilus 书签、输入法偏好、编辑器设置和 GNOME 扩展。不要直接导入整份 dconf 或旧的自动启动文件；其中可能有旧机器路径、旧软件版本和失效的 Nix store 地址。
