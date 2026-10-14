#!/usr/bin/env python3
"""Claude Code の statusline。作業場所・コンテキスト・利用枠を表示し、利用枠を外部へ送る。

Claude Code から stdin に渡される JSON を読み、次のように 3 行で表示する:
    📂 ~/dev/my-project │ 🌿 main +12 -3
    🧠 ███████░░░░░░░░ 47% │ 💪 Opus 5.5 (xhigh)
    🕐 ██████░░░░░░░░░ 42% ↻16:04 │ 📅 ██░░░░░░░░░░░░░ 18%
1 行目は作業ディレクトリと Git のブランチ・未コミットの変更行数、2 行目はコンテキストの
使用率とモデル、3 行目は 5時間枠（↻ はリセット時刻）と週次枠の使用率。
利用枠（`rate_limits` の five_hour・seven_day）は、通知などに使えるよう外部の URL へ送る。
前回送信に成功した値から変わったときだけ、切り離した別プロセスで POST する
（Claude Code は次の更新が来ると実行中の statusline スクリプトを止めるため）。
本文は `rate_limits` と同じ形の JSON、認証は `Authorization: Bearer <トークン>`。
標準ライブラリだけを使い、macOS の python3（3.9 以上）で動く。

setup.sh が ~/.claude/statusline.py にリンクし、settings.json の statusLine から呼ぶ。

設定ファイル（送信する Mac だけに置く。リポジトリには入れない）:
  ~/.config/claude-usage-forward/config.json（環境変数 CLAUDE_USAGE_FORWARD_CONFIG で上書き可）
    {"url": "<送信先の URL>", "token": "<送信先の認証トークン>"}
    トークンを含むため `chmod 600` にしておく。ない・壊れている場合は送信せず、表示だけ行う。

状態ファイル: ~/.cache/claude-usage-forward/state.json（環境変数 CLAUDE_USAGE_FORWARD_STATE で上書き可）
    {"last_sent": <前回送信に成功した値 または null>, "last_failure_at": <Unix 秒 または null>}
    スクリプトが自動で作る。壊れていたら空の状態として扱う。
"""
from __future__ import annotations

import json
import math
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, tzinfo
from pathlib import Path
from typing import Any, NamedTuple, Optional

CONFIG_ENV = "CLAUDE_USAGE_FORWARD_CONFIG"
STATE_ENV = "CLAUDE_USAGE_FORWARD_STATE"
DEFAULT_CONFIG_PATH = "~/.config/claude-usage-forward/config.json"
DEFAULT_STATE_PATH = "~/.cache/claude-usage-forward/state.json"

# 送信に失敗してから次に送るまでの待ち時間（秒）
FAILURE_BACKOFF_SECONDS = 60
# POST のタイムアウト（秒）
REQUEST_TIMEOUT_SECONDS = 5.0

# 送信・表示の対象とする枠（statusline の入力 JSON のキー）
WINDOW_KEYS = ("five_hour", "seven_day")

# 表示のバーのマス数と、項目の区切り
BAR_WIDTH = 15
SEPARATOR = " │ "
# git の各コマンドのタイムアウト（秒）
GIT_TIMEOUT_SECONDS = 1


def _is_number(value: Any) -> bool:
    """bool を除く有限の数値か。"""
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _extract_window(raw: Any) -> Optional[dict[str, Any]]:
    """1 つの枠を検証して取り出す。不正なら None。"""
    if not isinstance(raw, dict):
        return None
    used = raw.get("used_percentage")
    resets_at = raw.get("resets_at")
    if not _is_number(used) or used < 0:
        return None
    if not _is_number(resets_at) or resets_at < 0:
        return None
    return {"used_percentage": float(used), "resets_at": int(resets_at)}


def extract_windows(rate_limits: Any) -> dict[str, dict[str, Any]]:
    """`rate_limits` 相当の dict から、値が正しい枠だけを取り出す（他のキーは無視する）。"""
    if not isinstance(rate_limits, dict):
        return {}
    payload: dict[str, dict[str, Any]] = {}
    for key in WINDOW_KEYS:
        window = _extract_window(rate_limits.get(key))
        if window is not None:
            payload[key] = window
    return payload


def extract_payload(data: Any) -> dict[str, dict[str, Any]]:
    """statusline の入力 JSON から送信用の payload を作る。"""
    if not isinstance(data, dict):
        return {}
    return extract_windows(data.get("rate_limits"))


def _round_half_up(value: float) -> int:
    """小数点以下を四捨五入する（round() の偶数丸めは使わない）。"""
    return int(math.floor(value + 0.5))


class GitInfo(NamedTuple):
    """作業ディレクトリの Git のブランチと、未コミットの変更行数。"""

    branch: str
    added: int
    deleted: int


class _GitError(Exception):
    """git を実行できなかった（git がない・タイムアウトなど）。"""


