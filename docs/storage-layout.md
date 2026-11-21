# NixOS 家目录布局

[仓库首页](../README.md) · [重装手册](reinstall.md) · [试点手册](pilot.md)

基础清单位于 [manifests/storage-layout.txt](../manifests/storage-layout.txt)。工具由 NixOS 系统配置安装。目录清单用于恢复用户的工作区和资料分类。

| 位置 | 用途 |
| --- | --- |
| `Documents/` | 课程、笔记、长期资料与应用导出 |
| `Assets/` | 图片、音乐和视频 |
| `Workspace/` | 项目、脚本、模板、工具、临时实验及 Bot |
| `Backups/` | 按对象归档的本地副本 |

目录可以手动建立。需要批量补齐时，在仓库根目录以普通用户运行可选脚本。默认预览，加 `--apply` 后补齐缺失项。也可以在命令末尾传入另一个已存在的目标目录。

```bash
bash scripts/restore-layout.sh
bash scripts/restore-layout.sh --apply
```

课程、项目和备份对象的子目录随实际数据恢复。用于重装的备份另存到目标磁盘之外。

如果需要恢复文件管理器的默认保存位置，可参考 [XDG 用户目录设置](../home/config/.config/user-dirs.dirs)，将图片、音乐、视频和模板映射到上述目录。

若应用仍写入中文截图或录屏目录，确认目标目录已创建后，再按需恢复原有兼容链接。链接名已存在时，命令会报错并保留原内容。

```bash
ln -sT -- Screenshots "$HOME/Assets/Pictures/截图"
ln -sT -- Screencasts "$HOME/Assets/Videos/录屏"
```
