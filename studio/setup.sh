#!/bin/zsh
# BrickLink Studio の Hidden Parts とデフォルトの色を設定する
# Hidden Parts は V14-LEGO/Misc.-LEGO-Tools から取得する（update.sh で差分を確認できる）
set -eu

# update.sh でも同じ URL を使っている
hidden_parts_url='https://raw.githubusercontent.com/V14-LEGO/Misc.-LEGO-Tools/main/BrickLink%20Studio%20Tools/Hidden%20Parts/Until%202025/Hidden%20Parts'
hidden_parts="$HOME/.local/share/Stud.io/Buckets/Hidden Parts"
domain=com.BrickLink.Studio
palette_color_code=186

# Studio は終了時に設定を書き戻すので、起動中だと変更が消える
if pgrep -f 'Studio 2.0/Studio.app' >/dev/null; then
  echo "    ! Studio が起動中です。終了してから再実行してください" >&2
  exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

echo "==> Hidden Parts を取得します"
curl -fsSL "$hidden_parts_url" -o "$tmp_dir/hidden_parts"
if [[ -f "$hidden_parts" ]] && cmp -s "$tmp_dir/hidden_parts" "$hidden_parts"; then
  echo "    最新です: $hidden_parts"
else
  mkdir -p "${hidden_parts:h}"
  if [[ -e "$hidden_parts" ]]; then
    mv "$hidden_parts" "$hidden_parts.bak"
    echo "    既存のファイルを退避しました: $hidden_parts.bak"
  fi
  mv "$tmp_dir/hidden_parts" "$hidden_parts"
  echo "    + $hidden_parts"
fi

echo "==> デフォルトの色を設定します"
# BLStudioConfig_Json はライセンスの同意なども含む 1 つの JSON 文字列なので、色のキーだけを書き換える
if config=$(defaults read "$domain" BLStudioConfig_Json 2>/dev/null); then
  print -r -- "$config" >"$tmp_dir/config.json"
  plutil -replace PaletteColorCode -integer "$palette_color_code" "$tmp_dir/config.json"
  defaults write "$domain" BLStudioConfig_Json -string "$(plutil -convert json -o - "$tmp_dir/config.json")"
  echo "    PaletteColorCode: $palette_color_code"
else
  echo "    設定がまだないためスキップ。Studio を一度起動して終了してから再実行してください" >&2
fi

echo "完了"
