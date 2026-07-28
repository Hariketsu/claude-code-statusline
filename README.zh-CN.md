# Claude Code Statusline

[English](./README.md) | 中文

 个人自用 Claude Code 状态栏脚本，Gruvbox Dark 配色。支持 DeepSeek、Grok 等第三方模型及 Anthropic 兼容网关。

![statusline 演示](assets/statusline-demo.png)

## 快速开始

**前置要求：** Claude Code、[`jq`](https://jqlang.github.io/jq/)，终端需使用 [Nerd Font](https://www.nerdfonts.com/)。`git` 可选——有则显示分支和改动行数。

**Windows 用户**请用 [Git Bash](https://git-scm.com/download/win)，确保 `jq` 在 PATH 中，建议搭配 [Windows Terminal](https://aka.ms/terminal) + Nerd Font。无需 PowerShell 移植，同一份脚本即可。更多平台说明见 [ROADMAP.md](./ROADMAP.md)。

### 1. 安装 jq

```sh
# macOS
brew install jq

# Ubuntu / Debian
sudo apt-get install jq

# Windows
# winget install jqlang.jq
```

### 2. 安装脚本

```sh
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

### 3. 配置 Claude Code

`~/.claude/settings.json`（Windows：`%USERPROFILE%\.claude\settings.json`）：

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

`command` 路径请用 `~/...` 或正斜杠（如 `C:/Users/你/.claude/statusline.sh`），避免未转义的反斜杠 `\`。

| 配置项 | 说明 |
|--------|------|
| `padding` | 左右留白，`0` 为紧凑模式 |
| `refreshInterval` | 刷新间隔，单位**秒**。空闲状态下时长和 git 依赖此值更新 |

改完重启 Claude Code 生效。

## 显示内容

| 段 | 示例 | 说明 |
|----|------|------|
| 模型 | `𝕏 4.5` / `🐋 v4 pro` | 网关映射的模型名 → `.model.id` 短名 → `display_name`，自动识别 |
| 思考强度 | `󰧑 high` | `.effort.level`，无则隐藏 |
| 目录 | `my-project` | `.workspace.current_dir` 的 basename |
| Git | ` master +12 −3` | 分支名或 detached SHA；改动行数来自真实 git |
| 上下文 | `󰡳 15%/500k` | token 占用与上限 |
| 时长 | `1h2m` | `.cost.total_duration_ms` |

为保持紧凑，不显示 token 明细、费用估算、进度条等信息。

### Git 改动行数

分别统计未暂存和已暂存：

```sh
git diff --shortstat            # 未暂存
git diff --cached --shortstat   # 已暂存
```

两者累加。提交后工作区干净则自动隐藏 `+N −M`。注意这里用的是**真实 git 数据**，不是会话累计字段 `cost.total_lines_added` / `total_lines_removed`。

### 上下文

显示格式：Nerd Font 图标 + `占用比例/上限`，如 `󰡳 15%/500k`。

**Token 用量**（按优先级）：
1. `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`
2. 缺失的 cache 字段按 `0` 计
3. 以上均无则回退到 `used_percentage`

**上限取值**：
1. `.context_window.context_window_size`（Claude Code 下发）
2. `$CLAUDE_CODE_MAX_CONTEXT_TOKENS`
3. 默认 `200000`

**图标档位**（按占用比例）：`<30%` / `30–54%` / `55–84%` / `≥85%`

**颜色逻辑**：按剩余 token 量动态调整，而非固定的 70% / 90% 阈值。

脚本只读取 Claude Code 提供的 JSON 和环境变量，不会按模型名硬编码上下文上限。

### 第三方模型

Claude Code 对未识别的模型 ID 默认按 **200k** 窗口处理。如果你的模型实际更大（如 Grok 4.5 为 500k），在 `~/.claude/settings.json` 的 `env` 中配置：

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
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | 告知 Claude Code 上下文上限，影响状态栏分母 |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | 仅影响自动压缩计算，不直接改变状态栏显示 |

需要 **Claude Code ≥ 2.1.193**。配置后重启会话。参考：[Claude Code 环境变量](https://code.claude.com/docs/en/env-vars)。

## 自定义

### 关闭 emoji 图标

```json
"command": "USE_EMOJI_MODEL=0 ~/.claude/statusline.sh"
```

| 默认 | `USE_EMOJI_MODEL=0` |
|------|---------------------|
| `𝕏 4.5` | `Grok 4.5` |
| `🐋 v4 pro` | `DS v4 pro` |
| `🐋 v4 flash` | `DS v4 flash` |

### 添加新模型

编辑 `statusline.sh` 中的 `case "$model_id|$model_name" in` 块，按子串匹配添加你的模型。

### 调整颜色

脚本顶部的 `C_*` 变量，Gruvbox Dark 色板，truecolor ANSI。

## 测试

用 mock JSON 快速验证：

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

# 语法检查
bash -n statusline.sh
```

Windows 下 mock JSON 的路径写成 `"current_dir": "C:/Users/Public"`（正斜杠）即可。

## 排错

| 现象 | 可能原因 |
|------|----------|
| 状态栏无显示 | 未 `chmod +x`，或未接受工作区信任 |
| 图标显示为方框 / 豆腐块 | 终端字体不是 Nerd Font |
| Windows 路径不工作 | 使用了未转义的反斜杠，改用 `~/...` 或 `C:/...` |
| `jq: command not found` | Git Bash 的 PATH 中没有 `jq` |
| 上下文上限不对 | Claude Code 侧 env 未配或未重启 |
| 提交后仍显示 `+N −M` | 升级脚本，确保行数来自 git shortstat |
| 时长始终 `0m` | 未配置 `refreshInterval` |
| 上下文显示 `--` | 首次会话尚未返回用量数据，正常 |
| 无 Git 段 | 不在 Git 仓库，或 git 执行失败 |

## License

MIT
