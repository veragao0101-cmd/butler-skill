#!/bin/sh
# Butler guard: the PreToolUse hook registered by the hooks field in SKILL.md.
#
# Once the user types /butler, Claude Code runs this script before every Bash, Write,
# Edit, MultiEdit, NotebookEdit and PowerShell call on this session's main thread,
# passing the call (JSON) on stdin.
# - File writes: allowed only when the target is inside <project root>/.claude/butler/.
# - Bash: only the read-only inspection commands listed under "Role boundaries";
#   in a compound command every part must be on the list. Output redirection,
#   mkdir and cp are allowed only into .claude/butler/.
# - Calls made inside a subagent (input carries agent_id) are left alone.
# When something is not allowed it answers "ask": Claude Code shows a permission prompt
# and the user decides — approve if they said "just change it yourself", otherwise deny.
# In bypassPermissions mode it answers "deny" instead: there, Claude Code (2.1.318) lets
# a hook's "ask" through for files under protected folders such as .claude/ and .git/.
# When it is allowed it prints nothing, so Claude Code's own permission flow applies
# unchanged (the guard never grants anything).
#
# Plain POSIX sh and awk only: nothing extra to install on macOS or Linux.

# ---- messages (English version) ----
M_PREFIX='Butler guard: '
M_SEP=' '
M_TICKET='Turn this into a ticket for a Worker.'
M_FORM='If this only writes files under .claude/butler/ or is a read-only query, write it plainly and try again (use the file-writing tool, or literal paths with no variables, heredocs or $(...)); otherwise turn it into a ticket for a Worker.'
M_ASK='Only the user can let this step through, in the permission prompt: they approve if they explicitly said "just change it yourself" in this session, and deny otherwise.'
M_DENY='The session is in bypassPermissions mode, where the guard cannot ask the user, so it refuses. If the user really wants the butler to do this itself, they have to switch to another permission mode first.'
M_WRITE='the butler session may only write files under .claude/butler/; this write targets '
M_BASH='the butler session may only run read-only inspection commands, and this one is not allowed: '
M_BASH_OK='. Allowed: ls, cat, head, tail, wc, pwd, cd, echo; git status, git diff --stat, git diff --name-only, git log, git show, git ls-files, git rev-parse, git branch, git worktree list (optionally with -C <path>); mkdir, cp and output redirection into .claude/butler/.'
M_STOP='.'
M_PS='PowerShell commands are not parsed in the butler session, so you are asked every time.'
M_PARSE='could not read this call'"'"'s arguments, so you are asked.'

detail() {
  case $1 in
    redirect) printf 'output redirection %s' "$2" ;;
    subst) printf 'command or process substitution %s' "$2" ;;
    subshell) printf 'subshell or parentheses %s' "$2" ;;
    heredoc) printf 'heredoc %s' "$2" ;;
    assign) printf 'environment variable assignment before the command %s' "$2" ;;
    cmd) printf '%s is not on the allowlist' "$2" ;;
    gitopt) printf 'git option %s' "$2" ;;
    gitsub) printf 'git %s is not a read-only query' "$2" ;;
    gitdiff) printf 'git diff is allowed only with a summary flag such as --stat or --name-only' ;;
    gitbranch) printf 'git branch %s would create or change a branch' "$2" ;;
    mkdiropt | cpopt) printf 'unsupported option %s' "$2" ;;
    cpargs) printf 'incomplete cp arguments' ;;
    cdwrite) printf 'writing with %s after cd, so the path cannot be checked' "$2" ;;
    follow) printf 'tail %s never returns' "$2" ;;
    unverifiable) printf 'path %s contains variables or wildcards and cannot be checked' "$2" ;;
    outside) printf '%s is not inside .claude/butler/' "$2" ;;
    long) printf 'the command is too long to check' ;;
    *) printf 'unbalanced quotes or syntax the guard cannot read %s' "$2" ;;
  esac
}

