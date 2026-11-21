# nixos-setup

**NixOS 重装、配置部署与家目录迁移指南**

## 快速入口

| 你的场景 | 从这里开始 |
| --- | --- |
| 想了解配置，或在公司设备上小范围试点 | [试点与验收](docs/pilot.md) |
| 重装系统、换机或更新现有 NixOS | [重装与恢复](docs/reinstall.md) |
| 仅恢复目录骨架 | [家目录布局](docs/storage-layout.md) |

## 适用范围

系统母本面向使用 UEFI、GRUB、GNOME 的 NixOS 工作站，示例采用非 flake 部署。将母本用于其他启动方式或 flake 时，应将所选模块合并到目标机自己的配置入口。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| [docs/](docs/) | 操作指南和验收步骤 |
| [configuration.pending.nix](configuration.pending.nix) | 系统配置入口 |
| [modules/](modules/) | 引导、桌面、电源、账户、网络和软件包等系统模块 |
| [assets/grub/](assets/grub/) | GRUB 主题资源 |
| [manifests/](manifests/) | 家目录骨架清单 |
| [home/config/](home/config/) | VS Code、Neovim、Fcitx5、btop 和用户目录偏好 |
| [scripts/](scripts/) | 家目录恢复、NixOS 代次管理和 Hermes 会话管理 |

重建使用目标机自己生成的 `hardware-configuration.nix`，以及仓库里的配置入口、`modules/` 和 `assets/`。按重装手册执行 NixOS 自带命令即可。`scripts/` 仅供目录恢复和日常维护时选用。个人文件、设备快照、登录态和密钥单独备份。Windows 对应项目为 `windows-setup`。

> [!NOTE]
> **验证状态**
>
> 已验证家目录脚本的预览、创建和重复执行。完整重装、企业管理环境和目标硬件兼容性须以试点验收记录为准。

GRUB 主题资源来自 [Elegant-grub2-themes 固定提交](https://github.com/vinceliuice/Elegant-grub2-themes/tree/8f36b5dde2361c902656bc82890f2902baa3c6c4)，采用森林深色 2K 布局。背景、图标和备用字体随仓库保存。菜单使用的 Adwaita 字体由 Nixpkgs 和 GRUB 工具生成。[上游许可证](assets/grub/elegant-forest-window-left-dark/LICENSE)
