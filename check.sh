#!/bin/zsh
# リポジトリ内のスクリプトの構文をチェックする
# shellcheck は zsh に対応していないので、zsh -n（実行せずに構文だけを確認）を使う
set -u

repo_dir=${0:A:h}
failed=0

# チェックするファイル と 使うシェル
for file shell in \
  $(git -C "$repo_dir" ls-files --cached --others --exclude-standard '*.sh' | sed 's/$/ zsh/') \
  zsh/zshrc.local zsh \
  yabai/yabairc sh; do
  if "$shell" -n "$repo_dir/$file"; then
    echo "    ok: $file"
  else
    echo "    ! 構文エラー: $file" >&2
    failed=1
  fi
done

# Python のスクリプトは ast で構文だけを確認する（py_compile と違って .pyc を作らない）
for file in $(git -C "$repo_dir" ls-files --cached --others --exclude-standard '*.py'); do
  if python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' "$repo_dir/$file"; then
    echo "    ok: $file"
  else
    echo "    ! 構文エラー: $file" >&2
    failed=1
  fi
done

exit $failed
