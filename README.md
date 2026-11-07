# butler: a super-agent for solo developers

**English** | [简体中文](README.zh-CN.md)

> A Claude Code skill that borrows DeepSeek's Router–Worker "super-agent" design for solo developers — no servers, no GitHub bots, just one butler session that plans, delegates, verifies and only asks you when it matters.

Type `/butler <task>` and the current session becomes the "butler": it splits the work into tickets, hands them out, verifies the results and reports back. Execution happens in separate sub-sessions or subagents, and the butler only comes to you when it genuinely needs a decision.

---

## What is a super-agent?

In October 2026, DeepSeek Harness published an architecture exploration, *Super-agent Design Exploration*, which splits an agent system into two layers:

- **Router**: one long-running session that receives messages, makes judgments, dispatches work and replies — but never executes anything itself (it doesn't even get a shell).
- **Workers**: several isolated execution sessions, each taking one task with the full toolset and the strongest model, and handing its conclusions back to the Router when done.

Supporting mechanisms include thread subscription (follow-up events on the same PR go straight to the Worker responsible), a Watchdog (periodically judging whether a Worker is actually making progress), Chain of Recall (objects reference each other by ID and are expanded on demand), and batched decisions. In their synthetic experiments, p95 completion time dropped from 29.5 minutes with a single session to 15.7 minutes, at the cost of several times more cache-read tokens.

That design targets **teams, 24/7, event-driven** settings: cloud containers, databases, daemons on every machine, GitHub and chat events wired in. The article itself calls it an exploration, not a product.

## What a solo developer can borrow

Solo developers usually have no PR stream or chat events to handle, and don't want a long-running agent holding credentials and acting on its own. The real pain points are two:

1. **One session gets messier the longer it runs**: planning and execution get mixed together, and the context fills up fast.
2. **When unsure, the agent either makes the call itself or asks about everything.**

So this project **borrows the design principles, not the infrastructure**:

| Super-agent practice | Adopted? | What it looks like in butler |
|---|---|---|
| The Router only coordinates, never executes | ✅ | The butler session writes only the ledger, tickets, contracts and rules under `.claude/butler/` — no project files, no builds, no screenshots |
| Enforce delegation by structure, not by encouraging prompts | ✅ | With a neutral prompt, DeepSeek's experiment saw 0 delegations in 5 runs, so here it's a hard rule, backed by a hook that asks you before the butler session writes project files or runs commands |
| Isolated, parallel Workers | ✅ | Separate sub-sessions you can see by default (worktrees in git projects), at most 3 writing code and 5 in total |
| Ticket + Mandate | ✅ | One ticket per subtask, with an explicit mandate; external content can't widen it |
| Thread subscription, straight to the original Worker | ✅ | Rework and follow-ups go back to the original sub-session — no new session, no re-briefing through the butler |
| Chain of Recall / Inline & Spill | ✅ | The ledger is only an index; details live in ticket files, expanded by ID |
| Separate state from compute | ✅ | State lives in files; when a session fills up, open a new one and type `/butler continue` |
| Batched decisions | ✅ | Reports that arrive together are handled once and reported once |
| Watchdog | ✅ (simplified) | The butler checks in every time it wakes up, looking for "progress", not "still alive" |
| Interrupt the human only for decisions, briefly | ✅ | Reports are about 60 words, in three parts: outcome, needs your call, recommendation |
| Long-running processes, cloud containers, daemons | ❌ | Not needed for solo work, and a big security risk |
| Triggered automatically by GitHub / chat events | ❌ | Runs only while you're there, avoiding injection through external input |
| Peer-to-peer communication between Workers | ⚠️ Off by default | Authorized by the butler only for implementer ↔ reviewer loops or frontend ↔ backend interface alignment |

## How the butler works

### Overall structure

![Overall structure of the butler: you, the butler session, state files, sub-sessions and subagents](docs/diagrams/structure-en.svg)

<details>
<summary>Mermaid source</summary>

```mermaid
flowchart TB
    U([You]) <-->|"tasks / decisions<br/>reports ~60 words"| R

    subgraph R["Butler session (Router)"]
        direction TB
        R1[Split tickets · define contracts · order work]
        R2[Verify · check in · report]
    end

    R <-->|read / write| S[("State files<br/>ledger · tickets · contracts · rules")]

    R -->|dispatch ticket| W1[Sub-session T-001]
    R -->|dispatch ticket| W2[Sub-session T-002]
    R -->|quick read-only checks| SA[subagent]

    W1 -->|outcome + open items| R
    W2 -->|outcome + open items| R
    SA -->|result| R

    W1 -.->|full report| S
    W2 -.->|full report| S

    U -.->|in-scope changes, directly| W1
```

</details>

- The butler session holds only **conclusions**; change details, verification steps and acceptance records go in the ticket files.
- Sub-sessions don't talk to each other by default; they coordinate through **contract files** the butler writes up front.
- You can open any sub-session to watch or step in at any time — but you don't have to.

To see it in practice, [examples/en/](examples/en/README.md) is a real run: every message the butler sent, and the ledger, tickets and contract it left behind.

### Lifecycle of a ticket

![Lifecycle of a ticket: prep, queued, in progress, verification, rework, blocked, done](docs/diagrams/lifecycle-en.svg)

<details>
<summary>Mermaid source</summary>

```mermaid
stateDiagram-v2
    state "Prep" as Prep
    state "Queued" as Queued
    state "In progress" as InProgress
    state "Awaiting verification" as Verify
    state "Rework" as Rework
    state "Blocked" as Blocked
    state "Waiting for your call" as Decide
    state "Done" as Done

    [*] --> Prep: butler does read-only prep
    [*] --> Queued: ticket split out
    Prep --> Queued: you confirm
    Queued --> InProgress: slot free
    InProgress --> Verify: Worker reports done
    InProgress --> Blocked: check-in finds no progress
    Verify --> Done: verification passes
    Verify --> Rework: fails
    Rework --> InProgress: back to the original Worker
    Rework --> Blocked: still failing after two rounds
    Blocked --> InProgress: butler re-splits
    Blocked --> Decide: butler isn't sure
    Decide --> InProgress
    Done --> [*]
```

</details>

### When it comes to you

| Tier | Covers |
|---|---|
| **Always asks first** | Writing to external systems, sending messages, deleting or overwriting, publishing or pushing (incl. git push / PRs), touching credentials, red lines in `rules.md`, going beyond scope or widening a mandate |
| **Asks with a recommendation** | Two reasonable approaches that affect what follows, still failing after two rounds of rework, substantive contract changes |
| **Decides, then tells you** | Reading code and docs, read-only queries, implementing per existing conventions, running / previewing / testing locally, rework and re-splitting |

## Install

### As a plugin (recommended)

In Claude Code:

```text
/plugin marketplace add veragao0101-cmd/butler-skill
/plugin install butler@butler-skill
```

Or from your shell:

```bash
claude plugin marketplace add veragao0101-cmd/butler-skill
claude plugin install butler@butler-skill
```

Then run it with `/butler <task>`. If another command already uses `/butler`, use the full name `/butler:butler`.

To update: `claude plugin marketplace update butler-skill`, then `claude plugin update butler@butler-skill`. Third-party marketplaces don't auto-update unless you turn it on under `/plugin` → Marketplaces.

### Manual install

Put the [`en/butler/`](en/butler/) folder in either location:

- For all projects: `~/.claude/skills/butler/`
- For one project only: `<project>/.claude/skills/butler/`

```bash
git clone https://github.com/veragao0101-cmd/butler-skill.git
cp -r butler-skill/en/butler ~/.claude/skills/
```

### Chinese edition

The Chinese edition lives in [`butler/`](butler/) and installs as the plugin `butler-zh@butler-skill`. Both editions provide a skill named `butler`, so install only one of them, and don't keep a manual copy alongside the plugin.

## Usage

```text
/butler Finish the login page per the design mockup, using the existing /api/auth endpoint
/butler continue
```

Butler mode starts only when you type `/butler` yourself; Claude never switches a session into it on its own.

On first use, the butler sets up `.claude/butler/` in your project:

| File | Purpose |
|---|---|
| `rules.md` | Shared by all topics: your project's red lines (**fill this in first**) and cross-topic decisions |
| `<topic>/ledger.md` | This topic's index, one row per ticket |
| `<topic>/ledger-archive.md` | Finished tickets and carried-out decisions; not read at startup |
| `<topic>/tickets/T-xxx.md` | Goal, mandate, acceptance criteria, report log |
| `<topic>/contracts/C-xxx.md` | Fields, interfaces and conventions shared by several tickets |

**One ledger per topic**: when several unrelated things are going on, each gets its own topic, isolated from the others. `/butler migration continue` reads only `migration/` and `rules.md`. Keep one butler session per topic. With a single topic you can leave out the name; with several and no name, the butler lists them and asks.

In git projects, `.claude/butler/` comes with its own `.gitignore`, so it stays out of git and Workers' worktrees don't get stale copies. To commit the ledger as well, just delete that `.gitignore`.

### Requirements

- **Claude Code.** The desktop app (Code tab) gives the fullest experience — separate sub-sessions, messages between them, and a sidebar to view each one. The terminal version has no separate sub-sessions, so the butler uses subagents instead; the rules stay the same.
- **Skill frontmatter hooks** for the guard (see Limitations). Verified on Claude Code 2.1.318.
- **git is optional.** In a git repository each code-writing Worker gets its own worktree; outside git, all Workers share one folder and tickets have to split files more strictly.
- **`sh` and `awk`** for the guard script, both built into macOS and Linux. Windows needs Git for Windows (Git Bash); not tested there.

## Limitations

- The butler session's boundaries are enforced by a PreToolUse hook that ships with the skill (`scripts/guard.sh`). When the butler tries to write a file outside `.claude/butler/`, or run a command outside its read-only allowlist, Claude Code asks you first. Approve if you want the butler to do it itself; deny, and it turns the work into a ticket. Worker sub-sessions and subagents aren't affected.
  - **Let through**: read-only commands for looking at files and the environment (`grep`, `rg`, `find`, `sort`, `uniq`, `diff`, `stat`, `du`, `which`, `command -v`, `sed -n` printing line ranges, version probes such as `java -version`, and so on), git queries that don't change the repository, and the butler keeping its own files under `.claude/butler/` with `>`, heredocs, `mkdir`, `cp`, `mv`, `rm`, `touch` and `tee`.
  - **Asks you**: writing files outside `.claude/butler/`; interpreters that can run arbitrary code, such as `python` or `node`; builds, tests and servers; forms that change files, such as `sed -i`, `find -delete` or `sort -o`.

  The guard has limits:
  - It's active from the moment you type `/butler` until the session ends. Resuming an old session (`--resume`, `--continue`, or reopening it) doesn't bring it back; type `/butler continue` again.
  - Every out-of-bounds call needs its own approval. `claude -p` and SDK runs without a permission handler have no prompt, so those calls are always refused.
  - In bypassPermissions mode the guard refuses instead of asking, so the butler can't be let through at all. In that mode Claude Code (2.1.318) lets a hook's "ask" through whenever the target is in a protected folder such as `.claude/` or `.git/`, which would have let the butler edit `.claude/settings.json`. To let the butler do something itself, switch to another mode first.
  - It covers Bash, Write, Edit, MultiEdit, NotebookEdit and PowerShell. It doesn't cover MCP tools, or the butler sending a subagent to make changes without a ticket. It checks command text, so it catches a model forgetting the rules, not deliberate evasion.
  - The hook finds its script through `${CLAUDE_PLUGIN_ROOT}`, which points at the skill folder in skill hooks (verified on 2.1.318; the docs describe it only for plugins). If that changes, the hook errors out and the guard is off; replace the command under `hooks` in SKILL.md with the script's absolute path. Under the managed setting `strictPluginOnlyCustomization`, hooks of manually installed skills don't run.
- Multiple sessions cost more tokens than one; in exchange you get parallelism and a butler session that doesn't fill up.
- DeepSeek's experiments used synthetic workloads and measured scheduling, not code quality, and this project hasn't been systematically evaluated yet either. Issues with real-world feedback are welcome.

## Development

- `sh tests/test-guard.sh` runs the guard tests against both editions.
- The two `guard.sh` copies differ only in their messages: keep everything below the "shared logic" marker identical (the tests check this).
- The README diagrams are shown as the SVGs in `docs/diagrams/`; the folded Mermaid blocks are their source. After editing a Mermaid block, re-export the matching SVG (two per language) so the two stay in sync.

## References

- [DeepSeek Harness: Exploring Super-agent Design](https://x.com/DeepSeekHarness/status/2116857257245987236)
- [offloop: Exploring DeepSeek Super Agent Design (full English translation)](https://offloop.org/learn/exploring-deepseek-super-agent-design)
- [kingy.ai: DeepSeek's Super-agent Design Explained](https://kingy.ai/blog/deepseek-super-agent-design-explained/)
- [redreamality: DeepSeek Super-agent Architecture](https://redreamality.com/blog/deepseek-super-agent-router-worker-architecture/)

## License

[MIT](LICENSE)
