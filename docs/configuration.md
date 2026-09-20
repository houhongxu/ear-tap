# 快捷键配置

EarTap 第一次启动时，将包内 `shortcut.json` 复制到 `~/Library/Application Support/EarTap/shortcut.json`。每次准备处理请求时读取配置；正在处理的请求使用已经读取的配置。安装和升级保留已有配置。

只支持以下字段，未知字段也会报错，避免拼写错误被静默忽略。

| 字段 | 要求 | 默认值 |
| --- | --- | --- |
| `key` | 必填字符串，见下方支持列表；字母不区分大小写 | `v` |
| `modifiers` | 必填数组，允许为空，最多 5 个不重复的修饰键 | `["shift", "command"]` |
| `settleDelayMs` | 可选数字，10–1500 毫秒 | 250 |
| `eventIntervalMs` | 可选数字，10–1500 毫秒 | 40 |
| `keyHoldMs` | 可选数字，10–1500 毫秒 | 80 |

支持的 `key`：`a`–`z`、`0`–`9`、`space`、`return`、`escape`、`tab`、`delete`、`left`、`right`、`up`、`down`。`delete` 表示退格键。

支持的修饰键：`command`、`shift`、`option`、`control`、`fn`。名称必须小写。按数组顺序按下，反向释放。

键名对应 macOS 的 ANSI 物理键位，不是插入指定 Unicode 字符。在不同键盘布局或输入法下，实际字符由系统决定。`fn` 的行为也可能受系统设置和目标应用影响。

## 示例

`Control + Option + Space`：

```json
{
  "key": "space",
  "modifiers": ["control", "option"]
}
```

仅发送空格：

```json
{
  "key": "space",
  "modifiers": []
}
```

单键会作用于当前前台窗口；例如空格可能输入字符或触发当前控件。EarTap 不知道目标应用是否正在录音。播放、暂停、切换三种命令没有单独的映射规则。

## 时间参数

- `settleDelayMs`：处理一个请求前的等待。
- `eventIntervalMs`：修饰键和释放事件之间的间隔。
- `keyHoldMs`：主键按下与松开之间的间隔。

通常保留默认值。毫秒值发送时取整数。等待超过 3 秒的请求会取消；输入事件一旦开始，整组按键会发送完并释放修饰键，因此较大时间值可能延长退出等待。参数不能修复没有到达 EarTap 的媒体命令。

## 检查 JSON

```bash
./build/EarTap.app/Contents/MacOS/EarTap --validate "$HOME/Library/Application Support/EarTap/shortcut.json"
```

该命令只解析配置，不发送按键、不注册媒体会话。JSON 不支持注释和尾随逗号。无效配置会使对应请求取消，修正后再次触发即可。
