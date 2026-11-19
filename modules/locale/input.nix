{ pkgs, ... }:

{
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
}
