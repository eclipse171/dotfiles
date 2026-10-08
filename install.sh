#!/bin/zsh
# 新しい Mac でセットアップ用のスクリプトをまとめて実行する
# 各スクリプトは再実行しても安全なので、途中で失敗したらもう一度実行すればよい
# 使い方: zsh install.sh [-i|--interactive]
#   -i を付けると、Brewfile の各行と各スクリプトについて、入れるかどうかを 1 つずつ聞く
set -eu

repo_dir=${0:A:h}

interactive=0
case "${1:-}" in
  -i|--interactive) interactive=1 ;;
  "") ;;
  *)
    echo "使い方: zsh install.sh [-i|--interactive]" >&2
    exit 1
    ;;
esac

# 対話モードなら [Y/n] で聞き、Enter だけなら Yes とする。対話モードでなければ常に Yes
ask() {
  (( interactive )) || return 0
  local reply
  read -r "reply?$1 [Y/n] " || return 1
  [[ -z "$reply" || "$reply" == [Yy]* ]]
}

# リポジトリ内のスクリプトを見出し付きで実行する
# 2 つ目の引数は、スクリプトが必要とするコマンド。対話モードでそれを入れなかったときはスキップする
run() {
  local script=$1 required=${2:-}
  echo
  echo "######## $script"
  if (( interactive )); then
    if [[ -n "$required" ]] && ! command -v "$required" >/dev/null 2>&1; then
      echo "    $required がないためスキップしました"
      return
    fi
    # 説明にはスクリプトの 2 行目のコメントを使う
    if ! ask "    $(sed -n '2s/^# *//p' "$repo_dir/$script")"; then
      echo "    スキップしました"
      return
    fi
  fi
  zsh "$repo_dir/$script"
}

echo "######## Homebrew"
if command -v brew >/dev/null 2>&1; then
  echo "    インストール済み: $(command -v brew)"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# インストール直後は PATH に入っていないので、このスクリプト内で brew を使えるようにする
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done

run macos/defaults.sh

echo
echo "######## Brewfile"
brewfile="$repo_dir/Brewfile"
if (( interactive )); then
  # 選んだ行だけを一時的な Brewfile に書き出す
  brewfile=$(mktemp)
  trap 'rm -f "$brewfile"' EXIT
  # read で標準入力から答えを読むので、Brewfile は先に配列へ読み込んでおく
  for line in "${(@f)$(<"$repo_dir/Brewfile")}"; do
    [[ "$line" == (brew|cask)\ * ]] || continue
    if ask "    $line"; then
      print -r -- "$line" >>"$brewfile"
    fi
  done
fi
if [[ -s "$brewfile" ]]; then
  brew bundle --file="$brewfile"
else
  echo "    選んだものがないためスキップしました"
fi

run ideamaker/install.sh

run macos/dock.sh
run git/setup.sh
run ssh/setup.sh
run ssh/keygen.sh
run tailscale/setup.sh tailscale
run yabai/setup.sh
run zsh/setup.sh
run vim/setup.sh
run ghostty/setup.sh
run claude/setup.sh
run studio/setup.sh

cat <<'EOF'

######## すべて完了しました。以下は手動で行ってください
- システム設定 → プライバシーとセキュリティ → アクセシビリティ で yabai と skhd と Ghostty を許可する
- Chrome で Vimium をインストールする（https://chromewebstore.google.com/detail/vimium/dbepggeogbaibhgnhhndojpepiihcmeb）
- Autodesk Fusion を公式サイトからインストールする
- OrbStack を一度起動して初期設定する（Docker を選び、求められたら管理者パスワードを入力）
- 外から ssh で入る自宅の Mac は、Tailscale の管理画面（https://login.tailscale.com/admin/machines）で Disable key expiry を選ぶ
- BrickLink Studio を一度起動して終了し、zsh studio/setup.sh を再実行してデフォルトの色を設定する
- ウィジェットを配置する
- ログアウトして、キーボードと外観の設定を反映する
EOF
