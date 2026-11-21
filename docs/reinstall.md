# NixOS 重装与恢复

[仓库首页](../README.md) · [试点手册](pilot.md) · [目录布局](storage-layout.md)

适用于通过系统配置文件部署的 NixOS 工作站。已有 NixOS 的读者可直接看[日常更新与回退](#日常更新与回退)。若只想在试点设备评估配置，从[试点与验收](pilot.md)开始。

## 1. 重装前准备

开始安装前，确认受保护的备份可读，并记录以下信息。

- 个人文件和项目的实际备份位置及恢复方式。
- Hermes 登录与 QQ 机器人重新授权步骤；不要把 OAuth 凭据或 API 密钥写进仓库。
- SSH/GPG 密钥、密码管理器、认证器、浏览器和 Tailscale 的独立恢复方式。
- 旧设备采用的磁盘布局、EFI 分区位置、文件系统和是否保留 Windows。不要把 UUID 或原硬件配置直接套到新设备。

## 2. 安装 NixOS

本仓库采用 UEFI + GRUB 默认布局。先按 [NixOS 安装手册](https://nixos.org/manual/nixos/stable/#sec-installation-manual-installing)确认目标磁盘、EFI 分区、文件系统和双系统边界。以下命令从安装环境的仓库根目录执行，目标系统和引导分区应已挂载。

```bash
sudo nixos-generate-config --root /mnt &&
sudo cp /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.generated.nix &&
sudo cp -R modules assets /mnt/etc/nixos/ &&
sudo cp configuration.pending.nix /mnt/etc/nixos/configuration.nix
```

安装前核对以下各项。

| 项目 | 检查位置 |
| --- | --- |
| 目标机磁盘和硬件 | 保留新生成的 `/mnt/etc/nixos/hardware-configuration.nix`，确认其中的根分区和引导分区挂载 |
| 引导与双系统 | `modules/boot/grub.nix` 中的 EFI、引导器和 Windows 探测 |
| 账户和网络 | `modules/accounts/` 与 `modules/network/` 中的用户名、权限、主机名和服务 |
| 软件与版本 | `modules/packages/` 中的软件清单，以及 `modules/system/maintenance.nix` 中的 `system.stateVersion`。新安装以安装器生成的值为依据 |

> [!CAUTION]
> 若无法确认目标盘、EFI 挂载点或双系统分区归属，停止安装。

核对后执行 `sudo nixos-install`，按提示设置 root 密码。重启前用 `sudo nixos-enter --root /mnt -c 'passwd dev'` 设置普通用户密码，其中 `dev` 换成配置声明的真实用户名。首次从硬盘启动后确认引导菜单、桌面登录和网络可用。

## 3. 恢复开发环境

NixOS 构建时按模块安装开发工具。登录普通用户后，先用[家目录恢复步骤](storage-layout.md)建立目录骨架，再恢复偏好与脚本。

`home/config/` 中的文件是偏好模板，恢复前检查用户名、字体、扩展和目标路径。把 `user-dirs.dirs` 内容合并到新用户的 `~/.config/user-dirs.dirs`；其他配置按相对路径复制。Neovim 配置会安装插件，首次启动需要网络。

`scripts/` 中的脚本可复制至 `~/Workspace/Scripts/` 并设为可执行。`manage-hermes-sessions.sh` 需要 Hermes CLI、带 sqlite3 的 Python 和用户自己的 `~/.hermes/state.db`。`manage-system-generations.sh` 需要 NixOS、nix-env 和 sudo。

## 4. 恢复数据

恢复文档、项目、笔记库和应用导出。Obsidian、Hermes 和 Bot 的数据保留原有结构及应用引用路径。按需重新登录 Hermes、QQ、Tailscale 和浏览器，并逐项合并用户偏好。

## 5. 验收

验收结果按项目记录。

| 项目 | 通过条件 |
| --- | --- |
| 启动 | 能从目标磁盘启动并登录普通用户，双系统机器能选择约定的启动项 |
| 网络与服务 | 能访问所需网络，计划启用的服务运行正常 |
| 开发工具 | 代表性项目完成一次构建或测试 |
| 数据 | 抽查恢复的项目和文件，可以正常读取 |

验证合盖策略时，先接电合盖，再拔电。用 `systemctl status lid-close-suspend.timer` 查看 20 分钟倒计时，重新接电后确认定时器停止。电池供电时合盖也应启动计时，开盖应取消。

## 日常更新与回退

以下命令适用于使用 `/etc/nixos/configuration.nix` 的非 flake 安装。多主机或 flake 用户应把所选模块合并到自己使用的配置入口。

从仓库根目录运行。先保存当前配置目录，以便恢复配置源。检查现机自定义模块及资源后再复制，保留目标机的 `hardware-configuration.nix`。

```bash
backup_dir="/etc/nixos.before-$(date +%Y%m%d-%H%M%S)"
sudo cp -a /etc/nixos "$backup_dir" &&
sudo cp -R modules assets /etc/nixos/ &&
sudo cp configuration.pending.nix /etc/nixos/configuration.nix &&
sudo nixos-rebuild build
```

构建成功后单独运行 `sudo nixos-rebuild switch`，再按上节验收。切换失败时，从 GRUB 选择上一可用代次启动。若要继续用旧配置构建，从刚保存的备份恢复配置文件。系统代次和配置文件备份分别用于回退运行状态与恢复配置源。

## 数据与配置的边界

Git 仓库适合保存可审查的声明式配置、公开主题资源和通用恢复步骤。个人文档、家目录完整清单、dconf 全量导出、浏览器资料、应用数据库、Hermes 会话与密钥应存入加密或受访问控制的独立备份，并定期验证能否恢复。

目标设备验证完成后，再逐项决定是否恢复显示器布局、Nautilus 书签、输入法偏好、编辑器设置和 GNOME 扩展。不要直接导入整份 dconf 或旧的自动启动文件；其中可能有旧机器路径、旧软件版本和失效的 Nix store 地址。
