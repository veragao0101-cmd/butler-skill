# 示例：用 /butler 给 tiny-todo 加网页界面

这是一次真实运行的记录：Claude Code 2.1.318，终端模式（Worker 都是 Agent 工具派出的 subagent），用 `claude -p` 加 `--resume` 逐轮接着跑，模型 claude-sonnet-5-5，权限模式 bypassPermissions。文中和 `state/` 里只把绝对路径换成了 `<项目>`，别的没有改。

## 起点

种子项目 tiny-todo 是一个很小的 Node.js 命令行待办工具：`todo.js` 提供 add/done/list，数据存在 JSON 文件里，测试用 `node --test`，README 是英文的。`main` 上只有一个提交 `364ce2c`。

## 对话经过

一共调用了 4 次 `claude -p`。下面是用户输入的原文，以及管家发给用户的每一条消息，一字未删。

### 第 1 次

```
/butler 给 tiny-todo 加一个网页界面：用 Node 自带模块写一个小 HTTP 服务（不装依赖），基于现有的 todo.js 提供 JSON 接口，能列出待办、新增待办、标记完成；同一个服务再提供一个单页前端，在网页上能看、能加、能勾选完成。接口要有测试，README 里写清楚怎么启动。
```

管家建好 `.claude/butler/`（台账、规则、`工单/`、`契约/`，再加一个只有 `*` 的 `.gitignore`），自己用 `cat` 看了 `todo.js`、`package.json` 和 README，然后回复：

> **结论**:这件事不必用管家。要改的是新增 `server.js`、一个前端页面、测试文件和 README,代码量小,没有能并行的部分。开工单、派 Worker、再验收,比在普通会话里直接做更慢、更费 token。
>
> 我已经在 `.claude/butler/` 建好台账和规则,并放了 `.gitignore`,所以这些文件不会进 git。项目特有的红线可以写进 `.claude/butler/规则.md`。
>
> **需要你拍板**:选一个。
> - A:改在普通会话里直接做。
> - B:仍用管家。只开一张工单 T-001,不定契约,由一个 Worker 做完,再由验收 subagent 独立检查。
>
> **推荐**:A。
>
> 如果选 B,以下几处是我先替你定的,你可以改:
> - 接口:`GET /api/todos`、`POST /api/todos`(body 为 `{text}`)、`POST /api/todos/:id/done`。
> - 端口:默认 3000,可用 `PORT` 环境变量改。
> - 数据:复用 `todo.js` 的 `add`、`done`、`load`,沿用 `TODO_FILE`。
> - 错误:空文本返回 400,id 不存在返回 404。
> - 测试:用 `node --test`,测试时用临时的 `TODO_FILE`。
> - 改动范围:只新增文件,并改 README,不改 `todo.js`。
> - 提交:不提交,也不合并。

它认为这件事不值得用管家，理由是"没有能并行的部分"。不过它替用户定的默认值都列了出来。

### 第 2 次

```
/butler 继续：选 B，仍用管家。不过我觉得接口和前端页面其实能分开、并行做，你再看看怎么拆。你列的那几项默认值都可以。
```

管家写了契约 C-001、工单 T-001 和 T-002，更新台账后回复：

> **结论**:已拆成两张工单,按文件边界互不重叠,可以并行。接口格式先定成契约 C-001,两边都照它做。
>
> | 工单 | 内容 | 改动文件 |
> |---|---|---|
> | T-001 | HTTP 服务、三个 JSON 接口、静态页托管、接口测试、README 启动说明 | `server.js`、`test/server.test.js`、`README.md`;`package.json` 里加 `start` 脚本 |
> | T-002 | 单页前端:列出、新增(按钮和回车)、勾选完成 | 只新增 `public/index.html` |
>
> 两个 Worker 各用独立 worktree 并行,都不提交。完成后我派验收 subagent 独立检查,再把分支和 worktree 的清单交给你决定合并。
>
> 我自己拿主意、还没和你确认的地方:
> - 已完成的待办,复选框选中且禁用,因为接口不支持取消完成。
> - 重复标记完成仍返回 200。
> - 路径对但方法不对,返回 405。
> - 文本存入前去掉首尾空白。
> - 前端是单文件,JS 和 CSS 内联,不用任何外部资源。
> - 前端用 `textContent` 渲染用户输入,防止注入。
>
> **需要你拍板**:是否按这个拆分派发?详情见 `.claude/butler/契约/C-001.md` 和 `工单/T-001.md`、`T-002.md`。
>
> **推荐**:确认后派发。接口格式已在契约里写死,并行做不会对不上。