# ---- shared logic: keep identical in butler/scripts/guard.sh and en/butler/scripts/guard.sh ----

unset CDPATH

# Reads the hook input (one JSON object) and prints the fields the guard needs as
# KEY<TAB>VALUE lines. The JSON is split on double quotes, so long string values
# (e.g. Write content) are skipped without being copied or decoded. For Bash it
# also tokenizes the command and prints "block<TAB>CODE<TAB>ARG" or one
# "inside<TAB>PATH" line per mkdir/cp destination the shell part must check.
AWK_PROG='
function oddbs(s,   n, j) { n = length(s); j = n; while (j > 0 && substr(s, j, 1) == "\\") j--; return (n - j) % 2 }
function structure(s,   k, n, ch) {
  n = length(s)
  for (k = 1; k <= n; k++) {
    ch = substr(s, k, 1)
    if (ch == "{" || ch == "[") { d++; T[d] = (ch == "{") ? "o" : "a"; K[d] = "" }
    else if ((ch == "}" || ch == "]") && d > 0) d--
  }
}
function curpath(   k, p) { p = ""; for (k = 1; k <= d; k++) p = p (k > 1 ? "." : "") (T[k] == "o" ? K[k] : "[]"); return p }
function join(a, b,   k, s) { s = P[a]; for (k = a + 1; k <= b; k++) s = s "\"" P[k]; return s }
function hexval(h,   k, v, c) {
  v = 0; h = tolower(h)
  for (k = 1; k <= 4; k++) { c = index("0123456789abcdef", substr(h, k, 1)); if (!c) return -1; v = v * 16 + c - 1 }
  return v
}
function utf8(c) {
  if (c < 128) return sprintf("%c", c)
  if (c < 2048) return sprintf("%c%c", 192 + int(c / 64), 128 + c % 64)
  if (c < 65536) return sprintf("%c%c%c", 224 + int(c / 4096), 128 + int(c / 64) % 64, 128 + c % 64)
  return sprintf("%c%c%c%c", 240 + int(c / 262144), 128 + int(c / 4096) % 64, 128 + int(c / 64) % 64, 128 + c % 64)
}
function decode(s,   out, j, nx, h, l) {
  out = ""
  while ((j = index(s, "\\")) > 0) {
    out = out substr(s, 1, j - 1); nx = substr(s, j + 1, 1); s = substr(s, j + 2)
    if (nx == "\"" || nx == "\\" || nx == "/") out = out nx
    else if (nx == "n") out = out "\n"
    else if (nx == "t") out = out "\t"
    else if (nx == "u") {
      h = hexval(substr(s, 1, 4)); s = substr(s, 5)
      if (h >= 55296 && h < 56320 && substr(s, 1, 2) == "\\u") {
        l = hexval(substr(s, 3, 4))
        if (l >= 56320 && l < 57344) { s = substr(s, 7); h = 65536 + (h - 55296) * 1024 + (l - 56320) }
      }
      if (h < 32 || h == 127 || (h >= 55296 && h < 57344)) bad = 1; else out = out utf8(h)
    }
    else bad = 1
  }
  return out s
}
function block(code, arg) { if (!blocked) { blocked = 1; gsub(/[\t\n\r]/, " ", arg); print "block\t" code "\t" substr(arg, 1, 160) } }
function endword() {
  if (!inword) return
  if (redir != "") { checkredir(redir, word); redir = "" }
  else { nw[ns]++; W[ns, nw[ns]] = word }
  word = ""; inword = 0
}
function endseg() {
  endword()
  if (redir != "") { block("syntax", redir); redir = "" }
  if (nw[ns] > 0) { ns++; nw[ns] = 0 }
}
function checkredir(op, t) {
  if (op == "<") return
  if ((op == ">&" || op == "<&") && t ~ /^([0-9]+|-)$/) return
  if (op == "<&" || op == "<>") { block("redirect", op t); return }
  if (t == "/dev/null") return
  inside(t, op, ns)
}
function tokenize(c,   L, i, ch, nx, j, rest, op) {
  L = length(c); ns = 1; nw[1] = 0; word = ""; inword = 0; redir = ""
  for (i = 1; i <= L && !blocked; i++) {
    ch = substr(c, i, 1)
    if (ch == "\\") { nx = substr(c, i + 1, 1); i++; if (nx != "\n") { word = word nx; inword = 1 }; continue }
    if (ch == SQ) {
      rest = substr(c, i + 1); j = index(rest, SQ)
      if (!j) { block("syntax", SQ); break }
      word = word substr(rest, 1, j - 1); inword = 1; i += j; continue
    }
    if (ch == "\"") {
      inword = 1
      for (i++; i <= L; i++) {
        ch = substr(c, i, 1)
        if (ch == "\"") break
        if (ch == "`" || (ch == "$" && substr(c, i + 1, 1) == "(")) { block("subst", ch); break }
        if (ch == "\\") {
          nx = substr(c, i + 1, 1)
          if (nx == "$" || nx == "`" || nx == "\"" || nx == "\\") { word = word nx; i++; continue }
          if (nx == "\n") { i++; continue }
        }
        word = word ch
      }
      if (i > L) block("syntax", "\"")
      continue
    }
    if (ch == "`" || (ch == "$" && substr(c, i + 1, 1) == "(")) { block("subst", ch "("); break }
    if (ch == " " || ch == "\t") { endword(); continue }
    if (ch == "\n" || ch == ";") { endseg(); continue }
    if (ch == "&") {
      nx = substr(c, i + 1, 1)
      if (nx == ">") { endword(); i++; redir = "&>"; if (substr(c, i + 1, 1) == ">") { i++; redir = "&>>" }; continue }
      if (nx == "&") i++
      endseg(); continue
    }
    if (ch == "|") { nx = substr(c, i + 1, 1); if (nx == "|" || nx == "&") i++; endseg(); continue }
    if (ch == "(" || ch == ")") { block("subshell", ch); break }
    if (ch == "<" || ch == ">") {
      if (inword && word ~ /^[0-9]+$/) { word = ""; inword = 0 } else endword()
      if (redir != "") { block("syntax", redir ch); break }
      nx = substr(c, i + 1, 1)
      if (nx == "(") { block("subst", ch "("); break }
      op = ch
      if (ch == ">" && (nx == ">" || nx == "&" || nx == "|")) { op = op nx; i++ }
      else if (ch == "<" && (nx == "<" || nx == "&" || nx == ">")) { op = op nx; i++ }
      if (op == "<<") { block("heredoc", op); break }
      redir = op; continue
    }
    if (ch == "#" && !inword) { j = index(substr(c, i), "\n"); if (!j) break; i += j - 2; continue }
    word = word ch; inword = 1
  }
  if (!blocked) endseg()
}
function inside(a, what, seg) {
  if (a ~ /[$*?{}`\t\n\r]/ || index(a, "[") || a ~ /^~[^\/]/) { block("unverifiable", a); return }
  nin++; IN[nin] = a; WHAT[nin] = what; SEG[nin] = seg
}
function gitcheck(s, n,   k, a, sc, j) {
  k = 2
  while (k <= n) {
    a = W[s, k]
    if (a == "-C") { k += 2; continue }
    if (a == "--no-pager" || a == "-P") { k++; continue }
    if (a ~ /^-/) { block("gitopt", a); return }
    break
  }
  if (k > n) { block("gitsub", ""); return }
  sc = W[s, k]
  for (j = k + 1; j <= n; j++) if (W[s, j] ~ /^--output/ || W[s, j] == "--ext-diff") { block("gitopt", W[s, j]); return }
  if (sc == "status" || sc == "log" || sc == "show" || sc == "ls-files" || sc == "rev-parse") return
  if (sc == "diff") {
    for (j = k + 1; j <= n; j++) if (W[s, j] ~ /^--(stat|numstat|shortstat|dirstat|name-only|name-status|compact-summary|summary)/) return
    block("gitdiff", ""); return
  }
  if (sc == "worktree") { if (W[s, k + 1] == "list") return; block("gitsub", "worktree " W[s, k + 1]); return }
  if (sc == "branch") { branchcheck(s, n, k); return }
  block("gitsub", sc)
}
function branchcheck(s, n, k,   j, a, nm, listmode, pos, endopt) {
  listmode = 0; pos = 0; endopt = 0
  for (j = k + 1; j <= n; j++) {
    a = W[s, j]
    if (!endopt && a == "--") { endopt = 1; continue }
    if (!endopt && a ~ /^--/) {
      nm = a; sub(/=.*/, "", nm)
      if (nm ~ /^--(list|contains|no-contains|merged|no-merged|points-at)$/) { listmode = 1; continue }
      if (nm ~ /^--(all|remotes|verbose|show-current|color|no-color|column|no-column|abbrev|no-abbrev|ignore-case|omit-empty)$/) continue
      if (nm == "--sort" || nm == "--format") { if (a !~ /=/) j++; continue }
      block("gitbranch", a); return
    }
    if (!endopt && a ~ /^-./) {
      if (a ~ /^-[arvli]+$/) { if (a ~ /l/) listmode = 1; continue }
      block("gitbranch", a); return
    }
    pos++
  }
  if (pos > 0 && !listmode) block("gitbranch", W[s, k + 1])
}
function mkdircheck(s, n,   j, a, endopt) {
  endopt = 0
  for (j = 2; j <= n && !blocked; j++) {
    a = W[s, j]
    if (!endopt && a == "--") { endopt = 1; continue }
    if (!endopt && a ~ /^-/) { if (a ~ /^-[pv]+$/ || a == "--parents" || a == "--verbose") continue; block("mkdiropt", a); return }
    inside(a, "mkdir", s)
  }
}
function cpcheck(s, n,   j, a, endopt, cnt, last) {
  endopt = 0; cnt = 0
  for (j = 2; j <= n; j++) {
    a = W[s, j]
    if (!endopt && a == "--") { endopt = 1; continue }
    if (!endopt && a ~ /^-/) {
      if (a ~ /^-[rRpnfiva]+$/ || a ~ /^--(recursive|no-clobber|force|interactive|archive|verbose)$/) continue
      block("cpopt", a); return
    }
    cnt++; last = a
  }
  if (cnt < 2) { block("cpargs", ""); return }
  inside(last, "cp", s)
}
function evalsegs(   s, n, k, cmd, cdseg) {
  cdseg = 0
  for (s = 1; s <= ns && !blocked; s++) {
    n = nw[s]; if (n == 0) continue
    cmd = W[s, 1]
    if (cmd ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/) { block("assign", cmd); return }
    if (cmd == "ls" || cmd == "cat" || cmd == "head" || cmd == "wc" || cmd == "pwd" || cmd == "echo") continue
    if (cmd == "tail") {
      for (k = 2; k <= n; k++) if (W[s, k] ~ /^-[^-]*[fF]/ || W[s, k] ~ /^--(follow|retry)/) { block("follow", W[s, k]); return }
      continue
    }
    if (cmd == "cd") { if (!cdseg) cdseg = s; continue }
    if (cmd == "git") { gitcheck(s, n); continue }
    if (cmd == "mkdir") { mkdircheck(s, n); continue }
    if (cmd == "cp") { cpcheck(s, n); continue }
    block("cmd", cmd); return
  }
  # relative write targets after a cd would be resolved against the wrong folder (absolute ones are fine)
  if (!blocked && cdseg) for (k = 1; k <= nin; k++) if (SEG[k] > cdseg && IN[k] !~ /^(\/|~\/|[A-Za-z]:[\/\\])/) { block("cdwrite", WHAT[k]); return }
}
{ buf = (NR > 1) ? buf " " $0 : $0 }   # raw newlines are only whitespace in JSON; BWK awk split() also cuts at "\n"
END {
  SQ = sprintf("%c", 39)
  WANT["agent_id"] = "agent"; WANT["tool_name"] = "tool"; WANT["cwd"] = "cwd"; WANT["permission_mode"] = "mode"
  WANT["tool_input.file_path"] = "path"; WANT["tool_input.notebook_path"] = "path"; WANT["tool_input.command"] = "command"
  np = split(buf, P, "\"")
  d = 0; structure(P[1]); i = 2
  while (i <= np) {
    a = i
    while (oddbs(P[i]) && i < np) i++
    if (i >= np) { print "err\tjson"; exit }
    if (P[i + 1] ~ /^[ \t\r\n]*:/) K[d] = join(a, i)
    else if (T[d] == "o") {
      p = curpath()
      if (p in WANT) {
        if (WANT[p] in GOT) { print "err\tdup"; exit }
        bad = 0; v = decode(join(a, i)); GOT[WANT[p]] = v
        if (WANT[p] != "command") {
          if (bad || v ~ /[\t\n\r]/) { print "err\tvalue"; exit }
          print WANT[p] "\t" v
        } else if (bad) cmdbad = 1
      }
    }
    structure(P[i + 1]); i += 2
  }
  if (d != 0) { print "err\tjson"; exit }
  if (GOT["tool"] != "Bash") exit
  if (!("command" in GOT) || cmdbad) { print "block\tsyntax\t"; exit }
  if (length(GOT["command"]) > 20000) { print "block\tlong\t"; exit }
  blocked = 0; tokenize(GOT["command"])
  if (!blocked) evalsegs()
  if (!blocked) for (k = 1; k <= nin; k++) print "inside\t" IN[k]
}
'

# Holds the call back: "ask" (the user decides in a permission prompt), or "deny" in
# bypassPermissions mode, where Claude Code would let "ask" through for protected folders.
# $2 = form: the guard could not check how the command was written, so suggest a plainer form first.
ask() {
  if [ "${2:-}" = form ]; then _t=$M_FORM; else _t=$M_TICKET; fi
  if [ "$mode" = bypassPermissions ]; then _d=deny _h=$_t$M_SEP$M_DENY; else _d=ask _h=$_t$M_SEP$M_ASK; fi
  _m=$(printf '%s%s%s%s\n' "$M_PREFIX" "$1" "$M_SEP" "$_h" | LC_ALL=C awk '
    { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/[\001-\037\177]/, " "); printf "%s%s", (NR > 1 ? " " : ""), $0 }')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$_d" "$_m"
  exit 0
}

case $(uname -s 2>/dev/null) in MINGW* | MSYS* | CYGWIN*) on_windows=1 ;; *) on_windows= ;; esac

# Windows (Git Bash) passes C:\... paths; turn them into /c/... so the checks below work.
to_posix() {
  if [ -n "$on_windows" ]; then
    if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s\n' "$1" | tr '\\' '/'; fi
  else
    printf '%s\n' "$1"
  fi
}

# Absolute path -> "." and ".." removed lexically, as Node's path.resolve does for Write/Edit.
lexical() {
  printf '%s\n' "$1" | LC_ALL=C awk -F/ '{
    n = 0
    for (i = 1; i <= NF; i++) { if ($i == "" || $i == ".") continue; if ($i == "..") { if (n > 0) n--; continue } s[++n] = $i }
    o = ""; for (i = 1; i <= n; i++) o = o "/" s[i]; print (o == "" ? "/" : o) }'
}

# Absolute path -> where it really lands: follow a symlinked last component, resolve the
# longest existing directory prefix with pwd -P (symlinks and ".." as the kernel sees
# them), keep the not-yet-existing rest. Fails on symlink loops and dangling links.
physical() {
  _p=$1 _n=0
  while [ -L "$_p" ]; do
    _n=$((_n + 1)); [ "$_n" -le 40 ] || return 1
    _l=$(readlink "$_p") || return 1
    case $_l in /*) _p=$_l ;; *) _p=${_p%/*}/$_l ;; esac
  done
  _t=
  while [ -n "$_p" ] && [ ! -d "$_p" ]; do
    [ -L "$_p" ] && return 1
    _t=/${_p##*/}$_t
    _p=${_p%/*}
  done
  _r=$(cd -P "${_p:-/}" 2>/dev/null && pwd -P) || return 1
  [ "$_r" = / ] && _r=
  lexical "$_r$_t"
}

# True if path $1 (relative ones are taken from directory $2) lands inside $butler,
# read both the lexical way (Write/Edit) and the kernel way (mkdir/cp). With $3 = dir,
# $butler itself also counts (mkdir .claude/butler, cp x .claude/butler/).
in_butler() {
  _x=$1
  case $_x in
    '~') _x=$HOME ;;
    '~/'*) _x=$HOME/${_x#'~/'} ;;
  esac
  _x=$(to_posix "$_x")
  case $_x in /*) ;; *) _x=$2/$_x ;; esac
  _a=$(physical "$(lexical "$_x")") || return 1
  _b=$(physical "$_x") || return 1
  for _c in "$_a" "$_b"; do
    case $_c in
      "$butler"/*) ;;
      "$butler") [ "${3:-}" = dir ] || return 1 ;;
      *) return 1 ;;
    esac
  done
}

input=$(cat)
# Known before parsing, so that even unreadable input is denied rather than asked in bypass mode.
case $input in *'"permission_mode":"bypassPermissions"'* | *'"permission_mode": "bypassPermissions"'*) mode=bypassPermissions ;; *) mode= ;; esac
fields=$(printf '%s\n' "$input" | LC_ALL=C awk "$AWK_PROG") || ask "$M_PARSE"

tab=$(printf '\t')
agent= tool= cwd= path= err= bcode= barg= insides=
while IFS= read -r line; do
  key=${line%%"$tab"*}
  val=${line#*"$tab"}
  case $key in
    agent) agent=$val ;;
    mode) mode=$val ;;
    tool) tool=$val ;;
    cwd) cwd=$val ;;
    path) path=$val ;;
    err) err=$val ;;
    block) bcode=${val%%"$tab"*} barg=${val#*"$tab"} ;;
    inside) insides=$insides$val$tab ;;
  esac
done <<EOF
$fields
EOF

# Subagents (Workers, verification) are never the butler: let them through untouched.
[ -n "$agent" ] && exit 0

case $tool in
  Bash | Write | Edit | MultiEdit | NotebookEdit) ;;
  PowerShell) ask "$M_PS" ;;
  '') ask "$M_PARSE" ;;
  *) exit 0 ;;
esac
[ -n "$err" ] && ask "$M_PARSE"

root=$(to_posix "${CLAUDE_PROJECT_DIR:-${cwd:-$PWD}}")
base=$(to_posix "${cwd:-$root}")
butler=$(physical "$(lexical "$root/.claude/butler")") || ask "$M_PARSE"

if [ "$tool" = Bash ]; then
  case $bcode in subst | subshell | heredoc | assign | syntax | unverifiable | cdwrite | long) kind=form ;; *) kind= ;; esac
  [ -n "$bcode" ] && ask "$M_BASH$(detail "$bcode" "$barg")$M_BASH_OK" "$kind"
  while [ -n "$insides" ]; do
    p=${insides%%"$tab"*}
    insides=${insides#*"$tab"}
    in_butler "$p" "$base" dir || ask "$M_BASH$(detail outside "$p")$M_BASH_OK"
  done
  exit 0
fi

[ -n "$path" ] || ask "$M_PARSE"
in_butler "$path" "$base" || ask "$M_WRITE$path$M_STOP"
exit 0
