{ ... }:

{
  # 每周自动回收未被引用的 Nix 存储路径；系统代次由管理脚本手动维护。
  # 仓库中的管理脚本位于 scripts/manage-system-generations.sh。
  # Hermes Agent 的官方 Nix flake 由用户 profile 安装；启用 flake 命令。
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  nix.settings.auto-optimise-store = true;

  # 安装系统时确定的兼容版本；升级时不要随意修改。
  system.stateVersion = "26.05";
}
