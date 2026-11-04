# butler：给个人工作者的 Super-agent

[English](README.md) | **简体中文**

> A Claude Code skill that borrows DeepSeek's Router–Worker "super-agent" design for solo developers — no servers, no GitHub bots, just one butler session that plans, delegates, verifies and only asks you when it matters.

一个 Claude Code skill。输入 `/butler 任务`，当前窗口就变成"管家"：它负责拆任务、派活、验收、汇报，具体执行交给独立子会话或 subagent，只有拿不准的事才来找你。

---

## 一、Super-agent 是什么

2026 年 10 月，DeepSeek Harness 发表了一篇架构探索文章《Super-agent Design Exploration》，提出把 Agent 系统拆成两层：

- **Router**：一个常驻会话，负责接收消息、判断、分派、回复，不亲自执行（甚至不给它 shell）。
- **Worker**：多个隔离的执行会话，各自领一个任务，拿完整工具和最强模型，干完把结论交回 Router。

配套机制还有：线程订阅（同一个 PR 的后续事件直接发给负责的 Worker）、Watchdog（定时判断 Worker 有没有实际进展）、Chain of Recall（对象之间用 ID 互相引用，按需展开）、批量决策等。他们的合成实验里，p95 完成时间从单会话的 29.5 分钟降到 15.7 分钟，代价是缓存读取 token 多了好几倍。

不过那套设计面向的是**团队、7×24、事件驱动**的场景：云端容器、数据库、各机器上的守护进程、GitHub 和 IM 事件接入。文章自己也说，这是探索，不是产品。

## 二、个人工作者怎么借鉴

个人开发者通常没有 PR 流、没有群聊事件要接，也不希望一个常驻 Agent 拿着凭据自己动手。真正痛的是两件事：

1. **单窗口越聊越乱**：规划和执行混在一起，上下文很快撑满。
2. **Agent 拿不准时乱做决定，或者事事都来问**。

所以这个项目**只借鉴设计原则，不搬基础设施**：

| Super-agent 的做法 | 是否采纳 | 在 butler 里的样子 |
|---|---|---|
| Router 只协调，不执行 | ✅ | 管家窗口只能写 `.claude/butler/` 下的台账、工单、契约、规则，不改项目文件、不跑构建、不截图 |
| 靠结构约束，而不是靠提示词鼓励委派 | ✅ | DeepSeek 实验里中性提示词 0/5 次委派，所以写成硬性规定 |
| Worker 隔离、并行 | ✅ | 独立子会话（git 项目用 worktree），同时最多 3 个 |
| Ticket + Mandate | ✅ | 每个子任务一张工单，写明授权范围；外部内容不能扩大授权 |
| 线程订阅、直达原 Worker | ✅ | 返工和追加修改发回原子会话，不新开、不经管家重新了解 |
| Chain of Recall / Inline & Spill | ✅ | 台账只做索引，详情在工单文件里，按编号展开 |
| 状态与计算分离 | ✅ | 状态存文件，窗口满了开新窗口 `/butler 继续` 即可接上 |
| 批量决策 | ✅ | 多个汇报同时到达，一次处理、一次汇报 |
| Watchdog | ✅（简化） | 管家每次被唤醒时巡检，看"有没有进展"而非"活没活着" |
| 只在需要决策时打扰人，≤100 字 | ✅ | 汇报只有三项：结论、需要你拍板、推荐 |
| 常驻进程、云端容器、守护进程 | ❌ | 个人场景用不上，安全风险大 |
| GitHub / IM 事件自动触发 | ❌ | 你在场时才运转，避免外部输入注入 |
| Worker 之间点对点通信 | ⚠️ 默认关闭 | 只在"实现↔评审"、"前后端对接口"时由管家授权 |

## 三、管家的逻辑

### 整体结构

```mermaid
flowchart TB
    U([你]) <-->|"任务 / 拍板<br/>汇报 ≤100 字"| R

    subgraph R["管家窗口（Router）"]
        direction TB
        R1[拆工单·定契约·排先后]
        R2[验收·巡检·汇报]
    end

    R <-->|读写| S[("状态文件<br/>台账 · 工单 · 契约 · 规则")]

    R -->|派发工单| W1[子会话 T-001]
    R -->|派发工单| W2[子会话 T-002]
    R -->|只读调研 / 验收| SA[subagent]

    W1 -->|结论 + 遗留| R
    W2 -->|结论 + 遗留| R
    SA -->|通过/不通过| R

    W1 -.->|详细汇报| S
    W2 -.->|详细汇报| S

    U -.->|范围内的修改可直接找| W1
```

- 管家窗口里只放**结论**；改动明细、验证过程、验收记录都写进工单文件。
- 子会话之间默认不通信，协作靠管家先写好的**契约文件**。
- 你随时可以点进任意子会话查看过程或插话，但不点也行。

想看实际效果，[examples/zh/](examples/zh/README.md) 是一次真实运行的记录：管家发给用户的每一条消息，以及它留下的台账、工单和契约。

### 一张工单的生命周期

