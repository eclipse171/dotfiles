# MacBook Air セットアップ記録

macOS 27.0.1

## 使い方

新しい Mac では、次のコマンドで下のスクリプトを順番にすべて実行する。

```sh
zsh install.sh                # Homebrew をインストールし、下のスクリプトを上から順に実行
```

個別に実行する場合:

```sh
zsh macos/defaults.sh         # システム設定を適用（ログアウト後に反映）
brew bundle --file=Brewfile   # Brewfile のアプリをインストール
zsh macos/dock.sh             # Dock を dock-apps.txt の内容で作り直す
zsh git/setup.sh              # git/gitconfig を include し、全体の ignore をリンク（名前とメールアドレスは実行時に入力）
zsh ssh/setup.sh              # ~/.ssh/config の先頭でリポジトリの ssh/config（共通設定）を Include
zsh ssh/keygen.sh             # ssh 鍵を作成し、gh で GitHub に登録
zsh yabai/setup.sh            # yabai と skhd をインストールし、設定ファイルをリンクして起動
zsh zsh/setup.sh              # oh-my-zsh とプラグインをインストールし、~/.zshrc（zsh/zshrc.local の source を含む）と ~/.zprofile（Homebrew の shellenv）に設定
zsh vim/setup.sh              # ~/.vimrc をリポジトリの vim/vimrc へのシンボリックリンクにする
zsh ghostty/setup.sh          # ~/.config/ghostty/config をリポジトリの ghostty/config へのシンボリックリンクにする
zsh claude/setup.sh           # ~/.claude/CLAUDE.md と ~/.claude/settings.json をリポジトリの claude/ へのシンボリックリンクにする
```

## 作業ログ

### 2026-10-05

設定アプリで手動で行い、あとからスクリプトにまとめたもの。

