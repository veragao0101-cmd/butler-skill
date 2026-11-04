# Example: a web UI for tiny-todo (several tickets, one contract, parallel Workers)

Real run, Claude Code 2.1.318, terminal mode (Workers are subagents started with the Agent tool), driven with `claude -p` and `--resume`, model `claude-sonnet-5-5`, `--permission-mode bypassPermissions`. In the state files and quotes, absolute paths are replaced with `<project>`. Nothing else is edited.

## The seed project

tiny-todo is a Node.js command-line todo list: `todo.js` (add / done / list, JSON file storage, exports `add`, `done`, `list` and `load`), `test/todo.test.js` (run with `node --test`) and a README. It has one commit on `main` (`364ce2c`).

## What the user typed

1. `/butler Add a web UI to tiny-todo. A small HTTP server using only Node built-ins (no dependencies) with a JSON API to list todos, add one and mark one done, built on the existing todo.js; and a single-page frontend served by the same server where I can see, add and complete todos. Add tests for the API, and document in the README how to start it.`
2. `/butler continue — yes, I want to use the butler for this. The API looks good. But can the server and the frontend be separate tickets, so they get built in parallel against that API?`
3. `/butler continue — yes, merge both into main and remove the worktrees and branches.`

## What the butler said

Times are UTC. Every message is quoted in full. The status updates that asked for nothing are folded away, with their word counts shown.

**Turn 1, 09:14:34.** The butler read the code itself and set up `.claude/butler/`. It wrote one ticket and no contract, then stopped for review:

> I've set up `.claude/butler/` and written the plan, but I haven't dispatched anything yet. I need your OK first.
>
> **Outcome:** There's one ticket, T-001. It covers `server.js`, `public/index.html`, `test/server.test.js`, the README and a `start` script. These files depend on each other, so splitting them would only cause conflicts.
>
> **Needs your call:**
> - Setup added `.claude/butler/.gitignore` containing `*`, so the butler's working files stay out of git. Delete it if you want them committed. Project-specific red lines go in `.claude/butler/rules.md`.
> - This job probably doesn't need the butler. A normal session would likely be faster and cheaper.
> - If you do want the butler, here are the calls I made:
>   - `GET /api/todos` returns the list.
>   - `POST /api/todos` takes `{text}` and returns 201.
>   - `POST /api/todos/:id/done` marks a todo done.
>   - Bad input returns 400, and an unknown id returns 404.
>   - The port comes from `PORT` and defaults to 3000.
>   - The server uses the existing `TODO_FILE`.
>   - The Worker runs in its own worktree and doesn't commit. You decide on the merge afterwards.
>
> **Recommendation:** Say "go" to dispatch T-001 as planned. If you'd rather skip the overhead, tell me and a normal session can do it.

**Turn 2.** The butler took the reply as approval. It wrote contract C-001, split the job into T-001 (backend) and T-002 (frontend), and dispatched both Workers without showing the new plan first. Besides the messages below, the only lines it showed were "Dispatching both Workers now, each in its own worktree." and "Record the executor IDs in the tickets and ledger." It sent a message each time it woke up:

<details><summary>09:15:52, after dispatch (124 words, no decision needed)</summary>

> **Outcome:** I split the job as you asked and both Workers are now running in parallel, each in its own worktree.
> - **T-001 (backend):** `server.js`, the API tests, the README and a `start` script.
> - **T-002 (frontend):** `public/index.html`, tested against a throwaway stub of the API.
>
> Both follow a shared contract, C-001, which holds the API you approved.
>
> **Calls I made:**
> - I assigned the README to the backend ticket.
> - The page is one self-contained file with inline CSS and JS.
> - An integration check (T-003) runs after both are verified and merged.
>
> **Needs your call:** none for now. I'll come back when both Workers report and have been verified, and ask then which branches to merge.
>
> **Recommendation:** nothing to do until then.
</details>

<details><summary>09:16:46, T-001 reported (74 words, no decision needed)</summary>

> T-001's Worker has reported, and its changes are limited to the files in its mandate: `server.js`, `test/server.test.js`, `README.md` and the `package.json` start script. Its own `npm test` run passed, 10 of 10, but I'm not relying on that. A separate verification agent is checking it independently now, and T-002 (frontend) is still being built.
>
> **Needs your call:** none yet.
>
> I'll report again once both tickets are verified, and ask then which branches to merge.
</details>

<details><summary>09:17:36, T-001 verified (108 words, no decision needed)</summary>

> **Outcome:** T-001 (backend) passed independent verification. Every endpoint and error case in C-001 behaved as specified, `npm test` passed 10 of 10, and data persisted across a server restart. It's done but not merged, and its changes sit on branch `worktree-agent-a9be0dc71d6e757f1`.
>
> There were two minor issues, neither blocking:
> - A request body over 1 MB makes the server drop the connection without sending a response.
> - The test leaves its temp directory behind in the OS temp dir.
>
> T-002 (frontend) is still in progress.
>
> **Needs your call:** none yet.
>
> **Recommendation:** accept the two minor issues as they are. I'll ask about merging both branches once T-002 is verified.
</details>

