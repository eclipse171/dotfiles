#!/bin/zsh
# 新しい Mac でセットアップ用のスクリプトをまとめて実行する
# 各スクリプトは再実行しても安全なので、途中で失敗したらもう一度実行すればよい
set -eu

repo_dir=${0:A:h}

# リポジトリ内のスクリプトを見出し付きで実行する
run() {
  echo
  echo "######## $1"
  zsh "$repo_dir/$1"
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
brew bundle --file="$repo_dir/Brewfile"

run ideamaker/install.sh

run macos/dock.sh
run git/setup.sh
run ssh/setup.sh
run ssh/keygen.sh
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
- BrickLink Studio を一度起動して終了し、zsh studio/setup.sh を再実行してデフォルトの色を設定する
- ウィジェットを配置する
- ログアウトして、キーボードと外観の設定を反映する
EOF
