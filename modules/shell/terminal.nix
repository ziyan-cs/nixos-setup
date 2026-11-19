{ ... }:

{
  # Shell 与终端体验
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      directory = {
        style = "bold #B6CBE0";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      git_branch = {
        symbol = " ";
        style = "bold #8FB7C2";
        format = "[$symbol$branch]($style) ";
      };
      git_status = {
        style = "#CEB994";
        format = "([$all_status$ahead_behind]($style) )";
      };
      cmd_duration = {
        min_time = 2000;
        style = "#586576";
        format = "[took $duration]($style) ";
      };
      character = {
        success_symbol = "[❯](bold #93AEC8)";
        error_symbol = "[❯](bold #CC8F98)";
      };
    };
  };
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };
  programs.zoxide.enable = true;
}
