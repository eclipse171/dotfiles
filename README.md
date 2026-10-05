# dotfiles

macOS（Apple Silicon）の設定とアプリのインストールをまとめたリポジトリ。
作業の記録と、スクリプトにできない手動の作業は [SETUP_LOG.md](SETUP_LOG.md) にある。

## 新しい Mac でのセットアップ

1. リポジトリを取得して `install.sh` を実行する
   ssh 鍵はまだないので、https で clone する（鍵を登録したあと、remote は ssh に切り替わる）。初回の git ではコマンドライン・デベロッパツールのインストールを求められるので、インストールしてから再実行する。

   ```sh
   git clone https://github.com/eclipse171/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   zsh install.sh
   ```

   途中で次の入力を求められる。
   - git の名前とメールアドレス
   - ssh 鍵のパスフレーズ
   - GitHub へのログイン（ブラウザ）
2. 最後に表示される手動の作業を行う（アクセシビリティの許可など）

各スクリプトは再実行しても安全なので、途中で失敗したらもう一度 `zsh install.sh` を実行すればよい。
設定ファイルはシンボリックリンクか include で読み込んでいるので、リポジトリを置いた場所から動かさないこと。

## 構成

| パス | 内容 |
|---|---|
| `install.sh` | Homebrew をインストールし、下のスクリプトを順番に実行する |
| `Brewfile` | Homebrew でインストールするアプリ |
| `macos/defaults.sh` | システム設定（外観、キーボード、Finder、メニューバーなど） |
| `macos/dock.sh`, `macos/dock-apps.txt` | Dock に並べるアプリ |
| `git/` | git の共通設定（`~/.gitconfig` から include）と全体の ignore |
| `ssh/` | ssh の共通設定（`~/.ssh/config` から Include）と、鍵の作成・GitHub への登録 |
| `yabai/`, `skhd/` | タイル型ウィンドウマネージャとキー割り当て |
| `zsh/` | oh-my-zsh の設定と、`~/.zshrc` から読み込むエイリアス・PATH |
| `vim/` | vimrc |
| `ghostty/` | Ghostty（ターミナル）の設定 |
| `claude/` | Claude Code 本体のインストールと全体設定（`~/.claude/CLAUDE.md` と `settings.json`） |
| `studio/` | BrickLink Studio の Hidden Parts（[V14-LEGO/Misc.-LEGO-Tools](https://github.com/V14-LEGO/Misc.-LEGO-Tools/tree/main/BrickLink%20Studio%20Tools/Hidden%20Parts) から取得）とデフォルトの色。Studio を終了してから実行する |
| `ideamaker/` | ideaMaker（3D プリンタ用スライサー）を公式の DMG からインストールする。Homebrew の cask は無効化されているため |
| `lib/link.sh` | setup スクリプトで共通に使う、シンボリックリンクを作る関数 |
| `update.sh` | Homebrew、oh-my-zsh とプラグインの更新。Brewfile にないアプリの一覧と、Hidden Parts の GitHub との差分も表示する |
| `check.sh` | スクリプトの構文チェック（`zsh -n`）。push 時に GitHub Actions でも実行する |

## 設定を変えるとき

- リンクしているファイル（`vimrc`, `yabairc`, `skhdrc`, `gitconfig`, Ghostty の `config` など）はリポジトリのファイルを直接編集する
- Claude Code の `/config` などで変わった `settings.json` は、リポジトリの差分として現れるので、内容を確認してコミットする
- 変更後は `zsh check.sh` で構文を確認してからコミットする

## 更新するとき

`zsh update.sh` を実行する。最後に Brewfile にないアプリが表示されるので、使い続けるものは Brewfile に追加し、不要なものは `brew uninstall` で削除する。
Hidden Parts に差分が表示されたときは、Studio を終了してから `zsh studio/setup.sh` を実行すると GitHub の内容で置き換わる（手元のファイルは `Hidden Parts.bak` に退避される）。

## Appendix

### `admin:ssh_signing_key` スコープの warning

`ssh/keygen.sh` の実行中に次の warning が出ることがある。

    This API operation needs the "admin:ssh_signing_key" scope. To request it, run:  gh auth refresh -h github.com -s admin:ssh_signing_key

`gh ssh-key list` は認証用の鍵と署名用の鍵（SSH signing key）の両方を取得しようとする。ところが `keygen.sh` が `gh auth refresh` で追加するのは `admin:public_key` だけなので、署名用の鍵を取得できずに warning が出る。gh は認証用の鍵だけを一覧表示して処理を続けるので、鍵の確認と登録は正常に終わる。

コミットの署名に ssh 鍵は使っていないので、無視してよい。将来 ssh 署名を使う場合は、`gh auth refresh -h github.com -s admin:ssh_signing_key` でスコープを追加する。
