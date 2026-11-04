#!/bin/sh
# Tests for the butler guard: butler/scripts/guard.sh (zh) and en/butler/scripts/guard.sh (en).
# Feeds sample PreToolUse inputs to both copies and checks allow / ask.
#
#   sh tests/test-guard.sh
#   GUARD_SHELL="bash --posix" sh tests/test-guard.sh     # run the guard under another shell
#
# Needs only sh and awk, like the guard itself.

set -u
repo=$(cd "$(dirname "$0")/.." && pwd -P)
shell=${GUARD_SHELL:-sh}
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t guardtest) || exit 1
trap 'rm -rf "$tmp"' EXIT INT TERM
tmp=$(cd "$tmp" && pwd -P)

root=$tmp/proj
B=$root/.claude/butler
O=$tmp/outside
WT=$tmp/wt
mkdir -p "$B/工单" "$root/src" "$root/sub" "$O" "$WT/.claude/butler"
ln -s "$O" "$B/link"
ln -s "$O/target.md" "$B/file-link.md"
ln -s "$B" "$tmp/butler-alias"

pass=0 fail=0

jstr() {
  printf '%s' "$1" | awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); if (NR > 1) printf "\\n"; printf "%s", $0 }'
}

# run GUARD EXPECT NAME JSON
run() {
  out=$(printf '%s' "$4" | CLAUDE_PROJECT_DIR=$root $shell "$1" 2>&1)
  rc=$?
  case $out in
    '') got=allow ;;
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"'*'"}}') got=ask ;;
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"'*'"}}') got=deny ;;
    *) got="unexpected output: $out" ;;
  esac
  if [ "$rc" -eq 0 ] && [ "$got" = "$2" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL [%s] %s: expected %s, got %s (exit %s)\n' "$lang" "$3" "$2" "$got" "$rc"
  fi
}

input() { # TOOL KEY VALUE [CWD] [EXTRA_FIELDS]   (permission mode from $MODE, default "default")
  printf '{"session_id":"t","transcript_path":"/x/t.jsonl","cwd":"%s","permission_mode":"'"${MODE:-default}"'",%s"hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"%s":"%s","description":"d"},"tool_use_id":"toolu_1"}' \
    "${4:-$root}" "${5:-}" "$1" "$2" "$(jstr "$3")"
}

