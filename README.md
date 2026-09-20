# EarTap

**把耳机的播放按键映射为自定义键盘快捷键。**

A small macOS menu bar app that maps media commands to a configurable keyboard shortcut.

EarTap 将 macOS 发来的播放（`play`）和播放/暂停切换（`toggle`）命令映射为当前应用中的同一个快捷键；暂停（`pause`）命令仅记录日志，不发送快捷键，以避免已观察到的耳机关机误触。适合触发输入法语音输入，或目标应用支持的其他快捷操作。

> **状态：0.1.1，实验性。** 系统决定哪个应用接收媒体命令。EarTap 不保证每次实体按键都能送达，也不能确认目标应用是否执行了快捷键。

## 功能边界

- 一个菜单栏应用，一份快捷键配置；配置保存后下次触发即生效。
- 默认快捷键为 `Command + Shift + V`，可改为其他组合或单键。
- 菜单中可以暂停映射、测试快捷键、检查权限和查看日志。
- 不录音、不识别文字、不读取目标应用的录音状态、不联网。
- 不实现“第一次开始、第二次结束”；通过过滤的 `play` / `toggle` 命令都发送相同配置。
- 不映射音量键，也不是全局键盘重映射工具。

## 构建与安装

需要 macOS 13 或更新版本，以及 Xcode Command Line Tools。原生支持 Apple Silicon 与 Intel，构建产物对应当前机器架构。

```bash
xcode-select --install  # 已安装开发工具可跳过

git clone https://github.com/houhongxu/ear-tap.git
cd ear-tap
./scripts/test.sh
./scripts/build.sh
./scripts/install.sh
open "$HOME/Applications/EarTap.app"
```

安装脚本将应用放在 `~/Applications/EarTap.app`，不会自动启动、设置开机启动或更改系统媒体路由配置。也可手动复制 `build/EarTap.app` 到固定位置后打开。

1. 从菜单栏 **EarTap → 检查辅助功能权限**，在系统设置中允许当前 EarTap。
2. 确认目标应用支持配置中的快捷键，点入需要操作的窗口。
3. 按耳机播放键；收到的播放、切换命令映射为同一个快捷键，暂停命令被忽略。

开始或重复打开 EarTap 本身不会发送按键。使用其他播放器时，可先从菜单暂停映射或退出，释放 EarTap 的媒体会话。键盘媒体键或其他媒体遥控器也可能被系统路由给 EarTap，无法仅限定某副耳机。

首次授权以实际安装的应用为准。本地构建使用 ad-hoc 签名，重新构建后的授权是否保留取决于系统；单纯修改配置无需重新构建或授权。

## 自定义快捷键

运行配置位于：

```text
~/Library/Application Support/EarTap/shortcut.json
```

从 **EarTap → 编辑快捷键配置** 打开，用文本编辑器修改并保存：

```json
{
  "key": "v",
  "modifiers": ["shift", "command"],
  "settleDelayMs": 250,
  "eventIntervalMs": 40,
  "keyHoldMs": 80
}
```

例如改成 `Control + Option + Space`，将 `key` 改为 `space`、`modifiers` 改为 `["control", "option"]`。目标应用的快捷键也须匹配。完整键名、单键配置和参数说明见 [配置说明](docs/configuration.md)。

配置损坏时不发送按键，菜单和日志会给出错误。修正配置后，下次触发自动恢复。更新或重新安装应用不会覆盖已有配置。

## 排查没有反应

先使用菜单中的 **测试快捷键（2 秒后）**，在两秒内回到目标输入框。它只检查快捷键链路，不验证耳机或系统路由。

| 现象 | 检查方向 |
| --- | --- |
| 实体按键后“收到”没有增加 | 先查日志是否有 `IGNORED source=pause reason=pause-filter`；否则可能命令未送达 EarTap |
| “收到”增加，“已发送”不增加 | 辅助功能权限、配置错误、按住修饰键、等待过久或暂停状态 |
| “已发送”增加，目标应用无反应 | 目标应用快捷键、焦点和当前界面是否支持该操作 |
| 快捷键测试有效，耳机不稳定 | 系统媒体路由与设备兼容性；调整快捷键延迟不能保证解决 |

日志保留最近约 500 行，只包含时间、请求编号、来源、配置的快捷键和处理结果，不包含输入文本、音频或转写内容。`SENT` 仅表示按键事件已提交。程序不知道未送达的实体按键次数，因此不能从日志计算硬件按键成功率。

更多说明见 [故障排查](docs/troubleshooting.md)。

## 开发

```bash
./scripts/test.sh   # 配置、按键序列和调度回归；不发送真实按键
./scripts/build.sh  # 编译并签名，输出 build/EarTap.app
```

| 目录 | 内容 |
| --- | --- |
| `src/` | 应用生命周期、媒体接收、快捷键解析/发送、本地存储 |
| `resources/` | 应用元数据与默认配置 |
| `tests/` | 不依赖辅助功能权限的自动测试 |
| `scripts/` | 构建、安装、测试 |
| `docs/` | 配置、排查、架构说明 |

构建与测试在 GitHub Actions 的 macOS 环境运行。自动测试不证明耳机端到端可靠性。架构和验证边界见 [开发说明](docs/development.md)，贡献方式见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 卸载

从菜单退出 EarTap，再删除安装的 `EarTap.app`。如不再需要配置和日志，可手动删除 `~/Library/Application Support/EarTap/`；也可从系统辅助功能列表移除 EarTap。项目不安装后台服务或开机启动项。

## 许可证

[MIT](LICENSE)。本项目独立开发，不隶属于任何耳机厂商或目标应用厂商。
