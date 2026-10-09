#!/bin/bash
# Claude Code の PreToolUse hook。Bash コマンドを検査して、危険な操作を止める
# - deny（実行させない）: main/master への push、force push、rm -rf 系、.env や secrets/ に触れるコマンド
# - ask（確認を求める）: 作業内容を消す git 操作（reset --hard、clean -f、checkout --、branch -D など）
# パーミッションルールは前方一致なので書き方の違いですり抜けるが、ここでは引数を見て判定する

if ! command -v jq >/dev/null 2>&1; then
  echo "guard-bash: jq が見つからないため、安全のためコマンドをブロックしました" >&2
  exit 2
fi

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
dir=$(jq -r '.cwd // ""' <<<"$input")

deny() {
  echo "guard-bash: $1" >&2
  exit 2
}

ask_reason=""
ask() {
  [[ -z $ask_reason ]] && ask_reason=$1
}

# コマンド文字列をシェルの規則でおおまかに解析して、コマンドごとのトークン列を segs に入れる
# トークンは SEP で区切った1つの文字列にする
# - クォートの中は1つのトークンにする（コミットメッセージの中身をコマンドと誤認しないため）
# - ヒアドキュメントの本文は読み飛ばす
# - $(...) と `...` の中は、クォートの中にあっても別のコマンドとして解析する
SEP=$'\x1f'
segs=()

flush() {
  ((has)) && seg+=$tok$SEP
  tok="" has=0
}

end_seg() {
  flush
  [[ -n $seg ]] && segs+=("$seg")
  seg=""
}

parse() {
  local s=$1 n=${#1} i=0 j c q="" tok="" has=0 seg="" inner depth d h line rest strip
  local -a heredocs=()
  while ((i < n)); do
    c=${s:i:1}
    if [[ $q == "'" ]]; then
      if [[ $c == "'" ]]; then q=""; else tok+=${c/$'\n'/ }; fi
    elif [[ $q == '"' ]]; then
      if [[ $c == '\' ]]; then
        i=$((i + 1))
        tok+=${s:i:1}
      elif [[ $c == '"' ]]; then
        q=""
      elif [[ $c == '`' ]]; then
        j=$((i + 1))
        while ((j < n)) && [[ ${s:j:1} != '`' ]]; do j=$((j + 1)); done
        parse "${s:i+1:j-i-1}"
        i=$j
      elif [[ $c == '$' && ${s:i+1:1} == '(' ]]; then
        depth=1 j=$((i + 2))
        while ((j < n && depth > 0)); do
          case ${s:j:1} in
            '(') depth=$((depth + 1)) ;;
            ')') depth=$((depth - 1)) ;;
          esac
          j=$((j + 1))
        done
        parse "${s:i+2:j-i-3}"
        i=$((j - 1))
      else
        tok+=${c/$'\n'/ }
      fi
    else
      case $c in
        '\')
          i=$((i + 1))
          if [[ ${s:i:1} != $'\n' ]]; then tok+=${s:i:1}; has=1; fi
          ;;
        ' ' | $'\t') flush ;;
        "'" | '"') q=$c has=1 ;;
        ';' | '&' | '|' | '(' | ')' | '`') end_seg ;;
        $'\n')
          end_seg
          # 前の行で始まったヒアドキュメントの本文を、終端の行まで読み飛ばす
          for h in "${heredocs[@]}"; do
            strip=${h%%:*} d=${h#*:}
            while ((i < n)); do
              rest=${s:i+1}
              line=${rest%%$'\n'*}
              i=$((i + 1 + ${#line}))
              ((strip)) && line=${line#"${line%%[!$'\t']*}"}
              [[ $line == "$d" ]] && break
            done
          done
          heredocs=()
          ;;
        '<')
          if [[ ${s:i:3} == '<<<' ]]; then
            tok+='<<<' has=1
            i=$((i + 2))
          elif [[ ${s:i:2} == '<<' ]]; then
            # ヒアドキュメントの終端文字列を覚えておく（<<- は行頭のタブを無視する）
            flush
            i=$((i + 2)) strip=0 d=""
            [[ ${s:i:1} == - ]] && strip=1 i=$((i + 1))
            while [[ ${s:i:1} == ' ' || ${s:i:1} == $'\t' ]]; do i=$((i + 1)); done
            while ((i < n)); do
              c=${s:i:1}
              case $c in
                ' ' | $'\t' | $'\n' | ';' | '&' | '|' | '<' | '>' | '(' | ')') break ;;
                "'" | '"' | '\') ;;
                *) d+=$c ;;
              esac
              i=$((i + 1))
            done
            heredocs+=("$strip:$d")
            i=$((i - 1))
          else
            tok+=$c has=1
          fi
          ;;
        *) tok+=$c has=1 ;;
      esac
    fi
    i=$((i + 1))
  done
  end_seg
}