cases() { # GUARD
  g=$1
  # --- Write / Edit / MultiEdit / NotebookEdit ---
  run "$g" allow "Write: absolute path in .claude/butler" "$(input Write file_path "$B/台账.md")"
  run "$g" allow "Write: new subfolder in .claude/butler" "$(input Write file_path "$B/契约/C-001.md")"
  run "$g" allow "Write: relative path from project root" "$(input Write file_path ".claude/butler/ledger.md")"
  run "$g" allow "Write: relative path with .. from a subfolder" "$(input Write file_path "../.claude/butler/x.md" "$root/sub")"
  run "$g" allow "Write: .. that stays inside" "$(input Write file_path "$B/工单/../台账.md")"
  run "$g" allow "Write: symlink from outside into .claude/butler" "$(input Write file_path "$tmp/butler-alias/x.md")"
  run "$g" allow "Write: main .claude/butler while cwd is a worktree" "$(input Write file_path "$B/T-001.md" "$WT")"
  run "$g" ask "Write: project code, absolute" "$(input Write file_path "$root/src/app.js")"
  run "$g" ask "Write: project code, relative" "$(input Write file_path "src/app.js")"
  run "$g" ask "Write: .. climbing out of .claude/butler" "$(input Write file_path "$B/../settings.json")"
  run "$g" ask "Write: look-alike folder .claude/butler-old" "$(input Write file_path "$root/.claude/butler-old/x.md")"
  run "$g" ask "Write: through a symlinked folder that points outside" "$(input Write file_path "$B/link/x.md")"
  run "$g" ask "Write: through a symlinked file that points outside" "$(input Write file_path "$B/file-link.md")"
  run "$g" ask "Write: the worktree's own .claude/butler copy" "$(input Write file_path ".claude/butler/T-001.md" "$WT")"
  run "$g" ask "Write: home directory via ~" "$(input Write file_path "~/notes.md")"
  run "$g" ask "Write: outside, content mentions an inside path" \
    "{\"cwd\":\"$root\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$root/src/a.js\",\"content\":\"{\\\"file_path\\\":\\\"$B/x.md\\\"}\"}}"
  run "$g" ask "Edit: outside" "$(input Edit file_path "$root/src/app.js")"
  run "$g" allow "Edit: inside" "$(input Edit file_path "$B/台账.md")"
  run "$g" allow "MultiEdit: inside" "$(input MultiEdit file_path "$B/工单/T-001.md")"
  run "$g" ask "NotebookEdit: outside" "$(input NotebookEdit notebook_path "$root/analysis.ipynb")"
  run "$g" ask "Write: the .claude/butler folder itself" "$(input Write file_path "$B")"
  run "$g" allow "Write: path sent with \\u escapes (inside)" \
    "{\"cwd\":\"$root\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$B/\\u5de5\\u5355/T-001.md\"}}"
  run "$g" ask "Write: path sent with \\u escapes (outside)" \
    "{\"cwd\":\"$root\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$root/src/\\u4e2d.js\"}}"
  run "$g" ask "Bash: git commit with an escaped emoji message" \
    "{\"cwd\":\"$root\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m \\\"\\ud83d\\ude00\\\"\"}}"
  run "$g" ask "Write: no file_path" "{\"cwd\":\"$root\",\"tool_name\":\"Write\",\"tool_input\":{\"content\":\"x\"}}"

  # --- Bash: allowed read-only commands ---
  for c in \
    'git status' \
    'git status --short' \
    "git -C $WT status --short" \
    'git diff --stat' \
    'git diff --name-only main...HEAD' \
    "git -C '$WT' diff --name-only main...HEAD" \
    'git log --oneline -10' \
    'git --no-pager log -3 --format="%h %s"' \
    'git branch' \
    'git branch -a -vv' \
    'git branch --merged main' \
    'git worktree list' \
    'ls -la .claude/butler' \
    'cat .claude/butler/台账.md' \
    'cat ".claude/butler/a b.md"' \
    'head -20 .claude/butler/台账.md | wc -l' \
    'git status 2>&1 | tail -5' \
    'ls .claude/butler/工单 2>/dev/null' \
    "cd $WT && git status" \
    'ls "a > b; rm c"' \
    'ls # ; rm -rf x' \
    'git status; echo ---; git log -1' \
    'mkdir -p .claude/butler/工单 .claude/butler/契约' \
    'mkdir .claude/butler' \
    'cp ~/.claude/skills/butler/templates/台账.md .claude/butler/' \
    'cp -r templates/x .claude/butler/x' \
    "cd ~/.claude/skills/butler/templates && cp ledger.md rules.md $B/" \
    "cd sub && echo x > $B/a.md" \
    'echo "*" > .claude/butler/.gitignore' \
    'git log --oneline > .claude/butler/log.txt 2>&1' \
    'ls >> .claude/butler/工单/list.txt' \
    "echo x > $B/a.md" \
    'git ls-files' \
    'git show --stat HEAD' \
    "git -C $WT rev-parse --abbrev-ref HEAD"
  do
    run "$g" allow "Bash allow: $c" "$(input Bash command "$c")"
  done

  # --- Bash: everything else asks ---
  for c in \
    'git commit -m x' \
    'git checkout main' \
    'git switch -c feature' \
    'git stash' \
    'git reset --hard' \
    'git merge feature' \
    'git push' \
    'git branch new-feature' \
    'git branch -D old' \
    'git worktree add ../x' \
    'git -c core.pager=x log' \
    'git log --output=/tmp/x' \
    'git diff' \
    'git diff HEAD~1' \
    'ls > x.txt' \
    'ls >> x.txt' \
    'echo x > .claude/butler/../a.md' \
    'echo x > .claude/butler-old/a.md' \
    'echo x > .claude/butler/$X' \
    'echo x >| src/a' \
    'echo x &> src/a' \
    'echo x >&src/a' \
    'cat <> .claude/butler/a' \
    'cd sub && echo x > .claude/butler/a' \
    'echo x > .claude/butler/a; cd sub; echo y > .claude/butler/b' \
    'git show --output=x HEAD' \
    'cat a && rm b' \
    'ls; rm -rf x' \
    'ls || rm x' \
    'ls & rm x' \
    'ls | xargs rm' \
    'cat x | tee y' \
    'echo $(rm x)' \
    'ls `rm x`' \
    'echo "$(rm x)"' \
    'diff <(ls) x' \
    '(rm x)' \
    '{ rm x; }' \
    'FOO=1 git status' \
    '/bin/rm x' \
    'bash -c "ls"' \
    'npm test' \
    'python3 x.py' \
    "sed -i 's/a/b/' f" \
    'touch .claude/butler/x' \
    'mkdir src/new' \
    'mkdir -m 777 .claude/butler/x' \
    'mkdir .claude/butler/../../src' \
    'mkdir .claude/butler/$X' \
    'cp a.md src/' \
    'cp a.md .claude' \
    'cp -t .claude/butler a.md' \
    'cd sub && mkdir .claude/butler/x' \
    'tail -f log.txt' \
    "echo 'unterminated" \
    'ls
rm x' \
    'cat <<EOF
x
EOF'
  do
    run "$g" ask "Bash ask: $c" "$(input Bash command "$c")"
  done

  # --- subagents and other tools ---
  run "$g" allow "subagent: Write outside passes through" \
    "$(input Write file_path "$root/src/app.js" "$root" '"agent_id":"a1b2","agent_type":"general-purpose",')"
  run "$g" allow "subagent: Bash rm passes through" \
    "$(input Bash command "rm -rf src" "$root" '"agent_id":"a1b2","agent_type":"general-purpose",')"
  run "$g" ask "main thread started with --agent (agent_type, no agent_id) is guarded" \
    "$(input Bash command "rm -rf src" "$root" '"agent_type":"my-agent",')"
  run "$g" ask "PowerShell: always asks" "$(input PowerShell command "Get-ChildItem")"
  run "$g" allow "Read: not the guard's business" "$(input Read file_path "$root/src/app.js")"
  run "$g" ask "garbage input" 'not json'

  # --- bypassPermissions: deny instead of ask (Claude Code lets "ask" through for protected folders there) ---
  MODE=bypassPermissions
  run "$g" deny "bypass: Write outside" "$(input Write file_path "$root/.claude/settings.json")"
  run "$g" deny "bypass: Bash rm" "$(input Bash command "rm -rf src")"
  run "$g" deny "bypass: Bash writing .claude/butler and outside" "$(input Bash command 'echo a > .claude/butler/a && echo b > notes.txt')"
  run "$g" allow "bypass: Write inside" "$(input Write file_path "$B/台账.md")"
  run "$g" allow "bypass: git status" "$(input Bash command "git status")"
  run "$g" allow "bypass: subagent passes through" \
    "$(input Bash command "rm -rf src" "$root" '"agent_id":"a1b2","agent_type":"general-purpose",')"
  MODE=
  run "$g" deny "bypass: unreadable arguments are denied too" \
    "{\"permission_mode\":\"bypassPermissions\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"a\",\"file_path\":\"b\"}}"
  run "$g" ask "acceptEdits still asks" "$(MODE=acceptEdits input Write file_path "$root/src/app.js")"
  run "$g" ask "empty input" ''
}

