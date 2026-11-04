# Butler ledger

> Maintained by /butler. The ledger is an index: one row per ticket. Details are in `tickets/T-xxx.md`, contracts in `contracts/C-xxx.md`. No code, logs or full reports here.

## Current goal

Add a web UI to tiny-todo: built-ins-only HTTP server, JSON API (list/add/done) on todo.js, single-page frontend, API tests, README docs. **Done 2026-11-04** (merged into main, nothing pushed).

## Tickets

| ID | Goal | Executor (session link / session id / agent ID) | Status | Next step | Done date |
|---|---|---|---|---|---|
| T-001 | Backend: server.js, API per C-001, API tests, README, start script | subagent a9be0dc71d6e757f1 | done (merged) | Verified pass, 2 minor issues accepted (oversize body drops connection; test temp dir not cleaned). Merged to main in f0866eb | 2026-11-04 |
| T-002 | Frontend: public/index.html per C-001 | subagent a78fc673206e26e51 | done (merged) | Verified pass, 0 issues. Merged to main (8178f0d, merge eabadd2). Real-browser rendering never checked | 2026-11-04 |
| T-004 | Commit and merge T-001/T-002 into main, remove worktrees and branches (no push) | subagent a867ee94ca5f041dc | done | Checked via git: main at eabadd2, working tree clean, only main worktree and branch remain. Worker ran npm test 10/10 + curl check | 2026-11-04 |
| T-003 | Post-merge integration check | - | folded into T-004 | none | 2026-11-04 |

Status values: prep / queued / in progress / awaiting verification / rework / blocked / done. At most 3 sub-sessions "in progress" at once. Fill in the done date (YYYY-MM-DD) when a ticket passes verification; rows done for more than a week move to "Archive" at the end.

## Awaiting your decision

(none)

## Decisions made

| ID | Date | Decision | Related tickets |
|---|---|---|---|
| D-001 | 2026-11-04 | Use the butler; API shape approved as proposed (C-001) | T-001, T-002 |
| D-002 | 2026-11-04 | Split server and frontend into separate parallel tickets (user request) | T-001, T-002 |
| D-003 | 2026-11-04 | Merge both branches into main, then remove the worktrees and branches. No push. (T-004 merge Worker dispatched) | T-001, T-002 |

## Contracts

| ID | File | Content | Referenced by |
|---|---|---|---|
| C-001 | contracts/C-001.md | HTTP API + page-serving contract | T-001, T-002 |

## Blocked

(none)

## Archive

| ID | Goal | Executor (session link / session id / agent ID) | Status | Next step | Done date |
|---|---|---|---|---|---|
