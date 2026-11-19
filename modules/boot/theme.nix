{ pkgs }:

# 此目录下的背景、图标和布局来自仓库内的 assets/grub/。
pkgs.stdenv.mkDerivation {
  pname = "elegant-grub2-theme";
  version = "2025-03-25";
  src = ../../assets/grub/elegant-forest-window-left-dark;
  buildInputs = [
    pkgs.grub2
    pkgs.adwaita-fonts
  ];
  installPhase = ''
    themeDir="$out/grub/themes/Elegant-forest-window-left-dark"
    mkdir -p "$themeDir"
    cp "$src/background.jpg" "$src/theme.txt" "$src/"*.png "$themeDir/"
    grub-mkfont --name="Adwaita Sans" --size=18 \
      --range=32-126,183-183 \
      --output="$themeDir/adwaita-sans-18.pf2" \
      "${pkgs.adwaita-fonts}/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
    grub-mkfont --name="Adwaita Sans" --size=24 \
      --range=32-126,183-183 \
      --output="$themeDir/adwaita-sans-24.pf2" \
      "${pkgs.adwaita-fonts}/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
  '';
}