<details><summary>09:21:49, T-002 reported (93 words, no decision needed)</summary>

> T-002's Worker has reported. Its only change is the new `public/` folder, which is within its mandate. It tested the page against a stub of the API, not the real server, and couldn't render it in a real browser because headless Chrome hung.
>
> A verification agent is now checking the page on its own. It will also run the page against T-001's real server in a temp directory outside the repo, as a pre-merge integration check.
>
> **Needs your call:** none yet.
>
> I'll report once that finishes, and ask then which branches to merge.
</details>

**09:22:26, end of phase:**

> **Outcome:** Both tickets passed independent verification. T-001 (backend) had 2 minor issues. T-002 (frontend) had none. The pre-merge integration check also passed: T-001's real server served T-002's page, and the API calls matched C-001. Nothing is merged yet.
>
> Not checked: how the page looks in a real browser, because headless Chrome hangs in this sandbox.
>
> **Needs your call:** Each Worker's changes are uncommitted in its own worktree. The two branches, `worktree-agent-a9be0dc71d6e757f1` (T-001) and `worktree-agent-a78fc673206e26e51` (T-002), still point at the original commit. Merging means a Worker commits each one, merges both into `main`, and removes the worktrees and branches. There is no push.
>
> **Recommendation:** Approve the merge. The two branches change different files, so I don't expect conflicts. Afterwards, run `npm start` and open `http://localhost:3000` once to check the layout.

**Turn 3.** The butler sent a merge Worker (T-004) and checked the result with `git status`, `git show --stat` and `git worktree list`.

<details><summary>09:23:55, after dispatch (81 words, no decision needed)</summary>

> **Outcome:** I've recorded your merge approval and dispatched T-004, a Worker that will commit each branch, merge both into `main`, and remove the worktrees and branches. It won't push. It will also run `npm test` and a quick check against the server on `main` before it removes anything. If anything unexpected turns up, it stops and reports to me.
>
> **Needs your call:** none.
>
> I'll confirm the result with git (`log`, `worktree list`, `branch`) when it reports, then close out the goal.
</details>

**09:24:24, wrap-up:**

> **Outcome:** The web UI is merged into `main` and nothing was pushed. `git` confirms the following:
> - `main` is at `eabadd2` and the working tree is clean.
> - The two worktrees and two branches are gone.
> - The Worker reported `npm test` passing 10 of 10, and a check of the running server returned 200 for both `GET /` and `GET /api/todos`.
>
> Start it with `npm start`, then open `http://localhost:3000`. The README documents `PORT`, `TODO_FILE` and the API.
>
> **Needs your call:** none. The Worker's note that `.claude/` is untracked and not in `.gitignore` is already handled by the butler folder's own `.gitignore`, so `git status` is clean.
>
> **Recommendation:** Open the page once in a browser, since the layout was never rendered in a real browser.

## Tickets and contract

State after the run: [ledger](state/ledger.md), [rules](state/rules.md), [contract C-001](state/contracts/C-001.md) (the HTTP API and how the page is served, referenced by T-001 and T-002).

| Ticket | Goal | Executor | Own worktree | Verification | Rework rounds |
|---|---|---|---|---|---|
| [T-001](state/tickets/T-001.md) | Backend: `server.js`, API per C-001, API tests, README, `start` script | subagent `a9be0dc71d6e757f1` | yes | pass, 2 minor issues (verifier `a501be5094f304b70`) | 0 |
| [T-002](state/tickets/T-002.md) | Frontend: `public/index.html` per C-001 | subagent `a78fc673206e26e51` | yes | pass, 0 issues, plus a pre-merge integration check (verifier `a65465b87ab81062e`) | 0 |
| T-003 | Post-merge integration check | none | – | no ticket file. The ledger says "folded into T-004" | – |
| [T-004](state/tickets/T-004.md) | Commit both branches, merge into `main`, remove worktrees and branches | subagent `a867ee94ca5f041dc` | no | no verifier. The butler checked git itself | 0 |

The merge Worker created the T-004 file from the butler's brief, so the file has only a Log, with no Goal, Mandate or Acceptance sections. The merge result went into the ledger's T-001 and T-002 rows, not into those tickets' Logs.

## Parallelism and the guard

The Workers ran in parallel, per the task events in the stream log. T-001 and T-002 started at 09:15:42 and 09:15:45. T-001 finished at 09:16:33, and its verifier ran from 09:16:44 to 09:17:29 while T-002 was still working. T-002 finished at 09:21:31. About four of its minutes went on headless `google-chrome`, which hung, before it tested its script with a fake DOM. At most two subagents ran at once, so the cap of 3 never came into play.

