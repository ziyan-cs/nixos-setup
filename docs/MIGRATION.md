# NixOS 换机与恢复

本文记录可随仓库迁移的系统恢复流程。仓库母本描述软件和系统行为；磁盘布局、硬件和账户状态须在目标设备单独确认。

## 仓库内容

- `configuration.pending.nix`：系统配置入口。
- `modules/`：按启动、电源、桌面、网络、账户和软件包组织的 NixOS 模块。
- `assets/grub/`：GRUB 森林主题的背景、图标、布局和许可。
- `home/config/`：筛选后的 VS Code、Neovim、Fcitx5、btop、XDG 目录偏好。
- `home/directories.txt`：新家目录的基础结构。
- `home/scripts/`：Hermes 会话管理和 NixOS 系统代次管理脚本。
- `README.md`：当前机维护与部署说明。
- `hardware-configuration.nix`、EFI/分区清单、密钥、令牌和用户数据不属于公开母本。

## 换机前记录

在旧设备仍可用时，单独准备受保护的个人备份，并确认可读取。至少记录：

- 个人文件和项目的实际备份位置及恢复方式。
- Hermes 登录与 QQ 机器人重新授权步骤；不要把 OAuth 凭据或 API 密钥写进仓库。
- SSH/GPG 密钥、密码管理器、认证器、浏览器和 Tailscale 的独立恢复方式。
- 旧设备采用的磁盘布局、EFI 分区位置、文件系统和是否保留 Windows。不要把 UUID 或原硬件配置直接套到新设备。

## 全新安装

1. 从 NixOS 安装介质启动，确认目标磁盘、分区方案、EFI 挂载点、文件系统和是否保留其他系统。先备份目标磁盘上的资料。
2. 挂载目标系统至 `/mnt`，运行 `sudo nixos-generate-config --root /mnt`。保留新生成的 `hardware-configuration.nix`。
3. 将本仓库整个目录复制到安装环境可访问的位置。把入口复制为 `/mnt/etc/nixos/configuration.nix`，并将 `modules/`、`assets/` 一并复制到 `/mnt/etc/nixos/`。
4. 根据目标机器修改主机名、用户名、启动方式、Windows 探测、显示分辨率、硬件驱动和软件包。`system.stateVersion` 按安装器生成的配置及 NixOS 规则核对，不要机械沿用旧值。
5. 检查并构建目标配置，确认 EFI、根分区和用户设置无误后才执行 `sudo nixos-install`。
6. 首次启动后建立用户目录，逐项恢复配置与个人数据，再分别登录 Hermes、QQ、Tailscale、浏览器和其他账户。

## 用户偏好与脚本恢复

在仓库根目录用普通用户执行以下命令，创建基础目录。课程、备份对象和项目子目录随实际资料恢复。

```sh
while IFS= read -r path; do
  mkdir -p -- "$HOME/$path" || break
done < home/directories.txt
```

长期文档放在 `Documents/`，课程资料按课程归入 `Documents/School/`，笔记库归入 `Documents/Notes/`。图片、音乐和视频放在 `Assets/`，项目和脚本放在 `Workspace/`，备份按对象放在 `Backups/`。恢复 Obsidian 库、Hermes 资料或 Bot 项目时，保持其内部结构及应用引用的路径。

`home/config/` 中的文件是偏好模板，恢复前检查用户名、字体、扩展和目标路径。把 `user-dirs.dirs` 内容合并到新用户的 `~/.config/user-dirs.dirs`；其他配置按相对路径复制。Neovim 配置会安装插件，首次启动需要网络。

`home/scripts/` 中的脚本可复制至 `~/Workspace/Scripts/` 并设为可执行。`manage-hermes-sessions.sh` 需要 Hermes CLI、带 sqlite3 的 Python 和用户自己的 `~/.hermes/state.db`。`manage-system-generations.sh` 需要 NixOS、nix-env 和 sudo。

## 已安装系统更新

1. 从本仓库更新 `configuration.pending.nix`、`modules/` 和 `assets/` 到 `/etc/nixos/`；保留目标机自己的 `hardware-configuration.nix`。
2. 检查本机差异，执行 `sudo nixos-rebuild build`。
3. 构建成功后执行 `sudo nixos-rebuild switch`，再检查新代次、桌面、网络、服务和关键电源行为。
4. 如果新代次不能正常使用，从 GRUB 历史代次启动，或按 NixOS 提供的代次回退流程恢复。旧代次确认不再需要前，不要清理它们。

验证合盖策略时，先接电合盖，再拔电。用 `systemctl status lid-close-suspend.timer` 查看 20 分钟倒计时，重新接电后确认定时器停止。电池供电时合盖也应启动计时，开盖应取消。

## 数据与配置的边界

Git 仓库适合保存可审查的声明式配置、公开主题资源和通用恢复步骤。个人文档、家目录完整清单、dconf 全量导出、浏览器资料、应用数据库、Hermes 会话与密钥应存入加密或受访问控制的独立备份，并定期验证能否恢复。

目标设备验证完成后，再逐项决定是否恢复显示器布局、Nautilus 书签、输入法偏好、编辑器设置和 GNOME 扩展。不要直接导入整份 dconf 或旧的自动启动文件；其中可能有旧机器路径、旧软件版本和失效的 Nix store 地址。
