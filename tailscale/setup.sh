#!/bin/zsh
# Tailscale のデーモンを起動し、まだログインしていなければログインする
# デーモンは root で常駐するので、Mac にログインしていなくても接続が維持される
set -eu

if ! command -v tailscale >/dev/null 2>&1; then
  echo "    ! tailscale がありません。先に brew bundle --file=Brewfile を実行してください" >&2
  exit 1
fi

echo "==> tailscaled"
if tailscale status --json >/dev/null 2>&1; then
  echo "    起動済み"
else
  # sudo を付けて root のサービスにする（付けないとユーザーがログインしている間しか動かない）
  sudo brew services start tailscale
  # 起動直後はまだ接続できないので、最大10秒待つ
  for _ in {1..10}; do
    tailscale status --json >/dev/null 2>&1 && break
    sleep 1
  done
fi

echo "==> ログイン"
if tailscale status --json | grep -q '"BackendState": *"Running"'; then
  echo "    ログイン済み"
else
  # 表示される URL をブラウザで開いて認証する
  sudo tailscale up
fi

echo "    この Mac の Tailscale の IP: $(tailscale ip -4)"
echo "完了"