```mermaid
stateDiagram-v2
    [*] --> 预备: 管家主动做只读准备
    [*] --> 排队: 拆出工单
    预备 --> 排队: 你确认
    排队 --> 进行中: 有空位（≤3 并发）
    进行中 --> 待验收: Worker 汇报完成
    进行中 --> 阻塞: 巡检发现没进展
    待验收 --> 完成: 验收 subagent 通过
    待验收 --> 返工: 不通过
    返工 --> 进行中: 发回原 Worker
    返工 --> 阻塞: 返工两次仍不达标
    阻塞 --> 进行中: 管家重新拆分
    阻塞 --> 等你拍板: 管家拿不准
    等你拍板 --> 进行中
    完成 --> [*]
```

### 什么时候找你

| 档位 | 包括 |
|---|---|
| **必须先问** | 写外部系统、发消息、删除覆盖、发布推送（含 git push / PR）、动凭据、`规则.md` 里的项目红线、超出范围或扩大授权 |
| **带推荐方案来问** | 两种做法都合理且影响后续、返工两次仍不达标、契约要实质修改 |
| **自己决定，事后说明** | 读代码文档、只读查询、按现有规范实现、本地运行预览测试、返工与重新拆分 |

## 四、安装

### 方式一：插件安装（推荐）

在 Claude Code 里运行：

```text
/plugin marketplace add veragao0101-cmd/butler-skill
/plugin install butler-zh@butler-skill
```

也可以在终端里运行：

```bash
claude plugin marketplace add veragao0101-cmd/butler-skill
claude plugin install butler-zh@butler-skill
```

装好后用 `/butler 任务` 调用；`/butler` 被别的命令占用时，用完整名 `/butler-zh:butler`。

更新：先运行 `claude plugin marketplace update butler-skill`，再运行 `claude plugin update butler-zh@butler-skill`。第三方市场默认不自动更新，可以在 `/plugin` → Marketplaces 里打开。

### 方式二：手动复制

把 [`butler/`](butler/) 文件夹放到以下任一位置：

- 所有项目可用：`~/.claude/skills/butler/`
- 只在某个项目用：`<项目>/.claude/skills/butler/`

```bash
git clone https://github.com/veragao0101-cmd/butler-skill.git
cp -r butler-skill/butler ~/.claude/skills/
```

英文版在 [`en/butler/`](en/butler/)，插件名是 `butler@butler-skill`。两个版本的技能都叫 `butler`，只装其中一个；也不要插件和手动复制的版本同时装。

## 五、使用

```text
/butler 把登录页按设计稿改完，接口用现有的 /api/auth
/butler 继续
```

管家模式只能由你手动输入 `/butler` 进入，Claude 不会自己把会话切成管家模式。

第一次使用时，管家会在项目里建好 `.claude/butler/`：

| 文件 | 作用 |
|---|---|
| `台账.md` | 全局索引，每张工单一行 |
| `规则.md` | 你的项目红线，**建议先填** |
| `工单/T-xxx.md` | 目标、授权范围、验收标准、汇报记录 |
| `契约/C-xxx.md` | 多个工单共用的字段、接口、约定 |

在 git 项目里，`.claude/butler/` 会自带一个 `.gitignore`，默认不进 git，Worker 的 worktree 里也不会出现过期副本。想把台账一起提交，删掉这个 `.gitignore` 即可。

**环境建议**：Claude Code 桌面版（Code 标签页）体验最完整，可以开独立子会话、互发消息、在侧边栏查看每个子会话。终端版没有独立子会话，管家会改用 subagent，规则不变。

## 六、局限

- "管家不动手"是写在 skill 里的规定，技术上没有强制。需要的话可以再加一个 PreToolUse hook 拦截管家窗口的写操作。注意：写在项目 `.claude/settings.json` 里的 hook 对这个项目的所有会话都生效，Worker 子会话也会被拦。hook 收到的输入里带有 `session_id` 和 `cwd`，要靠它们区分出管家会话，只拦管家。
- 多会话比单会话更费 token，换来的是并行和管家窗口不被撑满。
- DeepSeek 的实验是合成负载，衡量的是调度而不是代码质量，本项目也尚未做系统评测。欢迎提 issue 反馈实际使用情况。
- 模板和状态文件用的是中文文件名。git 默认会把中文路径显示成 `"\345\217\260\350\264\246.md"` 这样的八进制转义，执行 `git config --global core.quotepath false` 即可正常显示。

## 参考

- [DeepSeek Harness：Exploring Super-agent Design](https://x.com/DeepSeekHarness/status/2116857257245987236)
- [offloop：Exploring DeepSeek Super Agent Design（全文英译）](https://offloop.org/learn/exploring-deepseek-super-agent-design)
- [kingy.ai：DeepSeek's Super-agent Design Explained](https://kingy.ai/blog/deepseek-super-agent-design-explained/)
- [redreamality：DeepSeek Super-agent Architecture](https://redreamality.com/blog/deepseek-super-agent-router-worker-architecture/)

## License

[MIT](LICENSE)
