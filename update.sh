#!/bin/zsh
# インストール済みのアプリとシェルのプラグインをまとめて更新する
# Brewfile にないものは一覧を表示するだけで、削除はしない
set -eu

repo_dir=${0:A:h}
omz_dir="$HOME/.oh-my-zsh"
custom_dir="${ZSH_CUSTOM:-$omz_dir/custom}"

echo "==> Homebrew"
brew update
brew upgrade

echo "==> oh-my-zsh"
if [[ -d "$omz_dir" ]]; then
  # omz update と同じ呼び出し方（~/.zshrc を読まずに実行する）
  ZSH="$omz_dir" zsh -f "$omz_dir/tools/upgrade.sh"
else
  echo "    $omz_dir がないためスキップ" >&2
fi

echo "==> 外部プラグイン"
for dir in "$custom_dir"/plugins/*(N/); do
  [[ -d "$dir/.git" ]] || continue
  git -C "$dir" pull --ff-only --quiet
  echo "    更新しました: ${dir:t}"
done

echo "==> BrickLink Studio の Hidden Parts"
# 差分を表示するだけで上書きはしない。反映するときは studio/setup.sh を実行する
# studio/setup.sh でも同じ URL を使っている
hidden_parts_url='https://raw.githubusercontent.com/V14-LEGO/Misc.-LEGO-Tools/main/BrickLink%20Studio%20Tools/Hidden%20Parts/Until%202025/Hidden%20Parts'
hidden_parts="$HOME/.local/share/Stud.io/Buckets/Hidden Parts"
if [[ -f "$hidden_parts" ]]; then
  remote_hidden_parts=$(mktemp)
  # 取得に失敗したら set -e でここで止まる（空のファイルと比較しないため）
  curl -fsSL "$hidden_parts_url" -o "$remote_hidden_parts"
  # 差分があると diff は終了コード 1 を返すので、set -e で止まらないようにする
  if diff "$hidden_parts" "$remote_hidden_parts"; then
    echo "    最新です"
  else
    echo "    差分があります（< 手元 / > GitHub）。反映するときは zsh studio/setup.sh を実行してください"
  fi
  rm -f "$remote_hidden_parts"
else
  echo "    $hidden_parts がないためスキップ" >&2
fi

echo "==> Brewfile にないもの"
# yabai / skhd / dockutil はセットアップスクリプトで入れるので、ここに表示されてよい
# 消すときは brew uninstall で個別に削除する
# cleanup は --force なしでも確認で yes と答えると削除するので、標準入力を塞いで一覧の表示だけにする
# （確認を出せないと削除せずに終了コード 1 を返す）
brew bundle cleanup --file="$repo_dir/Brewfile" </dev/null || true

echo "完了"
