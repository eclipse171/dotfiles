#!/bin/zsh
# ~/.vimrc をリポジトリの vim/vimrc へのシンボリックリンクにする
set -eu

repo_dir=${0:A:h:h}
src="$repo_dir/vim/vimrc"
dest="$HOME/.vimrc"

source "$repo_dir/lib/link.sh"

echo "==> 設定ファイルをリンクします"
link_file "$src" "$dest"

echo "完了"
