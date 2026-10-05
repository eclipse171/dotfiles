#!/bin/zsh
# ssh 鍵（ed25519）を作成し、GitHub に公開鍵を登録する
# パスフレーズは ssh/config の UseKeychain によりキーチェーンに保存される
set -eu

ssh_dir="$HOME/.ssh"
key="$ssh_dir/id_ed25519"

echo "==> ssh 鍵"
if [[ -f "$key" ]]; then
  echo "    作成済み: $key"
else
  [[ -d "$ssh_dir" ]] || mkdir -m 700 "$ssh_dir"
  # コメントは git のメールアドレス、未設定ならユーザー名@ホスト名
  comment=$(git config --global --get user.email || true)
  comment=${comment:-$USER@$(scutil --get LocalHostName)}
  # パスフレーズを聞かれるので入力する（初回使用時にキーチェーンへ保存される）
  ssh-keygen -t ed25519 -C "$comment" -f "$key"
  echo "    + $key"
fi

echo "==> GitHub への登録"
if ! command -v gh >/dev/null; then
  echo "    gh が見つからないため登録をスキップしました" >&2
  echo "完了"
  exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
  # 鍵はこのスクリプトで登録するため、gh には作成・登録させない
  gh auth login --git-protocol ssh --skip-ssh-key --web
fi
# 鍵の一覧には admin:public_key の権限が必要なため、足りなければ追加する
if ! keys=$(gh ssh-key list 2>/dev/null); then
  gh auth refresh -h github.com -s admin:public_key
  keys=$(gh ssh-key list)
fi
# 公開鍵の 2 列目（鍵本体）で登録済みか判定する
body=$(awk '{print $2}' "$key.pub")
if [[ "$keys" == *"$body"* ]]; then
  echo "    登録済み: $key.pub"
else
  gh ssh-key add "$key.pub" --title "$(scutil --get ComputerName)"
  echo "    + $key.pub"
fi

echo "==> 接続確認"
# 成功しても終了コード 1 を返すため、結果の表示だけにする
ssh -T git@github.com || true

echo "==> このリポジトリの remote"
# 鍵がない状態で https で clone しているので、鍵を登録したあとで ssh に切り替える
repo_dir=${0:A:h:h}
url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)
if [[ "$url" == https://github.com/* ]]; then
  repo_path=${${url#https://github.com/}%.git}
  git -C "$repo_dir" remote set-url origin "git@github.com:$repo_path.git"
  echo "    $url -> git@github.com:$repo_path.git"
else
  echo "    変更なし: ${url:-origin がありません}"
fi

echo "完了"