def _run_git(args: list[str], cwd: str) -> Optional[str]:
    """git を実行して stdout を返す。終了コードが 0 以外なら None、実行できなければ _GitError。"""
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=cwd,
            # statusline は頻繁に呼ばれるため、index.lock を取らないようにする
            env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except Exception as e:
        raise _GitError from e
    return result.stdout if result.returncode == 0 else None


def _count_numstat(output: str) -> tuple[int, int]:
    """`git diff --numstat` の出力から追加・削除の行数を数える（バイナリの行は数えない）。"""
    added = deleted = 0
    for line in output.splitlines():
        fields = line.split("\t", 2)
        if len(fields) == 3 and fields[0].isdecimal() and fields[1].isdecimal():
            added += int(fields[0])
            deleted += int(fields[1])
    return added, deleted


def get_git_info(cwd: str) -> Optional[GitInfo]:
    """Git の情報を返す。リポジトリでない・git を実行できない場合は None（例外は出さない）。"""
    try:
        branch = (_run_git(["symbolic-ref", "--short", "HEAD"], cwd) or "").strip()
        if not branch:
            commit = (_run_git(["rev-parse", "--short", "HEAD"], cwd) or "").strip()
            if not commit:
                return None
            branch = f"{commit} (detached)"
    except _GitError:
        return None
    added = deleted = 0
    try:
        for args in (["diff", "--numstat"], ["diff", "--cached", "--numstat"]):
            a, d = _count_numstat(_run_git(args, cwd) or "")
            added += a
            deleted += d
    except _GitError:
        return GitInfo(branch, 0, 0)  # ブランチだけ表示する
    return GitInfo(branch, added, deleted)


def _get(data: Any, *keys: str) -> Any:
    """入れ子の dict から値を取り出す。途中が dict でなければ None。"""
    for key in keys:
        if not isinstance(data, dict):
            return None
        data = data.get(key)
    return data


def _non_empty_str(value: Any) -> Optional[str]:
    return value if isinstance(value, str) and value else None


def current_dir(data: Any) -> Optional[str]:
    """作業ディレクトリ（workspace.current_dir、なければ cwd）。"""
    return _non_empty_str(_get(data, "workspace", "current_dir")) or _non_empty_str(_get(data, "cwd"))


def shorten_home(path: str, home: Optional[str] = None) -> str:
    """ホームディレクトリ配下なら先頭を `~` に短縮する。home が None なら実際のホーム。"""
    if home is None:
        home = os.path.expanduser("~")
    home = home.rstrip("/")
    if not home:
        return path
    if path == home:
        return "~"
    if path.startswith(home + "/"):
        return "~" + path[len(home):]
    return path


