{ pkgs, ... }:

{
  services.logind.settings.Login = {
    # 合盖立即锁屏；acpid 仅在断电后开始 20 分钟挂起倒计时。
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };
  services.acpid.enable = true;
  services.acpid.lidEventCommands = ''
    for state in /proc/acpi/button/lid/*/state; do
      [ -r "$state" ] || continue
      if ${pkgs.gnugrep}/bin/grep -qi closed "$state"; then
        for supply in /sys/class/power_supply/*; do
          [ -r "$supply/type" ] && [ -r "$supply/online" ] || continue
          if ${pkgs.gnugrep}/bin/grep -qEx 'Mains|USB.*' "$supply/type" &&
             ${pkgs.gnugrep}/bin/grep -qx 1 "$supply/online"; then
            ${pkgs.systemd}/bin/systemctl stop lid-close-suspend.timer
            exit 0
          fi
        done
        ${pkgs.systemd}/bin/systemctl restart lid-close-suspend.timer
        exit 0
      fi
    done
    # 重新开盖时取消倒计时；锁屏状态仍由 GNOME 管理。
    ${pkgs.systemd}/bin/systemctl stop lid-close-suspend.timer
  '';
  systemd.timers.lid-close-suspend = {
    description = "Suspend 20 minutes after power is disconnected while lid is closed";
    timerConfig = {
      OnActiveSec = "20min";
      AccuracySec = "1s";
      Unit = "lid-close-suspend.service";
    };
  };
  systemd.services.lid-close-suspend = {
    description = "Suspend if lid remains closed 20 minutes after power loss";
    serviceConfig.Type = "oneshot";
    script = ''
      # 到期时重新确认仍合盖且已断电；如果期间接回电源则保持运行。
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
  # 保留现机已验证的挂起兼容设置：跳过睡眠前后对用户会话的额外冻结。
  # 真正进入挂起后，所有进程仍会暂停，唤醒时再恢复。
  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
}
