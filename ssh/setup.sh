#!/bin/zsh
# ~/.ssh/config の先頭にリポジトリの ssh/config を Include する行を追加する
# ホストごとの設定はリポジトリに置かず、~/.ssh/config にそのまま残す
set -eu

repo_dir=${0:A:h:h}
ssh_dir="$HOME/.ssh"
config="$ssh_dir/config"
include_line="Include \"$repo_dir/ssh/config\""

echo "==> ~/.ssh"
if [[ -d "$ssh_dir" ]]; then
  echo "    作成済み: $ssh_dir"
else
  mkdir -m 700 "$ssh_dir"
  echo "    + $ssh_dir"
fi

echo "==> ~/.ssh/config"
if [[ ! -f "$config" ]]; then
  (umask 077 && print -r -- "$include_line" > "$config")
  echo "    + $config"
elif grep -Fqx -- "$include_line" "$config"; then
  echo "    設定済み: $include_line"
else
  # Host 行より後ろに置くとそのホストだけの設定になるため、先頭に追加する
  cp "$config" "$config.backup"
  print -r -- "$include_line"$'\n'"$(<"$config")" > "$config"
  echo "    先頭に追加しました: $include_line（変更前: $config.backup）"
fi

echo "完了"
