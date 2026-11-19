{ pkgs, ... }:

let
  # 构建 Elegant GRUB 主题，并使用 GNOME 安装环境的默认界面字体。
  elegantGrubTheme = pkgs.stdenv.mkDerivation {
    pname = "elegant-grub2-theme";
    version = "2025-03-25";
    src = pkgs.fetchzip {
      url = "https://github.com/vinceliuice/Elegant-grub2-themes/archive/8f36b5dde2361c902656bc82890f2902baa3c6c4.tar.gz";
      hash = "sha256-M9k6R/rUvEpBTSnZ2PMv5piV50rGTBrcmPU4gsS7Byg=";
    };
    buildInputs = [
      pkgs.imagemagick
      pkgs.grub2
      pkgs.adwaita-fonts
      # 主题脚本会调用 lsb_release；加入依赖可消除“命令不存在”的提示。
      pkgs.lsb-release
    ];
    installPhase = ''
      mkdir -p "$out/grub/themes"
      # 选用森林配色、背景在左、菜单在右的 2K 主题布局。
      bash ./generate.sh \
        -d "$out/grub/themes" \
        -t forest \
        -p window \
        -i left \
        -c dark \
        -s 2k \
        -l system
      themeDir="$out/grub/themes/Elegant-forest-window-left-dark"
      grub-mkfont --name="Adwaita Sans" --size=18 \
        --range=32-126,183-183 \
        --output="$themeDir/adwaita-sans-18.pf2" \
        "${pkgs.adwaita-fonts}/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
      grub-mkfont --name="Adwaita Sans" --size=24 \
        --range=32-126,183-183 \
        --output="$themeDir/adwaita-sans-24.pf2" \
        "${pkgs.adwaita-fonts}/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
      substituteInPlace "$themeDir/theme.txt" \
        --replace-fail 'Terminus Regular 18' 'Adwaita Sans Regular 18' \
        --replace-fail 'Unifont Regular 24' 'Adwaita Sans Regular 24'
    '';
  };

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
