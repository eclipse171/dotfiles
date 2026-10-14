#!/bin/zsh
# 外から ssh で入る自宅の Mac で、sshd の hardening、電源につないでいる間のスリープの無効化、Tailscale の経路の監視の登録を行う
# install.sh からは実行しない。自宅の Mac でだけ、単独で実行する（sudo のパスワードを求められる）
# リモートログインの ON と Tailscale の Key expiry の無効化は手動で行う（README の「自宅の Mac の設定」）
set -eu

# 同じ項目は先に読んだファイルが優先されるので、100-macos.conf より前に並ぶ名前にする
conf=/etc/ssh/sshd_config.d/100-hardening.conf
desired="PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers $USER"

echo "==> sshd"
if [[ -f "$conf" && "$(cat "$conf" 2>/dev/null)" == "$desired" ]]; then
  echo "    設定済み: $conf"
else
  # 書き込んだ設定が sshd -t を通らなかったときに戻せるよう、既存のファイルを退避する
  had_conf=false
  if [[ -f "$conf" ]]; then
    sudo cp "$conf" "$conf.bak"
    had_conf=true
  fi
  print -r -- "$desired" | sudo tee "$conf" >/dev/null
  if ! sudo sshd -t; then
    if $had_conf; then
      sudo mv "$conf.bak" "$conf"
    else
      sudo rm "$conf"
    fi
    echo "    ! sshd -t でエラーになったため元に戻しました" >&2
    exit 1
  fi
  $had_conf && sudo rm "$conf.bak"
  echo "    + $conf"
  # sshd は接続のたびに起動するので、次の接続から反映される
  echo "    ssh でつないで実行したときは、別のウィンドウから鍵で入れることを確認するまで今の接続を閉じないこと"
fi
if [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
  echo "    ! ~/.ssh/authorized_keys に公開鍵がないため、外から ssh で入れません（README の「新しい PC から入れるようにする」）" >&2
fi

echo "==> スリープ（電源につないでいる間）"
# pmset -g custom は Battery Power と AC Power の項目を分けて表示する
ac_sleep=$(pmset -g custom | awk '/Battery Power/ {ac = 0} /AC Power/ {ac = 1} ac && $1 == "sleep" {print $2}')
if [[ "$ac_sleep" == 0 ]]; then
  echo "    設定済み: スリープしない"
else
  sudo pmset -c sleep 0
  echo "    + スリープしない（${ac_sleep:-不明} 分 -> 0）"
fi

echo "==> リモートログイン"
# リモートログインが ON なら、launchd が 22 番ポートで待ち受けている
if nc -z -G 1 127.0.0.1 22 >/dev/null 2>&1; then
  echo "    ON"
else
  # コマンドで ON にするにはターミナルにフルディスクアクセスが必要なので、設定アプリで行う
  echo "    ! OFF です。システム設定 → 一般 → 共有 → リモートログイン を ON にし、アクセスは自分のユーザーだけにしてください" >&2
fi

echo "==> Tailscale の経路の監視"
# root が実行するファイルは root の持ち物としてコピーし、このユーザーの権限では書き換えられないようにする
src_dir=${0:A:h}
label=local.dotfiles.tailscale-watchdog
script=/usr/local/libexec/tailscale-watchdog.sh
plist=/Library/LaunchDaemons/$label.plist
if cmp -s "$src_dir/tailscale-watchdog.sh" "$script"; then
  echo "    設定済み: $script"
else
  sudo install -d -o root -g wheel -m 755 "${script:h}"
  sudo install -o root -g wheel -m 755 "$src_dir/tailscale-watchdog.sh" "$script"
  echo "    + $script"
fi
if cmp -s "$src_dir/$label.plist" "$plist" && launchctl print "system/$label" >/dev/null 2>&1; then
  echo "    設定済み: $plist"
else
  sudo install -o root -g wheel -m 644 "$src_dir/$label.plist" "$plist"
  # 登録済みのときは、新しい plist を読み込ませるために一度外す
  sudo launchctl bootout "system/$label" 2>/dev/null || true
  sudo launchctl bootstrap system "$plist"
  echo "    + $plist（再起動したときは /var/log/tailscale-watchdog.log に記録する）"
fi

echo "完了"