def format_bar(value: Any) -> str:
    """15 マスのバーと四捨五入した % を返す。値がない・不正ならバーを空にして `-`。"""
    if not _is_number(value) or value < 0:
        return f"{'░' * BAR_WIDTH} -"
    rounded = _round_half_up(value)
    filled = min(BAR_WIDTH, rounded * BAR_WIDTH // 100)
    return f"{'█' * filled}{'░' * (BAR_WIDTH - filled)} {rounded}%"


def _format_location(data: Any, git: Optional[GitInfo], home: Optional[str]) -> str:
    """1 行目: 作業ディレクトリと Git の情報。"""
    directory = current_dir(data)
    if directory is None:
        return "📂 -"
    text = f"📂 {shorten_home(directory, home)}"
    if git is not None:
        text += f"{SEPARATOR}🌿 {git.branch}"
        if git.added > 0:
            text += f" +{git.added}"
        if git.deleted > 0:
            text += f" -{git.deleted}"
    return text


def _format_model(data: Any) -> str:
    """2 行目: コンテキストの使用率とモデル。"""
    text = f"🧠 {format_bar(_get(data, 'context_window', 'used_percentage'))}"
    text += f"{SEPARATOR}💪 {_non_empty_str(_get(data, 'model', 'display_name')) or '-'}"
    effort = _non_empty_str(_get(data, "effort", "level"))
    if effort is not None:
        text += f" ({effort})"
    return text


def _format_limits(payload: dict[str, dict[str, Any]], tz: Optional[tzinfo]) -> str:
    """3 行目: 5時間枠（リセット時刻つき）と週次枠の使用率。"""
    five_hour = payload.get("five_hour")
    text = f"🕐 {format_bar(_get(five_hour, 'used_percentage'))}"
    if five_hour is not None:
        try:
            reset = datetime.fromtimestamp(five_hour["resets_at"], tz)
            text += f" ↻{reset:%H:%M}"
        except (OverflowError, OSError, ValueError):
            pass  # 表せない時刻なら ↻ を省く
    text += f"{SEPARATOR}📅 {format_bar(_get(payload.get('seven_day'), 'used_percentage'))}"
    return text


def format_status(
    data: Any,
    payload: dict[str, dict[str, Any]],
    git: Optional[GitInfo],
    tz: Optional[tzinfo] = None,
    home: Optional[str] = None,
) -> str:
    """表示する 3 行を組み立てる。tz が None ならローカル時刻で ↻ を表示する。"""
    return "\n".join(
        [_format_location(data, git, home), _format_model(data), _format_limits(payload, tz)]
    )


def should_send(payload: dict[str, Any], state: dict[str, Any], now: float) -> bool:
    """前回送信に成功した値から変わっていて、失敗直後の待ち時間でもなければ送る。"""
    if payload == state.get("last_sent"):
        return False
    last_failure_at = state.get("last_failure_at")
    return last_failure_at is None or now - last_failure_at >= FAILURE_BACKOFF_SECONDS


def config_path() -> Path:
    """設定ファイルのパス。"""
    return Path(os.path.expanduser(os.environ.get(CONFIG_ENV) or DEFAULT_CONFIG_PATH))


def state_path() -> Path:
    """状態ファイルのパス。"""
    return Path(os.path.expanduser(os.environ.get(STATE_ENV) or DEFAULT_STATE_PATH))


def _read_json_file(path: Path) -> Any:
    """JSON ファイルを読む。ない・壊れている場合は None。"""
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def load_config(path: Path) -> Optional[dict[str, str]]:
    """設定ファイルを読む。ない・壊れている・項目が欠けている場合は None。"""
    data = _read_json_file(path)
    if not isinstance(data, dict):
        return None
    url = data.get("url")
    token = data.get("token")
    if not isinstance(url, str) or not url.startswith(("http://", "https://")):
        return None
    if not isinstance(token, str) or not token:
        return None
    return {"url": url, "token": token}


def _empty_state() -> dict[str, Any]:
    return {"last_sent": None, "last_failure_at": None}


def load_state(path: Path) -> dict[str, Any]:
    """状態ファイルを読む。ない・壊れている場合は空の状態。"""
    data = _read_json_file(path)
    state = _empty_state()
    if not isinstance(data, dict):
        return state
    if isinstance(data.get("last_sent"), dict):
        state["last_sent"] = data["last_sent"]
    if _is_number(data.get("last_failure_at")):
        state["last_failure_at"] = data["last_failure_at"]
    return state


def save_state(path: Path, state: dict[str, Any]) -> None:
    """状態ファイルを書く（一時ファイルに書いてから置き換える）。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(state, f)
        os.replace(tmp_name, path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def post_payload(url: str, token: str, payload: dict[str, Any]) -> bool:
    """payload を POST する。2xx なら True、それ以外・通信の失敗は False。"""
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            return 200 <= response.status < 300
    except Exception:
        # HTTPError・URLError・タイムアウト・不正な URL などはすべて失敗として扱う
        return False


def run_send(payload_json: str, now: Optional[float] = None) -> int:
    """送信モード: payload を送り、結果を状態ファイルに記録する。"""
    try:
        payload = extract_windows(json.loads(payload_json))
    except ValueError:
        return 0
    config = load_config(config_path())
    if not payload or config is None:
        return 0
    ok = post_payload(config["url"], config["token"], payload)
    if now is None:
        now = time.time()
    path = state_path()
    state = load_state(path)
    if ok:
        state["last_sent"] = payload
        state["last_failure_at"] = None
    else:
        state["last_failure_at"] = int(now)
    save_state(path, state)
    return 0


def spawn_sender(payload: dict[str, Any]) -> None:
    """切り離した子プロセス（別セッション）で送信モードを起動する。"""
    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "--send", json.dumps(payload)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def _write_line(line: str) -> None:
    """表示を stdout に出す（ロケールが UTF-8 でなくても出せるようにする）。"""
    text = line + "\n"
    try:
        sys.stdout.write(text)
    except UnicodeEncodeError:
        sys.stdout.buffer.write(text.encode("utf-8"))
    sys.stdout.flush()


def run_statusline() -> int:
    """通常モード: stdin の JSON から表示し、必要なら送信プロセスを起動する。"""
    try:
        data = json.loads(getattr(sys.stdin, "buffer", sys.stdin).read())
    except (OSError, ValueError):
        return 0
    if not isinstance(data, dict):
        return 0
    payload = extract_payload(data)
    directory = current_dir(data)
    git = get_git_info(directory) if directory is not None else None
    _write_line(format_status(data, payload, git))
    if not payload or load_config(config_path()) is None:
        return 0
    try:
        if should_send(payload, load_state(state_path()), time.time()):
            spawn_sender(payload)
    except Exception:
        pass  # 送信できなくても表示は済んでいるので何もしない
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    """エントリポイント。どんな失敗でも終了コード 0 で終わる。"""
    args = sys.argv[1:] if argv is None else argv
    try:
        if args[:1] == ["--send"]:
            return run_send(args[1]) if len(args) >= 2 else 0
        return run_statusline()
    except Exception:
        return 0


if __name__ == "__main__":
    sys.exit(main())
