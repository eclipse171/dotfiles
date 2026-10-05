#!/bin/zsh
# git の全体設定を適用する
# ~/.gitconfig からリポジトリの git/gitconfig を include.path で読み込ませる
# ~/.config/git/ignore をリポジトリの git/gitignore_global へのシンボリックリンクにする
set -eu

repo_dir=${0:A:h:h}
gitconfig="$repo_dir/git/gitconfig"

source "$repo_dir/lib/link.sh"

echo "==> 共通の設定"
# ~/.gitconfig に直接書かず、リポジトリのファイルを読み込ませる
if git config --global --get-all include.path | grep -qxF "$gitconfig"; then
  echo "    設定済み: $gitconfig"
else
  git config --global --add include.path "$gitconfig"
  echo "    + include.path = $gitconfig"
fi

echo "==> 全体の ignore"
# git は core.excludesfile がなければ ~/.config/git/ignore を読む
link_file "$repo_dir/git/gitignore_global" "${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"

echo "==> 作成者の情報"
# 個人情報をリポジトリに置かないため、実行時に入力する
# 設定済みの場合は Enter でそのまま使う
for key label in user.name "名前" user.email "メールアドレス"; do
  current=$(git config --global --get "$key" || true)
  read "value?    ${label} [${current}]: "
  value=${value:-$current}
  if [[ -n "$value" ]]; then
    git config --global "$key" "$value"
  else
    echo "    ${label}が空のため設定をスキップしました" >&2
  fi
done

echo "完了"
