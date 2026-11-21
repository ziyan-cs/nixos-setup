{ pkgs, lib, ... }:

{
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
        # Caffeine 即使开启，也允许闲置锁屏和熄屏，避免全屏应用使屏幕整夜常亮。
        "org/gnome/shell/extensions/caffeine".screen-blank = "always";
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
}