### 第 3 次

```
/butler 继续：方案没问题，开始吧。
```

这次调用跑了 5 分 10 秒，管家发了 5 条消息。后台 Worker 每结束一次，主线程就被唤醒一次，所以中间几条只是通报进度，"需要你拍板"都是"无"。

派出两个 Worker 后：

> **结论**:T-001(接口、测试、README)和 T-002(前端页面)已并行派发,各在独立 worktree 里做,都不提交。台账和工单已更新。
>
> **需要你拍板**:无。
>
> **推荐**:等两边都汇报后,我再派验收 subagent 独立检查,到时一并向你汇报结果和分支清单。

两个 Worker 交付，管家用 `git -C <worktree> status --short` 核对文件范围，再派出验收 subagent：

> **结论**:T-001 和 T-002 的 Worker 都已交付,我核对了 git:改动文件都在授权范围内,没有越界。验收 subagent 已派出,联调两边的代码。
>
> **需要你拍板**:无。
>
> **推荐**:等验收结果出来再汇报。其中有一点需要你留意,T-001 多加了两个契约没写的行为:非法 JSON 请求体返回 400,请求体超过 64KB 返回 413。我倾向保留,验收通过后会补进 C-001。

验收结果回来，管家用 SendMessage 把问题退回 T-001 原来的 Worker：

> **结论**:验收两张工单都通过。联调时 `npm test` 12/12 全绿,curl 走通了所有接口和错误情形,改动也都在授权范围内。
>
> **问题**:T-001 有 1 个轻微问题。请求体超 64KB 时,服务端直接断开连接,不是 Worker 汇报的 413,也没有测试覆盖。我已经退回原 Worker 修复并补测试,修完后我会复核。
>
> **没验到的**:前端的点击、回车提交和出错提示只读了代码,没在真实浏览器里点过。验收只在 headless Chrome 里确认了页面渲染,以及 `<b>` 被当作文本转义。
>
> **需要你拍板**:无。合并要等 T-001 修好、复核通过之后再问你。
>
> **推荐**:返工修好后,把"非法 JSON 返回 400、超大请求体返回 413"补进契约 C-001。这两条是 Worker 额外加的,我倾向保留。

返工交付后，管家派了复核 subagent：

> **结论**:T-001 的返工已交付。Worker 说超 64KB 的请求体现在返回 413,`npm test` 13/13 全绿。这些是它的自述,我已派复核 subagent 独立检查,还没出结果。
>
> **新情况**:Worker 写不进工单文件,所以返工汇报是我代记的。它还指出,超限后服务端会一直读取并丢弃剩余请求体,没有总量上限。复核会顺带评估这是否需要加上限。
>
> **需要你拍板**:无。
>
> **推荐**:等复核结果。如果建议加上限,我直接退回原 Worker 小改,不用打扰你。

复核通过，进入收尾：

> **结论**:T-001 和 T-002 都验收通过,可以收尾。T-001 返工后,复核实测超 64KB 的请求体会收到 413,`npm test` 13/13 全绿。
>
> **留下的分支和 worktree**(都还没提交、没合并):
>
> | 工单 | 分支 | 状态 |
> |---|---|---|
> | T-001 | `worktree-agent-af843a1d18fcb2f4e` | 未合并 |
> | T-002 | `worktree-agent-a35373c87ec5924e5` | 未合并 |
>
> **需要你拍板**:
> 1. 是否让两个 Worker 各自提交,把改动合并到 main,再删除这两个 worktree 和分支?合并和删除都要你同意。
> 2. 是否给"超限后丢弃请求体"加上限?复核认为风险低:不占内存,受 Node 的 300 秒请求超时约束。
>
> **推荐**:
> 1. 合并并清理。
> 2. 不加。这是本地小工具,没必要。
>
> 另外两点你可能想知道:
> - 前端的点击、回车提交和出错提示还没在真实浏览器里点过。合并后你可以启动一次看看:`npm start`,打开 `http://localhost:3000`。
> - 我把 Worker 额外加的两个行为补进了契约 C-001:非法 JSON 返回 400,超大请求体返回 413。

### 第 4 次

```
/butler 继续：全部合并到 main，删掉 worktree。上限不用加。
```

管家派了一个新的 subagent 去提交、合并、跑测试、删 worktree 和分支，自己再用 `git worktree list`、`git ls-files`、`git branch` 核对：