parse "$cmd"

for seg in "${segs[@]}"; do
  IFS=$SEP read -ra toks <<<"$seg"
  ((${#toks[@]} == 0)) && continue

  # cd した先で git push するケースに備えて、ディレクトリを追う
  if [[ ${toks[0]} == cd && -n ${toks[1]} ]]; then
    case ${toks[1]} in
      /*) dir=${toks[1]} ;;
      "~"*) dir=$HOME${toks[1]#\~} ;;
      *) dir=$dir/${toks[1]} ;;
    esac
    continue
  fi

  # .env と secrets/ を参照するコマンド
  for t in "${toks[@]}"; do
    if [[ $t =~ (^|[/=\<\>])\.env(\.[A-Za-z0-9_.-]+)?$ || $t =~ (^|/)secrets(/|$) ]]; then
      deny ".env や secrets/ に触れるコマンドは禁止です: $t"
    fi
  done

  for i in "${!toks[@]}"; do
    t=${toks[$i]}

    # rm の再帰かつ強制削除（-rf, -fr, -Rf, -r -f, --recursive --force など）
    if [[ $t == rm || $t == */rm ]]; then
      recursive=0 force=0
      for a in "${toks[@]:i+1}"; do
        [[ $a =~ ^-[^-]*[rR] || $a == --recursive ]] && recursive=1
        [[ $a =~ ^-[^-]*f || $a == --force ]] && force=1
      done
      ((recursive && force)) && deny "rm の再帰かつ強制削除は禁止です"
    fi

    [[ $t == git ]] || continue
    # git のサブコマンドを探す（-C dir などのグローバルオプションは飛ばす）
    j=$((i + 1))
    while [[ ${toks[$j]} == -* ]]; do
      case ${toks[$j]} in
        -C) dir=${toks[$((j + 1))]}; j=$((j + 2)) ;;
        -c) j=$((j + 2)) ;;
        *) j=$((j + 1)) ;;
      esac
    done
    sub=${toks[$j]}
    args=("${toks[@]:j+1}")

    case $sub in
      push)
        positional=0
        for a in "${args[@]}"; do
          [[ $a =~ ^--force || $a =~ ^-[^-]*f || $a == +* ]] && deny "force push は禁止です"
          [[ $a == --all || $a == --mirror ]] && deny "git push $a は禁止です"
          [[ $a =~ ^([^:]*:)?(refs/heads/)?(main|master)$ ]] && deny "main/master への push は禁止です"
          [[ $a != -* ]] && positional=$((positional + 1))
        done
        # リモート名だけ、または引数なしの push は、今いるブランチが送られる
        if ((positional <= 1)); then
          branch=$(git -C "${dir:-.}" branch --show-current 2>/dev/null)
          [[ $branch == main || $branch == master ]] && deny "main/master ブランチからの push は禁止です"
        fi
        ;;
      reset)
        [[ " ${args[*]} " == *" --hard "* ]] && ask "git reset --hard は未コミットの変更を消します"
        ;;
      clean)
        for a in "${args[@]}"; do
          [[ $a =~ ^-[^-]*f || $a == --force ]] && ask "git clean -f は未追跡ファイルを消します"
        done
        ;;
      checkout)
        for a in "${args[@]}"; do
          [[ $a == -- || $a == . || $a == -f || $a == --force ]] && ask "git checkout $a は作業ツリーの変更を消すことがあります"
        done
        ;;
      restore)
        [[ " ${args[*]} " != *" --staged "* && " ${args[*]} " != *" -S "* ]] && ask "git restore は作業ツリーの変更を消します"
        ;;
      branch)
        for a in "${args[@]}"; do
          [[ $a =~ ^-[^-]*D || $a == --force ]] && ask "git branch -D はマージされていないブランチも消します"
        done
        ;;
      stash)
        [[ ${args[0]} == drop || ${args[0]} == clear ]] && ask "git stash ${args[0]} は stash を消します"
        ;;
    esac
  done
done

if [[ -n $ask_reason ]]; then
  jq -n --arg r "$ask_reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
fi
exit 0
