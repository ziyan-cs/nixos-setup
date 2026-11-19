{ pkgs }:

with pkgs; [
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
]
