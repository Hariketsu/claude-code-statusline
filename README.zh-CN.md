# Claude Code Statusline

[English](./README.md) | 中文

一个自定义的 [Claude Code](https://code.claude.com/docs/en/statusline) 状态栏脚本。单行布局，风格参考 Starship，配色为 Gruvbox Dark。面向第三方 / Anthropic 兼容模型友好（DeepSeek、Grok、CPA 网关等）。

![statusline 演示](assets/statusline-demo.png)

## 快速开始

**依赖：** Claude Code、[`jq`](https://jqlang.github.io/jq/)、可选 `git`、终端使用 [Nerd Font](https://www.nerdfonts.com/)。

```sh
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

```sh
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

在 `~/.claude/settings.json` 中加入：

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0,
    "refreshInterval": 30
  }
}
```

| 配置项 | 作用 |
|--------|------|
| `padding` | 额外左右留白；`0` 更紧凑 |
| `refreshInterval` | 每隔 **N 秒**（不是毫秒）重跑脚本，空闲时时长和 git 才会更新 |

改完设置后请重启 Claude Code / 新开会话。

## 显示内容

| 段 | 示例 | 数据来源 |
|----|------|----------|
| 模型 | `𝕏 4.5` / `🐋 v4 pro` | 由 `.model.id` 映射短名，否则 `display_name` / id |
| 思考强度 | `󰧑 high` | `.effort.level`（有则显示，无则隐藏） |
| 目录 | `my-project` | `.workspace.current_dir` 的 basename |
| Git | ` master +12 −3` | 分支或 detached 短 SHA；行数为**真实 git**（见下） |
| 上下文 | `󰡳 15%/500k` | token 占用 + 上限（见下） |
| 时长 | `1h2m` | `.cost.total_duration_ms` |

### Git 增删行数

```sh
git diff --shortstat            # 未暂存
git diff --cached --shortstat   # 已暂存
```

两者相加。提交后工作区干净则**不显示** `+N −M`。

这里**不是**会话累计字段 `cost.total_lines_added` / `total_lines_removed`。

### 上下文

- **显示：** Nerd Font 电量/刻度图标 + `百分比/上限`（如 `󰡳 15%/500k`）
- **占用（优先）：** `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`  
  cache 字段缺失按 `0`；token 明细都没有时再回退 `used_percentage`
- **上限优先级：**
  1. `.context_window.context_window_size`（Claude Code 下发）
  2. `$CLAUDE_CODE_MAX_CONTEXT_TOKENS`（若进程环境里有）
  3. `200000`
- **图标档位**（占用 %）：`<30` / `30–54` / `55–84` / `≥85`
- **颜色**（按剩余 token）：danger / warning 阈值看剩余量，而不是固定 70%/90% 占用

脚本只**读取** Claude Code 给的 JSON 与环境变量，**不会**按模型名写死上下文上限。

#### 第三方模型

Claude Code 对未识别的模型 ID 常常按 **200k** 窗口处理。若上游实际更大（例如 **Grok 4.5** 的 500k），请在 Claude Code 的 `~/.claude/settings.json` 的 `env` 中配置，然后**重启会话**：

```json
{
  "env": {
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "500000",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "500000"
  }
}
```

| 变量 | 作用 |
|------|------|
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | 让 Claude Code 按该大小假定上下文（影响下发的 `context_window_size` / 状态栏分母，对非 Claude 模型名尤其有用）。 |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | 仅用于**自动压缩**相关计算；单独设置不会替代状态栏上限。 |

这两个环境变量需要 **Claude Code ≥ 2.1.193** 才会生效（对非 Claude 模型 ID 尤其如此）。数值请按你的真实模型上限修改。官方说明：[Claude Code 环境变量](https://code.claude.com/docs/en/env-vars)。

## 故意不显示

为保持紧凑，默认不做：

- 拆开的 token 明细（input / output / 缓存命中率芯片）
- 客户端费用估算（对第三方账单往往不准）
- Rate limit（偏 Claude.ai 订阅字段）
- 进度条、多行布局

## 自定义

### 纯文本模型名

```json
{
  "statusLine": {
    "type": "command",
    "command": "USE_EMOJI_MODEL=0 ~/.claude/statusline.sh"
  }
}
```

| 默认 | `USE_EMOJI_MODEL=0` |
|------|---------------------|
| `𝕏 4.5` | `Grok 4.5` |
| `🐋 v4 pro` | `DS v4 pro` |
| `🐋 v4 flash` | `DS v4 flash` |

### 增加模型短名

改 `statusline.sh` 里 `case "$model_id" in`（对 `.model.id` 做子串匹配）。

### 颜色

脚本顶部 `C_*`，Gruvbox Dark，truecolor ANSI。

## 测试

```sh
printf '%s\n' '{
  "model": {"id": "grok-4.5", "display_name": "Grok"},
  "workspace": {"current_dir": "/tmp/demo"},
  "effort": {"level": "high"},
  "cost": {"total_duration_ms": 3720000},
  "context_window": {
    "context_window_size": 500000,
    "current_usage": {
      "input_tokens": 75000,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0
    }
  }
}' | ./statusline.sh

bash -n statusline.sh
```

## 排错

| 现象 | 可能原因 |
|------|----------|
| 状态栏空白 | 未 `chmod +x`，或未接受工作区信任 |
| 图标变方框 | 终端字体不是 Nerd Font |
| 上下文上限不对 | 以 Claude Code 下发的 JSON/默认为准；在 CC 侧改 env 后重启会话 |
| 干净提交后仍有 `+N −M` | 升级脚本：行数应来自 git shortstat，而非会话 cost |
| 时长一直 `0m` | 设置 `refreshInterval`（单位：秒） |
| 上下文显示 `--` | 首次 API 占用字段出现前属正常 |
| 无 Git 段 | 不在仓库内，或 git 失败（该段可缺失） |

## Windows支持

细节与后续路线见 [ROADMAP.md](./ROADMAP.md)。

## License

MIT
