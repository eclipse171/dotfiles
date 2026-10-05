#!/bin/zsh
# yabai と skhd をインストールし、設定ファイルをリポジトリへのシンボリックリンクにする
set -eu

repo_dir=${0:A:h:h}

source "$repo_dir/lib/link.sh"

echo "==> yabai と skhd をインストールします"
brew tap asmvik/formulae
# 旧 tap (koekeishiya/formulae) で入れたものと衝突するので、インストール済みなら何もしない
for cmd in yabai skhd; do
  if brew list "$cmd" >/dev/null 2>&1; then
    echo "    インストール済み: $cmd"
  else
    brew install "asmvik/formulae/$cmd"
  fi
done

echo "==> 設定ファイルをリンクします"
# リポジトリのファイル と リンクを置く場所
for src dest in \
  "$repo_dir/yabai/yabairc" "$HOME/.config/yabai/yabairc" \
  "$repo_dir/skhd/skhdrc"   "$HOME/.config/skhd/skhdrc"; do
  link_file "$src" "$dest"
done

echo "==> サービスを起動します"
# 起動中なら設定を読み直すために再起動する
for cmd in yabai skhd; do
  if pgrep -x "$cmd" >/dev/null; then
    "$cmd" --restart-service
  else
    "$cmd" --start-service
  fi
done

echo "完了"
echo "初回はシステム設定 → プライバシーとセキュリティ → アクセシビリティ で yabai と skhd を許可してください"