The guard held back one main-thread command, in turn 1. That command was `mkdir -p … && cd <skill>/templates && cp ledger.md rules.md <project>/.claude/butler/`:

> PreToolUse:Bash hook error: Butler guard: the butler session may only run read-only inspection commands, and this one is not allowed: writing with cp after cd, so the path cannot be checked. Allowed: ls, cat, head, tail, wc, pwd, cd, echo; git status, git diff --stat, git diff --name-only, git log, git show, git ls-files, git rev-parse, git branch, git worktree list (optionally with -C <path>); mkdir, cp and output redirection into .claude/butler/. Keep commands plain: literal paths, no variables. Turn this into a ticket for a Worker. The session is in bypassPermissions mode, where the guard cannot ask the user, so it refuses. If the user really wants the butler to do this itself, they have to switch to another permission mode first.

The destination was a literal path inside `.claude/butler/`, so this hold was overcautious. The butler wrote the files with the Write tool instead. Every other main-thread command was read-only (`ls`, `cat`, `git status`/`worktree list`/`branch`/`show --stat`). The butler ran no project code and edited no project files.

## Outcome

```
$ git log --oneline
eabadd2 Merge branch 'worktree-agent-a78fc673206e26e51'
f0866eb Add HTTP server, JSON API, tests and README docs
8178f0d Add single-page web frontend
364ce2c tiny-todo: add, done, list

$ git diff --stat 364ce2c..main
 README.md           |  20 +++++++
 package.json        |   2 +-
 public/index.html   | 161 ++++++++++++++++++++++++++++++++++++++++++++++++++++
 server.js           |  95 +++++++++++++++++++++++++++++++
 test/server.test.js |  93 ++++++++++++++++++++++++++++++
 5 files changed, 370 insertions(+), 1 deletion(-)

$ npm test
# tests 10
# pass 10
# fail 0
```

To check it myself, I started the server with `PORT=3456 TODO_FILE=<tmp>/todos.json node server.js`:

```
$ curl -s -o /dev/null -w '%{http_code} %{content_type}\n' localhost:3456/
200 text/html; charset=utf-8
$ curl -s -X POST localhost:3456/api/todos -d '{"text":"buy milk"}'
{"id":1,"text":"buy milk","done":false}
```

I also opened the page in headless Chromium through Playwright, which the butler's agents didn't use. I added a todo with the form and clicked Done. The item showed with a strikethrough, the file recorded `"done": true`, and the console showed no errors.

## Numbers per invocation

These figures come from the `result` events and cover the main thread only. In `claude -p`, the main thread woke up each time a background subagent finished, and each wake produced its own `result` event, so each row sums its invocation's events.

| Invocation | Wall clock | `result` events | duration_ms | num_turns | input | cache write | cache read | output |
|---|---|---|---|---|---|---|---|---|
| 1 (plan) | 30 s | 1 | 27,954 | 10 | 12 | 17,724 | 135,003 | 3,373 |
| 2 (split, build, verify) | 7 min 17 s | 5 | 92,077 | 25 | 36 | 25,959 | 683,206 | 10,857 |
| 3 (merge, wrap-up) | 1 min 00 s | 2 | 43,348 | 13 | 18 | 14,045 | 509,588 | 4,429 |

Subagents included, the session's `modelUsage` at the end was 158 input tokens, 137,899 cache-write tokens, 2,121,865 cache-read tokens and 45,688 output tokens.

## What changed in the skill afterwards

This run, together with the Chinese one, led to these changes. The transcript above shows the behaviour before them.

- **Is the butler worth it?** The check now needs all three conditions at once (one or two files, nothing to parallelize, a short job), and parts that can be built separately once a contract is set, such as frontend and backend, count as parallelizable.
- **Splitting:** when parts depend on each other through an interface, the butler writes the interface up as a contract and splits the work, instead of folding it into one ticket.
- **Reading code:** a subagent reads the code to be changed and reports which files are involved and which parts can be done separately; the butler doesn't read project code itself.
- **Plan review:** only an explicit go-ahead counts as confirmation. A question or a change request means revising the plan and showing it again.
- **Reports:** no messages to the user between dispatch and an outcome or a decision.
- **Ticket path:** in the terminal, Workers in a worktree often can't write the ticket file; the four-part report they send back goes into the ticket as is, not just the outcome.
- **Wrap-up:** the butler writes the merge-and-cleanup ticket itself before dispatching it, checks the result with git rather than relying on the Worker's report, and records it in that ticket.
- **Guard:** writing with `cp` after `cd` is allowed when the destination is an absolute path inside `.claude/butler/`. When a command is held back only because of how it's written (a heredoc into a ticket, say), the message suggests a plainer form first instead of a ticket.
