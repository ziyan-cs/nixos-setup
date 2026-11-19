# NixOS 配置母本

这个仓库保存一份供当前电脑维护、换机时裁剪使用的 NixOS 配置母本。入口是 [`configuration.pending.nix`](configuration.pending.nix)，实际功能配置在 `modules/` 中。它不是当前系统配置的自动镜像，也不包含个人数据或完整系统备份。

## 文件与状态

| 文件 | 用途 |
| --- | --- |
| `configuration.pending.nix` | 待审查和部署的入口；保留 `.pending` 名称，防止误认为它已在运行 |
| `modules/boot/grub.nix`、`modules/boot/theme.nix` | GRUB 启动菜单及主题构建 |
| `assets/grub/elegant-forest-window-left-dark/` | GRUB 森林背景、布局、图标及上游许可文件 |
| `modules/power/lid.nix` | 合盖锁屏、延时挂起和恢复兼容设置 |
| `modules/network/networking.nix` | 主机名、NetworkManager、Tailscale、时区 |
| `modules/locale/input.nix` | 中文区域设置、Fcitx5、键盘布局 |
| `modules/desktop/` | GNOME、快捷键、字体、默认应用和桌面服务 |
| `modules/accounts/`、`modules/shell/` | 本地用户、终端提示符及命令行体验 |
| `modules/packages/` | 桌面应用和开发工具清单；QQ 下载适配位于 `desktop.nix` |
| `modules/system/maintenance.nix` | Nix 功能、垃圾回收与 `system.stateVersion` |
| `.gitignore` | Git 收录白名单，防止本地快照、凭据和设备资料被意外提交 |

要修改启动时看到的 GRUB 菜单和主题，查看 `modules/boot/grub.nix`；要修改进入系统后的 GNOME/GDM 登录与桌面设置，查看 `modules/desktop/gnome.nix`。`modules/packages/default.nix` 将桌面应用和开发工具两份有序清单组合起来。

实际运行的配置以 `/etc/nixos/configuration.nix` 为准。修改此仓库不会自动切换系统；每次部署都要先比较差异，再由管理员执行构建和切换。入口引用了 `./hardware-configuration.nix` 和相对路径 `./modules/...`；GRUB 模块引用了 `./assets/grub/...`。部署时必须把整个 `modules/` 和 `assets/` 目录一起复制。仓库没有 `hardware-configuration.nix`，目标机器必须使用自己的硬件配置。

GRUB 视觉资源来自 [Elegant-grub2-themes 固定提交](https://github.com/vinceliuice/Elegant-grub2-themes/tree/8f36b5dde2361c902656bc82890f2902baa3c6c4)，选用森林、窗口、左侧图片、深色、2K 布局。仓库保存的是现机生成后的背景、图片和 `theme.txt`，以便离线复刻此菜单；字体由 Nixpkgs 的 Adwaita 字体与 GRUB 工具生成。上游项目使用 [GPL-3.0](assets/grub/elegant-forest-window-left-dark/LICENSE) 许可；这些视觉资源的版权归原作者所有。

## 当前配置概览

- UEFI + GRUB 双系统菜单、GNOME 桌面、中文环境和 Fcitx5。
- 开盖锁屏或闲置不会使后台任务挂起；合盖立即锁屏，仍合盖时电池供电约 15 分钟、接电约 20 分钟后挂起。
- NetworkManager、Tailscale、Flatpak、打印、PipeWire、Steam，以及日常应用和开发工具。
- 使用 NixOS 默认账户密码认证；不额外设置 PAM 登录失败锁定。MySQL 服务未启用。
- Hermes 由用户级安装和配置管理；此母本不保存其账号或密钥。

这些是母本的设计，不代表当前机器已经切换到该版本。

## 在当前机器上部署

先在本机检查差异，特别留意引导、账户、网络和电源策略。现机配置若仍是单文件，可以用 `git show e81d89d:configuration.pending.nix` 查看拆分前的完整母本，对照模块中的内容。以下命令在仓库目录执行；需要管理员权限的命令由使用者亲自运行。

```sh
nix-instantiate --parse configuration.pending.nix >/dev/null
for file in modules/*/*.nix; do nix-instantiate --parse "$file" >/dev/null || exit 1; done
diff -u /etc/nixos/configuration.nix configuration.pending.nix || true
if test -d /etc/nixos/modules; then diff -ru /etc/nixos/modules modules || true; fi
```

确认后保留一份现用配置，复制母本，并构建验证：

```sh
sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.before-pending
sudo cp -a modules /etc/nixos/
sudo cp -a assets /etc/nixos/
sudo cp configuration.pending.nix /etc/nixos/configuration.nix
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

`build` 成功只说明配置能够构建。`switch` 之后还需核对桌面登录、网络、合盖挂起和实际使用的服务。部署前不要把包含密码或令牌的本地改动提交到 Git。

## 换机时使用

1. 在新机器的安装环境中，按硬件实际情况分区、挂载并运行 `nixos-generate-config --root /mnt`。保留新生成的 `/mnt/etc/nixos/hardware-configuration.nix`；不要复用旧机器的硬件文件。
2. 先审查并调整各模块中的 GRUB/EFI、Windows 探测、显示分辨率、主机名、用户名、GNOME、合盖策略、软件包、`system.stateVersion`。已有系统的 `system.stateVersion` 不能因升级而随意改动。
3. 将调整后的母本复制为目标机的 `/mnt/etc/nixos/configuration.nix`，并将整个 `modules/` 与 `assets/` 目录复制到 `/mnt/etc/nixos/`。入口还引用同目录的 `hardware-configuration.nix`。
4. 确认配置与磁盘挂载后再运行 `nixos-install`。GRUB 视觉资源随仓库保存，无需再访问主题上游；Nixpkgs 包和 QQ 桌面版仍可能需要网络下载。
5. 系统启动后单独恢复用户文件、软件登录和密钥。本仓库不承担这些数据的备份。

## GitHub 留存边界

仓库只跟踪本 README、母本、`modules/` 下的 Nix 文件、GRUB 视觉资源和 `.gitignore`。本地的 `NixOS-Backup.md`、`snapshots/`、`user-config/`、`inventories/`、`folders/` 等包含设备、账户或个人路径信息，均不进入 GitHub。若未来希望远程保存这些资料，应使用单独的受保护备份；提交前逐项检查。

母本本身含有本机用户名、主机名和用户显示名，并公开所用软件与系统设计。准备发布为公开仓库前，也应确认愿意公开这些信息。
