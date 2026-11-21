# NixOS 家目录布局

基础清单位于 [manifests/storage-layout.txt](../manifests/storage-layout.txt)。工具由 NixOS 系统配置安装。目录清单用于恢复用户的工作区和资料分类。

| 位置 | 用途 |
| --- | --- |
| `Documents/` | 课程、笔记、长期资料与应用导出 |
| `Assets/` | 图片、音乐和视频 |
| `Workspace/` | 项目、脚本、模板、临时实验及 Bot |
| `Backups/` | 按对象归档的本地副本 |

在仓库根目录以普通用户运行。默认预览家目录中将创建的目录，加 `--apply` 后补齐缺失项。也可以在命令末尾传入另一个已存在的目标目录。

```bash
bash scripts/restore-layout.sh
bash scripts/restore-layout.sh --apply
```

课程、项目和备份对象的子目录随实际数据恢复。用于重装的备份另存到目标磁盘之外。
