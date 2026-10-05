# setup スクリプトから source して使う関数
# 使い方: source "$repo_dir/lib/link.sh"

# dest を src へのシンボリックリンクにする
# 既存のファイルは上書きせずに dest.bak へ退避する
link_file() {
  local src=$1 dest=$2
  mkdir -p "${dest:h}"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    echo "    リンク済み: $dest"
    return
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "$dest.bak"
    echo "    既存のファイルを退避しました: $dest.bak"
  fi
  ln -s "$src" "$dest"
  echo "    + $dest -> $src"
}
