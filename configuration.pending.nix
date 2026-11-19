{ pkgs, lib, ... }:

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
  # 换机手动安装：先将目标系统挂载到 /mnt，再执行 sudo nixos-generate-config --root /mnt。
  # 它会生成新机器的 /mnt/etc/nixos/hardware-configuration.nix；之后再放入本配置。
  # 日常 nixos-rebuild 不会生成此文件，当前机器已有时无需重复执行，也不要照搬旧机器的硬件文件。
  imports = [ ./hardware-configuration.nix ];

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

  services.logind.settings.Login = {
    # logind 在合盖时立即锁屏；acpid 负责电池 15 分钟、接电 20 分钟后的条件挂起。
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };
  services.acpid.enable = true;
  services.acpid.lidEventCommands = ''
    for state in /proc/acpi/button/lid/*/state; do
      [ -r "$state" ] || continue
      if ${pkgs.gnugrep}/bin/grep -qi closed "$state"; then
        ${pkgs.systemd}/bin/systemctl restart lid-close-suspend-battery.timer lid-close-suspend-final.timer
        exit 0
      fi
    done
    # 重新开盖时取消倒计时；锁屏状态仍由 GNOME 管理。
    ${pkgs.systemd}/bin/systemctl stop lid-close-suspend-battery.timer lid-close-suspend-final.timer
  '';
  systemd.timers.lid-close-suspend-battery = {
    description = "Suspend on battery 15 minutes after lid close";
    timerConfig = {
      OnActiveSec = "15min";
      AccuracySec = "1s";
      Unit = "lid-close-suspend-battery.service";
    };
  };
  systemd.services.lid-close-suspend-battery = {
    description = "Suspend if lid is closed and external power is unavailable";
    serviceConfig.Type = "oneshot";
    script = ''
      # 15 分钟时按当前电源状态判断；电池供电才挂起。
      for state in /proc/acpi/button/lid/*/state; do
        [ -r "$state" ] || continue
        if ${pkgs.gnugrep}/bin/grep -qi closed "$state"; then
          for supply in /sys/class/power_supply/*; do
            [ -r "$supply/type" ] && [ -r "$supply/online" ] || continue
            if ${pkgs.gnugrep}/bin/grep -qEx 'Mains|USB.*' "$supply/type" &&
               ${pkgs.gnugrep}/bin/grep -qx 1 "$supply/online"; then
              exit 0
            fi
          done
          ${pkgs.systemd}/bin/systemctl --no-block suspend
          exit 0
        fi
      done
    '';
  };
  systemd.timers.lid-close-suspend-final = {
    description = "Suspend 20 minutes after lid close";
    timerConfig = {
      OnActiveSec = "20min";
      AccuracySec = "1s";
      Unit = "lid-close-suspend-final.service";
    };
  };
  systemd.services.lid-close-suspend-final = {
    description = "Suspend if the laptop lid is still closed after 20 minutes";
    serviceConfig.Type = "oneshot";
    script = ''
      for state in /proc/acpi/button/lid/*/state; do
        [ -r "$state" ] || continue
        if ${pkgs.gnugrep}/bin/grep -qi closed "$state"; then
          ${pkgs.systemd}/bin/systemctl --no-block suspend
          exit 0
        fi
      done
    '';
  };
  # 保留现机已验证的挂起兼容设置：跳过睡眠前后对用户会话的额外冻结。
  # 真正进入挂起后，所有进程仍会暂停，唤醒时再恢复。
  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  # 网络与地区
  networking.hostName = "dev-machine";
  networking.networkmanager.enable = true;
  # 启用 Tailscale 后台服务，并自动提供 tailscale 命令；首次登录后会随系统启动。
  services.tailscale.enable = true;
  time.timeZone = "Asia/Shanghai";

  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = false;
      addons = with pkgs; [ qt6Packages.fcitx5-chinese-addons ];
      settings = {
        globalOptions = {
          "Hotkey/TriggerKeys"."0" = "Control+space";
          "Hotkey/AltTriggerKeys"."0" = "Shift_L";
          Behavior = {
            ActiveByDefault = "True";
            DefaultPageSize = 9;
          };
        };
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "pinyin";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "pinyin";
            Layout = "";
          };
          GroupOrder."0" = "Default";
        };
        addons.pinyin.globalSection = {
          PageSize = 9;
          CloudPinyinEnabled = "False";
        };
      };
    };
  };
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # GNOME 桌面与常用设置
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell".enabled-extensions = [ pkgs.gnomeExtensions.kimpanel.extensionUuid ];
        "org/gnome/shell/keybindings".show-screenshot-ui = [
          "<Alt>w"
          "Print"
        ];
        "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        ];
        # 此列表登记下方的快捷键配置；Control、Alt、Super 对应 Ctrl、Alt、Windows 键。
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          name = "Open Terminal";
          command = "kgx";
          binding = "<Control><Alt>t";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          name = "Open Files";
          command = "nautilus --new-window";
          binding = "<Super>e";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
          name = "Open System Monitor";
          command = "gnome-system-monitor";
          binding = "<Super><Shift>Escape";
        };
        "org/gnome/desktop/interface" = {
          font-name = "Adwaita Sans 11";
          document-font-name = "Adwaita Sans 12";
          monospace-font-name = "Adwaita Mono 11";
        };
        # 闲置 5 分钟锁屏并熄屏，但不自动挂起；服务需在锁屏期间持续运行。
        "org/gnome/desktop/session".idle-delay = lib.gvariant.mkUint32 300;
        "org/gnome/desktop/screensaver" = {
          lock-enabled = true;
          lock-delay = lib.gvariant.mkUint32 0;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-type = "nothing";
        };
        "org/gnome/desktop/input-sources".sources = [
          (lib.gvariant.mkTuple [
            "xkb"
            "us"
          ])
        ];
        "org/gnome/Console" = {
          audible-bell = false;
          visual-bell = false;
          # GNOME 将回滚行数定义为 64 位整数，因此要用 mkInt64 标注类型。
          scrollback-lines = lib.gvariant.mkInt64 10000;
          use-system-font = false;
          custom-font = "Maple Mono NF CN 16";
          font-scale = 0.9;
          theme = "night";
        };
      };
    }
  ];

  # 桌面界面沿用 GNOME 安装环境的默认字体，Noto CJK 用于补齐中文字形。
  # Maple 仅用于 GNOME Console 和 VS Code 集成终端；JetBrains Mono 仅用于 VS Code 编辑器。
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      adwaita-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      # Office 文档中的 Calibri、Cambria 字体替代。
      carlito
      caladea
      jetbrains-mono
      maple-mono.NF-CN
    ];
    # 通用字体请求优先使用 GNOME 默认字体；中文缺字时回退到 Noto CJK。
    fontconfig.defaultFonts.sansSerif = [
      "Adwaita Sans"
      "Noto Sans CJK SC"
    ];
    fontconfig.defaultFonts.monospace = [
      "Adwaita Mono"
      "Noto Sans Mono CJK SC"
    ];
  };

  xdg.mime.defaultApplications = {
    "text/html" = "google-chrome.desktop";
    "application/xhtml+xml" = "google-chrome.desktop";
    "x-scheme-handler/http" = "google-chrome.desktop";
    "x-scheme-handler/https" = "google-chrome.desktop";
    "x-scheme-handler/about" = "google-chrome.desktop";
    "x-scheme-handler/unknown" = "google-chrome.desktop";
  };

  # 桌面服务与常用软件
  services.flatpak.enable = true;
  services.printing.enable = true;
  programs.firefox.enable = true;
  programs.steam.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # 用户账户
  users.users."dev" = {
    isNormalUser = true;
    description = "Alex Yan";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Shell 与终端体验
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      directory = {
        style = "bold #B6CBE0";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      git_branch = {
        symbol = " ";
        style = "bold #8FB7C2";
        format = "[$symbol$branch]($style) ";
      };
      git_status = {
        style = "#CEB994";
        format = "([$all_status$ahead_behind]($style) )";
      };
      cmd_duration = {
        min_time = 2000;
        style = "#586576";
        format = "[took $duration]($style) ";
      };
      character = {
        success_symbol = "[❯](bold #93AEC8)";
        error_symbol = "[❯](bold #CC8F98)";
      };
    };
  };
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };
  programs.zoxide.enable = true;

  # 常用应用与开发工具链
  # 允许安装 Steam、Chrome 等有专有授权的软件包。
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    # 桌面应用与日常软件
    flclash
    obsidian
    # GNOME 日常工具：个人文件备份、截图标注、录屏裁剪。
    deja-dup
    gradia
    video-trimmer
    bitwarden-desktop
    proton-authenticator
    wechat
    # QQ 安装包地址需要从腾讯接口获取短时有效的下载签名。
    (qq.overrideAttrs (
      _:
      let
        url = "https://qqdl.gtimg.cn/qqfile/QQNTV2/9.9.36/release/9ee04bef/QQ_3.2.34_260924_amd64_01.deb";
      in
      {
        version = "3.2.34-2026-09-24";
        src =
          pkgs.runCommandLocal "QQ_3.2.34_260924_amd64_01.deb"
            {
              outputHash = "sha256-Q2xl4d0oQi4SiiHL3bX+Ti5sB51/J/7CVB4BTTjMM24=";
              outputHashMode = "flat";
              nativeBuildInputs = with pkgs; [
                curl
                jq
                cacert
              ];
            }
            ''
              signedUrl=$(
                curl -fsS --retry 3 -X POST \
                  "https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign" \
                  -H "Content-Type: application/json" \
                  -H 'x-oidb: {"uint32_command":"0x9b8e","uint32_service_type":1}' \
                  -d '{"url":"${url}"}' | jq -er '.data.url'
              )
              curl -fL --retry 3 -o "$out" "$signedUrl"
            '';
      }
    ))
    chatbox
    piper-tts
    _7zz
    nodejs_24
    (google-chrome.override { commandLineArgs = "--ozone-platform=x11"; })
    gnomeExtensions.kimpanel
    fastfetch
    btop

    # 文档、表格、演示文稿与英文拼写检查
    libreoffice-still
    hunspell
    hunspellDicts.en_US

    # 通用命令行与文件处理工具
    git
    vim
    neovim
    tree-sitter
    pyright
    wl-clipboard
    xclip
    curl
    wget
    ripgrep
    fd
    jq
    yq-go
    tree
    zip
    unzip
    shellcheck
    # C/C++ 编译、构建和调试工具
    gcc
    clang
    clang-tools
    cmake
    ninja
    gnumake
    pkg-config
    gdb

    # Go 开发工具链
    go
    gopls
    gotools
    go-tools
    delve

    # Python 开发工具链
    # 安装 Python 运行环境，但不把单独的文档输出加入系统软件清单。
    (builtins.removeAttrs python312 [ "doc" ])
    uv
    ruff

    # NixOS 配置工具与编辑器
    nixfmt
    nil
    vscode
  ];

  programs.nix-ld.enable = true;
  # 阻止 uv 自动下载 Python；项目使用系统提供的 Python。
  environment.sessionVariables.UV_PYTHON_DOWNLOADS = "never";

  # 每周自动回收未被引用的 Nix 存储路径；系统代次由管理脚本手动维护。
  # 管理脚本：/home/dev/Workspace/Scripts/manage-system-generations.sh
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
