{ pkgs, ... }:

{
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
}
