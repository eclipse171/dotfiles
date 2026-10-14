#!/bin/zsh
# Tailscale の経路が消えていたら tailscaled を再起動する
# root の launchd から 1 分ごとに実行される。home/setup.sh が /usr/local/libexec にコピーして登録する
# tailscaled は起動したときに経路を登録し、あとで経路表から消えても登録し直さないので、再起動して登録させる
set -u

export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
label=sh.brew.tailscale

# 停止中やログアウト中は経路がないのが正しいので、何もしない
tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"' || exit 0
self=$(tailscale ip -4 2>/dev/null) || exit 0

# 自分以外の端末を 1 つ選び、その IP への経路が Tailscale のインターフェースを向いているかを見る
peer=$(tailscale status 2>/dev/null | awk -v self="$self" '$1 ~ /^100\./ && $1 != self {print $1; exit}')
[[ -n "$peer" ]] || exit 0
ifc=$(ifconfig | awk -v self="$self" '/^[a-z]/ {name = $1} $1 == "inet" && $2 == self {sub(":", "", name); print name}')
via=$(route -n get "$peer" 2>/dev/null | awk '$1 == "interface:" {print $2}')
[[ -n "$ifc" && "$via" == "$ifc" ]] && exit 0

echo "$(date '+%Y/%m/%d %H:%M:%S') $peer への経路が ${via:-（なし）} を向いているため、tailscaled を再起動します"
launchctl kickstart -k "system/$label"
