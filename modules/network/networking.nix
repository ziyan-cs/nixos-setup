{ ... }:

{
  # 网络与地区
  networking.hostName = "dev-machine";
  networking.networkmanager.enable = true;
  # 启用 Tailscale 后台服务，并自动提供 tailscale 命令；首次登录后会随系统启动。
  services.tailscale.enable = true;
  time.timeZone = "Asia/Shanghai";
}
