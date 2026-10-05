#!/bin/zsh
# ~/.config/ghostty/config をリポジトリの ghostty/config へのシンボリックリンクにする
set -eu

repo_dir=${0:A:h:h}

source "$repo_dir/lib/link.sh"

echo "==> 設定ファイルをリンクします"
link_file "$repo_dir/ghostty/config" "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"

echo "完了"