for lang in zh en; do
  case $lang in zh) guard=$repo/butler/scripts/guard.sh mark='管家守卫' ;; en) guard=$repo/en/butler/scripts/guard.sh mark='Butler guard' ;; esac
  cases "$guard"

  # message language
  out=$(printf '%s' "$(input Bash command 'rm x')" | CLAUDE_PROJECT_DIR=$root $shell "$guard")
  case $out in *"$mark"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL [$lang] message is not in the expected language: $out" ;; esac

  # held back only because of how it is written: suggest a plainer form; out of bounds: suggest a ticket
  case $lang in zh) plain='换成直白写法' ;; en) plain='write it plainly' ;; esac
  out=$(printf '%s' "$(input Bash command 'cat >> .claude/butler/a.md <<EOF
x
EOF')" | CLAUDE_PROJECT_DIR=$root $shell "$guard")
  case $out in *"$plain"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); echo "FAIL [$lang] heredoc message does not suggest a plainer form: $out" ;; esac
  out=$(printf '%s' "$(input Bash command 'npm test')" | CLAUDE_PROJECT_DIR=$root $shell "$guard")
  case $out in *"$plain"*) fail=$((fail + 1)); echo "FAIL [$lang] out-of-bounds message suggests a plainer form: $out" ;; *) pass=$((pass + 1)) ;; esac

  # a large Write (about 1 MB of content with many escaped quotes) stays fast
  big=$(awk 'BEGIN { s = "{\"cwd\":\"'"$root"'\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"'"$B"'/big.md\",\"content\":\""; for (i = 0; i < 20000; i++) s = s "line \\\"" i "\\\" text text text text text\\n"; print s "\"}}" }')
  t0=$(date +%s)
  run "$guard" allow "Write: 1 MB content" "$big"
  t1=$(date +%s)
  if [ $((t1 - t0)) -le 5 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL [$lang] 1 MB Write took $((t1 - t0))s"; fi

  # SKILL.md declares the hook and points at the shipped script
  skill=${guard%/scripts/guard.sh}/SKILL.md
  if awk '/^---$/ { n++; next } n == 1' "$skill" | grep -q 'command: "sh \\"${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh\\""'; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "FAIL [$lang] $skill frontmatter does not register scripts/guard.sh"
  fi
done

# the two copies differ only in their messages
marker='# ---- shared logic: keep identical in butler/scripts/guard.sh and en/butler/scripts/guard.sh ----'
if [ "$(sed -n "\\|^$marker\$|,\$p" "$repo/butler/scripts/guard.sh")" = "$(sed -n "\\|^$marker\$|,\$p" "$repo/en/butler/scripts/guard.sh")" ] &&
  grep -q "^$marker\$" "$repo/butler/scripts/guard.sh"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "FAIL shared logic differs between the zh and en guard"
fi

echo "guard tests ($shell): $pass passed, $fail failed"
[ "$fail" -eq 0 ]
