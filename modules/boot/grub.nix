{ pkgs, ... }:

let
  # 视觉资源随仓库保存；字体继续从 Nixpkgs 构建，复刻时无需访问主题上游。
  elegantGrubTheme = import ./theme.nix { inherit pkgs; };

  elegantGrubThemeDir = "${elegantGrubTheme}/grub/themes/Elegant-forest-window-left-dark";
in
{
  # 启动与电源
  # 使用 GRUB 作为默认启动菜单，以选择 NixOS 历史代次或 Windows。
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  # 菜单显示 8 秒后自动启动默认项。
  boot.loader.timeout = 8;
  boot.loader.grub = {
    enable = true;
    # UEFI 模式下使用 EFI 启动方式，不把 GRUB 写入传统 BIOS/MBR 位置。
    device = "nodev";
    efiSupport = true;
    # 扫描其他系统的启动项，例如 Windows Boot Manager。
    useOSProber = true;
    timeoutStyle = "menu";
    theme = elegantGrubThemeDir;
    splashImage = "${elegantGrubThemeDir}/background.jpg";
    # 优先匹配显示器原生分辨率；固件不支持时退回自动选择。
    gfxmodeEfi = "1920x1200,auto";
    # NixOS 生成 grub.cfg 后，统一调整当前系统、历史配置和 Windows 的显示名称。
    extraInstallCommands = ''
      grubCfg=/boot/grub/grub.cfg
      if [ -f "$grubCfg" ]; then
        ${pkgs.gnused}/bin/sed -i \
          -e 's/menuentry "NixOS"/menuentry "NixOS · Current"/' \
          -e 's/submenu "NixOS - All configurations"/submenu "NixOS · Previous"/' \
          "$grubCfg"
        ${pkgs.perl}/bin/perl -i -pe \
          's/(menuentry\s+["\x27])Windows Boot Manager(?:\s+\(on [^)]*\))?(["\x27])/$1Windows · Boot Manager$2/' \
          "$grubCfg"
      fi
    '';
    extraConfig = ''
      insmod gfxterm
      insmod png
    '';
  };
}
