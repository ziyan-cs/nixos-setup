{ ... }:

{
  # 此文件是部署入口。换机时先生成目标机器自己的 hardware-configuration.nix。
  # 模块按功能拆分；部署时须将整个 modules/ 目录一并复制到 /etc/nixos/。
  imports = [
    ./hardware-configuration.nix
    ./modules/boot/grub.nix
    ./modules/power/lid.nix
    ./modules/network/networking.nix
    ./modules/locale/input.nix
    ./modules/desktop/gnome.nix
    ./modules/desktop/services.nix
    ./modules/accounts/user.nix
    ./modules/shell/terminal.nix
    ./modules/packages/default.nix
    ./modules/system/maintenance.nix
  ];
}
