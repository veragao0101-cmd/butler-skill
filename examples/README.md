# Examples

**English** | [简体中文](#示例)

Real runs of the `butler` skill, end to end, on the same small task: add a web UI (a JSON API plus a single-page frontend) to a tiny Node.js todo CLI. Each folder has a walkthrough with every message the butler sent, quoted verbatim, and a snapshot of the `.butler/` folder it left behind.

| Run | Skill edition | What it shows |
|---|---|---|
| [en/](en/README.md) | English | One contract, two Workers in parallel worktrees, a verifier per ticket, a merge Worker and wrap-up |
| [zh/](zh/README.md) | Chinese | The same flow, plus a real bug found in verification and sent back to the original Worker for rework |

Both ran in Claude Code 2.1.318 in terminal mode (Workers are subagents), with `claude -p` and `--resume`, model `claude-sonnet-5-5`, in bypassPermissions mode. Only absolute paths were replaced.

They're not polished demos. Both runs also showed where the skill fell short: the butler first said the job wasn't worth it and put frontend and backend in one ticket, read project code itself, sent progress messages with nothing to decide, and left merge results out of the tickets. Each walkthrough ends with the skill changes the run led to; the transcripts show the behaviour before those changes.

---

## 示例

[English](#examples) | **简体中文**

`butler` skill 的真实运行记录，从头到尾跑完，两次用的是同一个小任务：给一个 Node.js 待办命令行工具加网页界面（JSON 接口加单页前端）。每个文件夹里有一份经过说明，原样引用了管家发给用户的每一条消息，还有它留下的 `.butler/` 快照。

| 记录 | skill 版本 | 展示了什么 |
|---|---|---|
| [en/](en/README.md) | 英文版 | 一份契约，两个 Worker 在各自的 worktree 里并行，每张工单单独验收，最后派 Worker 合并、收尾 |
| [zh/](zh/README.md) | 中文版 | 同样的流程，另外验收查出一个真 bug，退回原 Worker 返工 |

两次都在 Claude Code 2.1.318 终端模式下运行（Worker 是 subagent），用 `claude -p` 加 `--resume`，模型 `claude-sonnet-5-5`，bypassPermissions 模式。只替换了绝对路径。

这不是精修过的演示。两次运行也暴露了 skill 的不足：管家起初说这件事不值得用管家，把前端和后端放进一张工单，自己读项目代码，发了不需要拍板的进度消息，合并结果也没记进工单。每份记录末尾列了这次运行带来的 skill 修改；记录本身展示的是修改之前的表现。
