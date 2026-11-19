{ pkgs }:

with pkgs; [
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
]
