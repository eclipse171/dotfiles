#!/bin/zsh
# デフォルトシェルを zsh にし、oh-my-zsh とプラグインをインストールして ~/.zshrc に設定する
# ~/.zprofile では Homebrew の shellenv の行だけを管理する
# ~/.zshrc のうち ZSH_THEME と plugins の行だけを管理し、ほかの行には触れない
# ~/.zshrc の末尾に zsh/zshrc.local を source する行を 1 行だけ置く（エイリアスや PATH はそちらに書く）
# 以前このスクリプトで追加していた ssh-add の行は削除する（鍵の登録は ssh/config の AddKeysToAgent で行う）
set -eu

repo_dir=${0:A:h:h}
theme="robbyrussell"
# zsh-syntax-highlighting は最後に置く必要がある
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
# oh-my-zsh に含まれないプラグインの名前 と リポジトリ
external_plugins=(
  zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
  zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
)

zshrc="$HOME/.zshrc"
source_line="source \"$repo_dir/zsh/zshrc.local\""
zprofile="$HOME/.zprofile"
omz_dir="$HOME/.oh-my-zsh"
custom_dir="${ZSH_CUSTOM:-$omz_dir/custom}"

echo "==> デフォルトシェル"
current_shell=$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')
if [[ "$current_shell" == /bin/zsh ]]; then
  echo "    設定済み: $current_shell"
else
  chsh -s /bin/zsh
  echo "    $current_shell -> /bin/zsh（次回ログインから反映）"
fi

echo "==> oh-my-zsh"
if [[ -d "$omz_dir" ]]; then
  echo "    インストール済み: $omz_dir"
else
  # シェルの切り替えと起動はこのスクリプトで扱うので、インストーラーには行わせない
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

echo "==> 外部プラグイン"
for name url in $external_plugins; do
  dest="$custom_dir/plugins/$name"
  if [[ -d "$dest" ]]; then
    echo "    インストール済み: $name"
  else
    git clone --depth 1 "$url" "$dest"
    echo "    + $name"
  fi
done

echo "==> ~/.zprofile"
brew_bin=""
for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$candidate" ]]; then
    brew_bin=$candidate
    break
  fi
done
if [[ -z "$brew_bin" ]]; then
  echo "    ! Homebrew が見つからないためスキップ" >&2
else
  shellenv_line="eval \"\$($brew_bin shellenv)\""
  old_lines=()
  [[ -s "$zprofile" ]] && old_lines=("${(@f)$(<"$zprofile")}")
  new_lines=()
  added=false
  for line in "${old_lines[@]}"; do
    case "$line" in
      # brew shellenv の行と、その出力を展開して書いた行は、標準の形の 1 行にまとめる
      *"brew shellenv"* | "eval 'export HOMEBREW_PREFIX="*)
        $added && continue
        line=$shellenv_line
        added=true ;;
    esac
    new_lines+=("$line")
  done
  $added || new_lines+=("$shellenv_line")

  new_content=${(F)new_lines}
  if [[ -f "$zprofile" && "$new_content" == "$(<"$zprofile")" ]]; then
    echo "    変更なし"
  else
    [[ -f "$zprofile" ]] && cp "$zprofile" "$zprofile.backup"
    print -r -- "$new_content" > "$zprofile"
    echo "    設定しました: $shellenv_line"
  fi
fi

echo "==> ~/.zshrc"
if [[ ! -f "$zshrc" ]]; then
  echo "    $zshrc がありません" >&2
  exit 1
fi

new_lines=()
for line in "${(@f)$(<"$zshrc")}"; do
  case "$line" in
    ZSH_THEME=*)
      line="ZSH_THEME=\"$theme\"" ;;
    plugins=\(*\))
      line="plugins=(${(j: :)plugins})" ;;
    plugins=\(*)
      # 複数行で書かれた plugins は書き換えると壊れるおそれがあるため触れない
      echo "    ! plugins が複数行で書かれているため書き換えをスキップ: 手動で plugins=(${(j: :)plugins}) にしてください" >&2 ;;
    ssh-add*)
      continue ;;
    # zshrc.local を読む行はいったん取り除き、末尾に標準の形で 1 行だけ追加する
    source*zshrc.local*)
      continue ;;
  esac
  new_lines+=("$line")
done
new_lines+=("$source_line")

new_content=${(F)new_lines}
if [[ "$new_content" == "$(<"$zshrc")" ]]; then
  echo "    変更なし"
else
  # 変更がないときは退避しないので、再実行しても直前のバックアップは上書きされない
  cp "$zshrc" "$zshrc.backup"
  print -r -- "$new_content" > "$zshrc"
  echo "    更新しました（変更前: $zshrc.backup）"
fi

echo "完了"
echo "新しいターミナルを開くか exec zsh で反映してください"
