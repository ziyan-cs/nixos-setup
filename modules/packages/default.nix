{ pkgs, ... }:

{
  # 桌面与开发包按用途维护，最终仍组成同一个有序软件清单。
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages =
    (import ./desktop.nix { inherit pkgs; })
    ++ (import ./development.nix { inherit pkgs; });

  programs.nix-ld.enable = true;
  # 阻止 uv 自动下载 Python；项目使用系统提供的 Python。
  environment.sessionVariables.UV_PYTHON_DOWNLOADS = "never";
}
