{ ... }:

{
  # 用户账户
  users.users."dev" = {
    isNormalUser = true;
    description = "Alex Yan";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}
