{ pkgs, ... }:

let
  timer = "lid-close-suspend.timer";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  grep = "${pkgs.gnugrep}/bin/grep";

  # 只有确认合盖且未检测到外部供电时才返回成功。
  powerState = ''
    closed_on_battery() {
      local state supply lid_closed=no
      for state in /proc/acpi/button/lid/*/state; do
        if [ -r "$state" ] && ${grep} -qi closed "$state"; then
          lid_closed=yes
          break
        fi
      done
      [ "$lid_closed" = yes ] || return 1

      for supply in /sys/class/power_supply/*; do
        [ -r "$supply/type" ] && [ -r "$supply/online" ] || continue
        if ${grep} -qEx 'Mains|USB.*' "$supply/type" &&
           ${grep} -qx 1 "$supply/online"; then
          return 1
        fi
      done
      return 0
    }
  '';

  updateTimer = powerState + ''
    if closed_on_battery; then
      # 重复事件不会把正在运行的倒计时清零。
      ${systemctl} start ${timer}
    else
      ${systemctl} stop ${timer}
    fi
  '';
in
{
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };

  services.acpid = {
    enable = true;
    lidEventCommands = updateTimer;
    acEventCommands = updateTimer;
  };

  systemd.timers.lid-close-suspend = {
    description = "Wait 20 minutes while closed and on battery";
    timerConfig = {
      OnActiveSec = "20min";
      AccuracySec = "1s";
      RemainAfterElapse = false;
      Unit = "lid-close-suspend.service";
    };
  };

  systemd.services.lid-close-suspend = {
    description = "Suspend if the lid is still closed and on battery";
    serviceConfig.Type = "oneshot";
    script = powerState + ''
      if closed_on_battery; then
        ${systemctl} --no-block suspend
      fi
    '';
  };

  # 现机的挂起兼容设置。真正挂起后，后台程序仍会暂停。
  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
}
