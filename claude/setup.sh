#!/bin/zsh
# Claude Code をインストールし、全体設定をリポジトリのファイルへのシンボリックリンクにする
# ~/.claude のほかのファイル（履歴、claude.ai から同期される skills など）には触れない
set -eu

repo_dir=${0:A:h:h}

source "$repo_dir/lib/link.sh"

echo "==> Claude Code をインストールします"
# 公式のネイティブインストーラーは ~/.local/bin/claude に入れて、自動で更新する
if [[ -x "$HOME/.local/bin/claude" ]]; then
  echo "    インストール済み: $HOME/.local/bin/claude"
else
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo "==> 設定ファイルをリンクします"
# リポジトリのファイル と リンクを置く場所
for src dest in \
  "$repo_dir/claude/CLAUDE.md"     "$HOME/.claude/CLAUDE.md" \
  "$repo_dir/claude/settings.json" "$HOME/.claude/settings.json" \
  "$repo_dir/claude/hooks/guard-bash.sh" "$HOME/.claude/hooks/guard-bash.sh"; do
  link_file "$src" "$dest"
done

echo "完了"
