#!/bin/zsh
# dock-apps.txt の内容で Dock のアプリ一覧を作り直す
set -eu

script_dir=${0:A:h}
apps_file="$script_dir/dock-apps.txt"

if ! command -v dockutil >/dev/null 2>&1; then
  echo "==> dockutil をインストールします"
  brew install dockutil
fi

echo "==> Dock のアプリをすべて外します"
dockutil --remove all --no-restart

echo "==> dock-apps.txt のアプリを追加します"
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  app=${line/#\~/$HOME}
  if [[ -e "$app" ]]; then
    dockutil --add "$app" --no-restart >/dev/null
    echo "    + $app"
  else
    echo "    ! 見つからないためスキップ: $app" >&2
  fi
done < "$apps_file"

killall Dock
echo "完了"
