# nixos-setup

用于重装 NixOS、迁移到新电脑，或恢复家目录和开发环境。系统入口是 [configuration.pending.nix](configuration.pending.nix)。这份母本源自一台使用 UEFI、GRUB 和 GNOME 的个人电脑。

| 你的场景 | 从这里开始 |
| --- | --- |
| 想了解配置，或在公司设备上小范围试点 | [试点与验收](docs/pilot.md) |
| 重装系统、换机或更新现有 NixOS | [重装与恢复](docs/reinstall.md) |
| 仅恢复目录骨架 | [家目录布局](docs/storage-layout.md) |

| 路径 | 内容 |
| --- | --- |
| [docs/](docs/) | 操作指南和验收步骤 |
| [modules/](modules/) | 引导、桌面、电源、账户、网络和软件包等系统模块 |
| [assets/grub/](assets/grub/) | GRUB 主题资源 |
| [manifests/](manifests/) | 家目录骨架清单 |
| [home/config/](home/config/) | VS Code、Neovim、Fcitx5、btop 和用户目录偏好 |
| [scripts/](scripts/) | 家目录恢复、NixOS 代次管理和 Hermes 会话管理 |

目标机使用自己生成的 `hardware-configuration.nix`。套用母本前，核对启动方式、磁盘挂载、账号、网络、软件和电源策略。个人文件、设备快照、登录态和密钥单独备份。Windows 对应项目为 `windows-setup`。

GRUB 主题资源来自 [Elegant-grub2-themes 固定提交](https://github.com/vinceliuice/Elegant-grub2-themes/tree/8f36b5dde2361c902656bc82890f2902baa3c6c4)，采用森林深色 2K 布局。背景、图标和备用字体随仓库保存。菜单使用的 Adwaita 字体由 Nixpkgs 和 GRUB 工具生成。[上游许可证](assets/grub/elegant-forest-window-left-dark/LICENSE)