> **结论**:已派 Worker 去合并并清理。它会在两个 worktree 里各提交一次,按顺序合并进 main,在合并后的 main 上跑 `npm test`,测试通过后再删除两个 worktree 和分支。不加请求体上限,也不 push。
>
> **需要你拍板**:无。
>
> **推荐**:等 Worker 回报后,我用 git 核对合并结果,再把台账收尾。

> **结论**:网页界面已全部合并进 main,两个 worktree 和分支都已删除,没有 push。我用 git 核对过:main 工作区干净,新增了 `server.js`、`public/index.html`、`test/server.test.js`,README 和 `package.json` 也已更新。Worker 在合并后的 main 上跑 `npm test`,13 个测试全过。
>
> **怎么用**:`npm start`,然后打开 `http://localhost:3000`。
>
> **需要你拍板**:无。
>
> **留意两点**:
> - 前端的点击、回车提交和出错提示还没在真实浏览器里点过,建议你启动后试一下。
> - 合并提交 `bc658f8` 用的是 git 默认信息,没有 Co-Authored-By 署名行。要补的话需要改写这条提交,所以我没动。需要的话告诉我。

## 工单与契约

| 编号 | 目标 | 执行者 | worktree | 验收结果 | 返工次数 |
|---|---|---|---|---|---|
| [T-001](state/工单/T-001.md) | `server.js`、JSON 接口、接口测试、README | subagent `af843a1d18fcb2f4e` | 是 | 首验通过但有 1 个轻微问题（超过 64KB 时断开连接，不是 413），返工后复核通过 | 1 |
| [T-002](state/工单/T-002.md) | 单页前端 `public/index.html` | subagent `a35373c87ec5924e5` | 是 | 通过，0 个问题 | 0 |

契约 [C-001](state/契约/C-001.md) 规定了接口路径、请求和响应格式、错误码、静态页和前端行为，两张工单都引用它。验收后管家把 Worker 额外加的两条行为（非法 JSON 返回 400，超过 64KB 返回 413）补进了契约，变更记录里"谁拍板"写的是"管家（待用户知悉）"。事先没有问用户，只在汇报里说了"我倾向保留"。

另外三个 subagent 不对应工单：验收 `a2c9a2e0523b8bdbf`（两张工单一起验，含联调），复核 `ab6c5f7042f84f055`（T-001 返工），收尾合并 `af968de858c1881f9`。台账见 [state/台账.md](state/台账.md)，[规则.md](state/规则.md) 保持模板原样。

## 并行与拦截

**并行**：两个 Worker 都是后台 subagent，各在自己的 worktree 里。按 subagent 日志的时间戳（UTC），T-001 在 09:16:24–09:17:37，T-002 在 09:16:28–09:17:26，两段时间重叠。同时最多 2 个，没碰到 3 个的上限。

**守卫**只拦过一次。管家想用 heredoc 把 T-001 的返工汇报追加进工单，收到：

> PreToolUse:Bash hook error: 管家守卫：管家窗口只能跑只读查看命令，这条不行：heredoc <<。允许的有：ls、cat、head、tail、wc、pwd、cd、echo；git status、git diff --stat、git diff --name-only、git log、git show、git ls-files、git rev-parse、git branch、git worktree list（可加 -C <路径>）；往 .claude/butler/ 里 mkdir、cp、输出重定向。命令写直白些：路径写全，不用变量。 请把这件事开成工单派给 Worker。当前是 bypassPermissions 模式，守卫没法弹窗问用户，只能直接拒绝；用户真要管家自己改，得先切换到别的权限模式。

要写的是 `.claude/butler/` 里的文件，本来允许，被拦的只是写法，末尾那句"开成工单"在这里不适用。管家没有换命令硬写，改用 Edit 写进了工单。

**Claude Code 自带的 worktree 隔离**也拦过 Worker。worktree 里的 subagent 写主目录下的工单文件时，heredoc 命令和 Edit 都被拒绝，Edit 的报错是"Edit the worktree copy of this file instead of the shared-checkout path."。拦得不一致：T-001 第一次用 heredoc 追加成功了，T-002 和 T-001 返工时都被拒。T-001 返工时 Worker 把四项汇报发回管家，由管家代记。T-002 的 Worker 改用一条 `printf`，只写了一行"详见 Worker 返回消息"，管家后来也没补全，所以 T-002 里的 Worker 汇报只有结论。

## 结果

