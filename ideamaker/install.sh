#!/bin/zsh
# ideaMaker（Raise3D の 3D プリンタ用スライサー）を公式の DMG からインストールする
# Homebrew の cask は 2026-01-23 に無効化されたので Brewfile には書かない
# 新しいバージョンが出たら dmg_url を書き換える
set -eu

dmg_url='https://downcdn.raise3d.com/ideamaker/release/5.3.2/install_ideaMaker_5.3.2.8640-arm64.dmg'
app=/Applications/ideaMaker.app

if [[ -d "$app" ]]; then
  echo "    インストール済み: $app"
  exit 0
fi

# Apple Silicon 用の DMG なので、それ以外の Mac では入れない
if [[ "$(uname -m)" != arm64 ]]; then
  echo "    ! arm64 以外の Mac には対応していません。公式サイトからインストールしてください" >&2
  exit 1
fi

tmp_dir=$(mktemp -d)
mount_dir="$tmp_dir/mnt"
trap 'hdiutil detach -quiet "$mount_dir" 2>/dev/null || true; rm -rf "$tmp_dir"' EXIT

echo "==> ideaMaker をダウンロードします"
curl -fL --progress-bar "$dmg_url" -o "$tmp_dir/ideamaker.dmg"

echo "==> ideaMaker をインストールします"
# DMG に使用許諾が付いていて、同意しないとマウントできないので yes で同意する
# パイプの終了コードは最後の hdiutil のものになる（pipefail は使わない）ので、yes が SIGPIPE で止まっても失敗しない
mkdir -p "$mount_dir"
yes | PAGER=cat hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$tmp_dir/ideamaker.dmg" >/dev/null
ditto "$mount_dir/ideaMaker.app" "$app"
echo "    + $app"