| 作業 | スクリプト |
|---|---|
| ダークモードに設定 | `macos/defaults.sh` |
| アイコンとウィジェットのスタイルをダークに (`AppleIconAppearanceTheme = RegularDark`) | `macos/defaults.sh` |
| キーのリピート速度を最速に (`KeyRepeat = 2`) | `macos/defaults.sh` |
| リピート入力認識までの時間を最短に (`InitialKeyRepeat = 15`) | `macos/defaults.sh` |
| 修飾キー: Caps Lock → Control、左右の Control → Option | `macos/defaults.sh` |
| Dock から不要なアプリを削除 | `macos/dock.sh` + `macos/dock-apps.txt` |
| ウィジェットの表示設定（デスクトップ / ステージマネージャ） | `macos/defaults.sh` |
| メニューバーにディスプレイとキーボードの輝度を表示 | `macos/defaults.sh` |
| git のデフォルトブランチを main に (`init.defaultBranch = main`) | `git/setup.sh` |
| yabai と skhd の設定をリポジトリに追加し、`~/.config` へシンボリックリンクで配置 | `yabai/setup.sh` + `yabai/yabairc` + `skhd/skhdrc` |
| Dock に並べるアプリを Brewfile で自動インストール | `Brewfile` |
| oh-my-zsh にプラグイン (zsh-autosuggestions, zsh-syntax-highlighting) を追加し、`~/.zshrc` のテーマとプラグインを設定 | `zsh/setup.sh` |
| vimrc をリポジトリに追加し、`~/.vimrc` へシンボリックリンクで配置 | `vim/setup.sh` + `vim/vimrc` |
| Vimari（Safari 拡張）を Mac App Store から自動インストール | `Brewfile`（mas） |
| ssh の共通設定 (`AddKeysToAgent`, `UseKeychain`) をリポジトリで管理し、`~/.ssh/config` から Include（`~/.zshrc` の `ssh-add` は削除）| `ssh/setup.sh` + `ssh/config` |
| `~/.zprofile` に Homebrew の shellenv (`eval "$(/opt/homebrew/bin/brew shellenv)"`) を設定 | `zsh/setup.sh` |
| `~/.zshrc` から `zsh/zshrc.local`（`cd-icloud` と `~/.local/bin` の PATH）を source | `zsh/setup.sh` + `zsh/zshrc.local` |
| git と gh を Brewfile でインストール | `Brewfile` |
| git の共通設定 (`pull.rebase`, `push.autoSetupRemote`, `core.editor`) を include し、全体の ignore を `~/.config/git/ignore` にリンク | `git/setup.sh` + `git/gitconfig` + `git/gitignore_global` |
| ssh 鍵 (ed25519) を作成し、gh で GitHub に登録 | `ssh/keygen.sh` |
| iTerm2 と VS Code をやめて Ghostty に（Brewfile と Dock） | `Brewfile` + `macos/dock-apps.txt` |
| yabai でシステム設定などをタイル配置しないルール、skhd に Ghostty を開くキーとフロート切り替えを追加 | `yabai/yabairc` + `skhd/skhdrc` |
| Finder ですべての拡張子を表示 (`AppleShowAllExtensions`) | `macos/defaults.sh` |
| リンク処理を共通化し、スクリプトの構文チェックを追加 | `lib/link.sh` + `check.sh` + `.github/workflows/check.yml` |
| uv と pipx を Brewfile でインストール | `Brewfile` |
| ssh 鍵の登録後、https で clone したリポジトリの remote を ssh に切り替え | `ssh/keygen.sh` |
| zsh の履歴を 10 万件に増やし、重複と余分な空白を除く | `zsh/zshrc.local` |
| アプリとプラグインをまとめて更新するスクリプトを追加 | `update.sh` |
| Ghostty の設定（テーマ、Option を Alt に、Ctrl+` のドロップダウンなど）を追加し、`~/.config/ghostty` へシンボリックリンクで配置 | `ghostty/setup.sh` + `ghostty/config` |
| Claude Code の CLAUDE.md と settings.json をリポジトリに移し、`~/.claude` へシンボリックリンクで配置（iTerm2 用の `cc-status` の hooks は削除） | `claude/setup.sh` + `claude/` |
| `~/.zshrc` にあった `$icloud` を `zshrc.local` に移し、`cd-icloud` はそれを使う形に | `zsh/zshrc.local` |
| 構文チェックの対象に `zshrc.local` を追加 | `check.sh` |
| Vimari をやめて Vimium（Chrome 拡張）に。Vimari は Rosetta 2 が必要で、Rosetta 2 は廃止予定のため。mas も使わなくなったので削除 | `Brewfile` + `install.sh` + `update.sh` |
| Slidev 用に node と pnpm を Brewfile でインストール | `Brewfile` |
| ideaMaker を公式の DMG からインストールし、Dock の Fusion の次に追加 | `ideamaker/install.sh` + `install.sh` + `macos/dock-apps.txt` |

### 2026-10-07

| 作業 | スクリプト |
|---|---|
| Docker の実行環境として OrbStack を Brewfile でインストール（初回起動は手動） | `Brewfile` |

### 2026-10-08

| 作業 | スクリプト |
|---|---|
| fzf を Brewfile でインストールし、キー割り当て（Ctrl-R / Ctrl-T / Alt-C）を有効に | `Brewfile` + `zsh/zshrc.local` |
| README に手順として書いていた自宅の Mac の sshd の hardening とスリープの無効化を、スクリプトに（`install.sh` からは実行しない） | `home/setup.sh` |
| git の設定を追加（`fetch.prune`, `diff.algorithm = histogram`, `merge.conflictstyle = zdiff3`, `rerere.enabled`） | `git/gitconfig` |

## スクリプトにできないもの

- **ウィジェットの配置（どのウィジェットをどこに置くか）**
  `com.apple.notificationcenterui` のコンテナに保存されているが、macOS の保護 (TCC) で読み取れないうえ形式も非公開なので、手動で設定する。
- **yabai と skhd と Ghostty のアクセシビリティ権限**
  システム設定 → プライバシーとセキュリティ → アクセシビリティ で yabai と skhd を許可する。Ghostty も、どこからでも呼び出すキー（`global:` のキー）を使うために許可する。TCC で保護されているためスクリプトでは設定できない。
- **Autodesk Fusion のインストール**
  Homebrew の cask `autodesk-fusion` はあるが、ダウンロードしたインストーラー (Fusion Client Downloader) を起動するだけなので Brewfile には入れていない。公式サイトからインストーラーを入手して手動でインストールする（`~/Applications/Autodesk Fusion.app` に入る）。
- **OrbStack の初回起動**
  Brewfile でインストールしたあと、一度 OrbStack を起動して初期設定（Docker を選び、求められたら管理者パスワードを入力）を済ませる。これで `docker` コマンドが使えるようになる。
- **Vimium のインストール**
  Chrome Web Store の拡張は Homebrew では入れられないので、Chrome で https://chromewebstore.google.com/detail/vimium/dbepggeogbaibhgnhhndojpepiihcmeb を開いて追加する。
- **GitHub へのログイン**
  `ssh/keygen.sh` は未ログインなら `gh auth login --web` を実行するので、表示されたコードをブラウザで入力して認証する。ssh 鍵のパスフレーズも実行中に入力する。
