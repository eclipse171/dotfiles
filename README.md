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
   - Tailscale へのログイン（ブラウザ）
   入れるものを選びたいときは `zsh install.sh -i` で実行する。Brewfile の各アプリと各スクリプトについて、入れるかどうかを 1 つずつ聞かれる（Enter だけなら入れる）。Homebrew 本体は常に入る。
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
| `tailscale/` | Tailscale（VPN）のデーモンを root で常駐させてログインする。外から自宅の Mac に ssh するため。自宅の Mac は Key expiry を無効にする（[Appendix](#自宅の-mac-の-tailscale-の-key-expiry)） |
| `home/` | 外から ssh で入る自宅の Mac でだけ実行する設定（sshd の hardening とスリープの無効化）。`install.sh` からは実行しない（[自宅の Mac の設定](#自宅の-mac-の設定)） |
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

## 外から自宅の Mac に ssh する

自宅の Mac には Tailscale 経由で ssh する。自宅の Mac は鍵でしかログインできない（パスワードでのログインは無効）ので、新しい PC の公開鍵は、すでに入れる PC から、または自宅の Mac の前で登録する。

### 自宅の Mac の設定

自宅の Mac で `zsh home/setup.sh` を実行する（sudo のパスワードを求められる）。sshd とスリープはスクリプトが設定し、リモートログインと Tailscale は手動で設定する。再実行しても安全で、リモートログインが OFF のときや、`~/.ssh/authorized_keys` に公開鍵がないときは警告を表示する。

| 項目 | 設定 |
|---|---|
| リモートログイン | 手動。システム設定 → 一般 → 共有 → リモートログインを ON にし、アクセスは自分のユーザーだけにする |
| sshd | `home/setup.sh`。`/etc/ssh/sshd_config.d/100-hardening.conf` に、パスワードと root でのログインを無効にし、実行したユーザーだけを許可する設定を書く。同じ項目は先に読んだファイルが優先されるので、`100-macos.conf` より前に並ぶ名前にしている |
| スリープ | `home/setup.sh`。電源につないでいる間はスリープしない（`pmset -c sleep 0`）。ノート型はふたを閉めるとスリープするので、開けたまま置く |
| Tailscale | 手動。Key expiry を無効にする（[Appendix](#自宅の-mac-の-tailscale-の-key-expiry)） |

スクリプトは sshd の設定を書いたあと `sudo sshd -t` で構文を確認し、エラーなら元に戻す。sshd は接続のたびに起動するので、次の接続から設定が反映される。ssh でつないだまま実行したときは、別のウィンドウから鍵で入れることを確認するまで今の接続を閉じない。

### 新しい PC から入れるようにする

1. `install.sh` で ssh 鍵の作成と Tailscale へのログインを済ませておく
2. 新しい PC の公開鍵（`~/.ssh/id_ed25519.pub`）を、すでに入れる PC に AirDrop などで渡し、その PC で自宅の Mac に登録する

   ```sh
   ssh home 'cat >> ~/.ssh/authorized_keys' < id_ed25519.pub
   ```

   すでに入れる PC がないときは、自宅の Mac の前で `~/.ssh/authorized_keys` の末尾に公開鍵の 1 行を追記する。
3. 新しい PC の `~/.ssh/config` の末尾に追記する（ホストごとの設定はリポジトリではなく `~/.ssh/config` に書く）。IP は `tailscale status` で確認する

   ```
   Host home
     HostName <自宅の Mac の Tailscale IP>
     User <自宅の Mac のユーザー名>
   ```

4. `ssh home` で接続する。初回はホスト鍵のフィンガープリントを聞かれるので、すでに入れる PC で `ssh-keygen -lF <自宅の Mac の Tailscale IP>` を実行し、表示される値と同じなら `yes` と答える
5. 自宅以外のネットワーク（スマホのテザリングなど）からも `ssh home` で入れることを確認する

### PC を手放す・なくしたとき

その PC の公開鍵の行を、自宅の Mac の `~/.ssh/authorized_keys` から削除し、Tailscale の管理画面からそのマシンも削除する。
`keygen.sh` で作った鍵は、どの PC でもコメントが同じメールアドレスになるので、フィンガープリントで見分ける。

```sh
ssh home 'ssh-keygen -lf ~/.ssh/authorized_keys'   # 登録されている鍵の一覧
ssh-keygen -lf ~/.ssh/id_ed25519.pub              # その PC の鍵（手放す前に控えておく）
```

### つながらないとき

| 症状 | 確認すること |
|---|---|
| `Permission denied (publickey)` | 公開鍵が `authorized_keys` に登録されているか。`User` が正しいか |
| タイムアウトする | 両方の PC で Tailscale がつながっているか（`tailscale status`）。自宅の Mac がスリープしていないか、Key expiry が切れていないか |
| `Host key verification failed` | 入力を受け付けない環境（Claude Code の `!` など）で初めて接続した。普通のターミナルで実行する |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | 自宅の Mac を初期化したなどで、ホスト鍵が変わった。心当たりがあれば `ssh-keygen -R <自宅の Mac の Tailscale IP>` で古い鍵を消して接続し直す。なければ接続しない |

## Appendix

### 自宅の Mac の Tailscale の Key expiry

Tailscale の鍵にはデフォルトで有効期限（180日）があり、期限が切れると再ログインするまで tailnet から外れる。外出先から ssh で入る自宅の Mac で期限が切れると、自宅に戻るまで入れなくなる。

そのため、自宅の Mac は管理画面（ https://login.tailscale.com/admin/machines ）でそのマシンのメニューから **Disable key expiry** を選ぶ。持ち歩く Mac は、紛失したときに期限で無効になるほうが安全なので、期限を残したままにする。

### `admin:ssh_signing_key` スコープの warning

`ssh/keygen.sh` の実行中に次の warning が出ることがある。

    This API operation needs the "admin:ssh_signing_key" scope. To request it, run:  gh auth refresh -h github.com -s admin:ssh_signing_key

`gh ssh-key list` は認証用の鍵と署名用の鍵（SSH signing key）の両方を取得しようとする。ところが `keygen.sh` が `gh auth refresh` で追加するのは `admin:public_key` だけなので、署名用の鍵を取得できずに warning が出る。gh は認証用の鍵だけを一覧表示して処理を続けるので、鍵の確認と登録は正常に終わる。

コミットの署名に ssh 鍵は使っていないので、無視してよい。将来 ssh 署名を使う場合は、`gh auth refresh -h github.com -s admin:ssh_signing_key` でスコープを追加する。
