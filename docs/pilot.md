# NixOS 试点与验收

[仓库首页](../README.md) · [重装手册](reinstall.md) · [目录布局](storage-layout.md)

先在公司允许的 Linux 环境、虚拟机或专用测试设备上试用。目录预览与部分用户偏好可以单独验证。要验证引导、驱动和系统策略，使用 NixOS 虚拟机或测试设备，并提前保存快照或备份。

1. 记录仓库提交、NixOS 版本、预期启用的模块和测试项目。审查 `modules/accounts/`、`modules/network/`、`modules/boot/` 和 `modules/packages/`，替换个人账号与主机名，选用公司允许的软件、网络和缓存来源。
2. 在仓库根目录用普通用户预览目录。可选用临时路径验证实际创建，再从 `home/config/` 中挑选一项用户偏好进行合并。
3. 在已安装 NixOS 的虚拟机或测试设备上，可将候选配置放到临时目录，用下方命令构建。确认目标机硬件配置与候选模块匹配后，再按[重装指南](reinstall.md)部署。
4. 验收登录、网络、显示、项目构建和重启。笔记本合盖逻辑在代表性真机上另验。系统切换失败时使用虚拟机快照或上一可用系统代次恢复。

```bash
trial_root=$(mktemp -d)
bash scripts/restore-layout.sh "$trial_root"
```

这两个命令只创建临时测试根目录并预览路径。要验证目录创建，可运行 `bash scripts/restore-layout.sh --apply "$trial_root"`。公司电脑的系统安装和设备管理按 IT 流程处理。

## 构建候选配置

以下示例适用于目标机已有 `/etc/nixos/hardware-configuration.nix` 的非 flake 环境。从仓库根目录执行。构建产物和下载的软件包会占用 Nix store 空间。

```bash
candidate_dir=$(mktemp -d)
cp -R modules assets "$candidate_dir/"
cp configuration.pending.nix "$candidate_dir/configuration.nix"
cp /etc/nixos/hardware-configuration.nix "$candidate_dir/"
cd "$candidate_dir"
nixos-rebuild build -I "nixos-config=$candidate_dir/configuration.nix"
```

`build` 会生成候选系统，实际切换请按重装指南中的步骤执行。

## 试点记录与停止条件

试点记录应包含仓库提交、系统版本、设备或虚拟机、实际执行的命令、通过项与失败项。

> [!IMPORTANT]
> 若目标目录不明确、所需软件来源不获批准，或设备缺少可用的回退方式，暂停该项试点。 构建失败时保留构建日志并停止部署。已经切换的测试设备可选用上一可启动代次，或恢复虚拟机快照。