管家窗口没有改过项目文件：主线程的 27 次 Write/Edit 都在 `.claude/butler/` 里，21 次 Bash 里有 20 次是 `ls`、`cat`、`head`、`tail`、`mkdir`、`cp` 和只读的 git 查询，剩下 1 次是上面被拦的 heredoc。

```
$ git log --oneline
bc658f8 Merge branch 'worktree-agent-a35373c87ec5924e5'
bf95e48 tiny-todo: add HTTP server with JSON API and tests
0cd93b5 tiny-todo: add single-page web UI
364ce2c tiny-todo: add, done, list

$ git diff --stat 364ce2c..main
 README.md           |  33 ++++++++++++-
 package.json        |   2 +-
 public/index.html   | 125 +++++++++++++++++++++++++++++++++++++++++++++++
 server.js           | 119 +++++++++++++++++++++++++++++++++++++++++++++
 test/server.test.js | 137 ++++++++++++++++++++++++++++++++++++++++++++++++++++
 5 files changed, 413 insertions(+), 3 deletions(-)

$ npm test
# tests 13
# pass 13
# fail 0
```

我自己用临时的 `TODO_FILE` 启动了服务：

```
$ PORT=3917 node server.js
$ curl -s -o /dev/null -w '%{http_code} %{content_type}\n' localhost:3917/
200 text/html; charset=utf-8
$ curl -s -X POST -H 'Content-Type: application/json' -d '{"text":"买牛奶"}' localhost:3917/api/todos
{"id":1,"text":"买牛奶","done":false}
$ curl -s -X POST localhost:3917/api/todos/1/done
{"id":1,"text":"买牛奶","done":true}
```

管家最后提醒前端的点击没在真实浏览器里试过，我用 Playwright 在 Chromium 里补了一遍：输入后回车能新增，勾选后复选框变成选中并禁用，控制台没有报错。

## 每次调用的数字

| 调用 | 墙钟 | result 事件 | 主线程 duration_ms 合计 | 主线程 turns | 输入 | 缓存写入 | 缓存读取 | 输出 |
|---|---|---|---|---|---|---|---|---|
| 第 1 次 | 31 秒 | 1 | 29.9 秒 | 12 | 10 | 16,160 | 111,224 | 2,600 |
| 第 2 次 | 52 秒 | 1 | 50.6 秒 | 10 | 12 | 12,557 | 175,430 | 4,834 |
| 第 3 次 | 310 秒 | 5 | 144.9 秒 | 32 | 114 | 101,220 | 1,743,630 | 37,272 |
| 第 4 次 | 56 秒 | 2 | 37.7 秒 | 12 | 24 | 26,293 | 532,837 | 5,473 |

token 数取自每次调用前后 `modelUsage` 的差值，包含 subagent。一次调用里有几个 result 事件，就是管家发了几条消息。四次调用的墙钟合计约 7.5 分钟。

## 其他值得一提的

- 收尾时台账写上了合并提交号，当前目标标成"已完成 2026-11-04"，但合并和清理的结果没有记进两张工单的「记录」。
- 第 4 次最后一条提到合并提交"没有 Co-Authored-By 署名行"。这是 Claude Code 自己的提交署名设定，用户没提过。
- 主线程偶尔夹着英文的过程说明，比如 "Now update the ledger."、"Verified. Closing out the ledger."，不在给用户的汇报里。

## 之后 skill 改了什么

这次运行和英文那次一起，促成了下面这些修改。上面的记录展示的是修改之前的表现。

- **值不值得用管家**：三条要同时满足（只动一两个文件、没有能并行的部分、活很小）才建议不用；前端和后端这类能先定契约再分头做的部分，算能并行。
- **拆分**：几部分靠接口互相依赖时，先把接口写成契约再拆开，不合成一张工单。
- **读代码**：要改的代码交给 subagent 读，带回涉及哪些文件、哪些部分能分开做；管家自己不读项目代码。
- **过目**：用户明确说可以才算确认；用户提了问题或修改意见，改完再过目一次。
- **汇报**：派发之后、有结论或要拍板之前，不给用户发消息。
- **工单路径**：终端版 worktree 里的 Worker 常常写不进工单文件，发回的四项汇报要原样记进工单，不能只记结论。
- **收尾**：合并和清理由管家先写成工单再派发；Worker 汇报后管家自己用 git 核实，结果记进这张工单。
- **守卫**：只是写法没法核对而被拦下时（比如用 heredoc 写工单），提示改为先换成直白写法再试，不再一律提示开成工单；`cd` 之后用 `cp` 写到 `.claude/butler/` 里的绝对路径，不再拦。
