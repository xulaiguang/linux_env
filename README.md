# Vim + Tmux 一键配置工具

## 快速开始

```bash
# 执行完整安装
~/dotfiles/setup-env.sh

# 或逐步操作
cd ~/dotfiles
./setup-env.sh
```

## 功能特性

### Vim 配置亮点
- **插件管理器**: vim-plug
- **文件管理**: NERDTree (F4 开关)
- **模糊搜索**: fzf + fzf.vim (Ctrl+p)
- **语法检查**: ALE 异步检查
- **状态栏**: vim-airline
- **Git 集成**: vim-fugitive + vim-gitgutter
- **代码补全**: auto-pairs, vim-surround
- **配色**: gruvbox + termguicolors

### Tmux 配置亮点
- **前缀键**: Ctrl+a (比默认 Ctrl+b 更顺手)
- **鼠标支持**: 开启鼠标模式
- **快捷键**:
  - `Ctrl+h/j/k/l` -  pane 间跳转（无需前缀）
  - `\` - 垂直分屏
  - `-` - 水平分屏
  - `prefix + z` - 最大化 pane
  - `prefix + I` - 安装插件

### 自动化功能
- 自动备份现有配置
- 自动创建目录结构
- 自动安装 vim-plug
- 自动安装 fzf
- 自动安装 tpm (tmux plugin manager)

## 使用方法

### 交互式菜单

```bash
./setup-env.sh
# 选择:
# 1) 完整安装 (Vim + Tmux)
# 2) 仅安装 Vim
# 3) 仅安装 Tmux
# 4) 仅备份当前配置
# 5) 退出
```

### 命令行参数

```bash
# 完整安装
./setup-env.sh

# 仅 Vim
./setup-env.sh --vim-only

# 仅 Tmux
./setup-env.sh --tmux-only

# 仅备份
./setup-env.sh --backup

# 从备份恢复（交互式）
./setup-env.sh --restore
```

## 目录结构

```
~/dotfiles/
├── setup-env.sh      # 一键配置脚本
├── README.md         # 本说明文件
├── vim/
│   └── .vimrc        # Vim 配置
└── tmux/
    └── .tmux.conf    # Tmux 配置
```

## 安装后操作

### Vim 插件

首次运行 vim 后，安装插件：

```
:PlugInstall
```

或命令行：

```bash
vim +PlugInstall +qall
```

### Tmux 插件

启动 tmux 后安装插件：

```
prefix + I  (大写 I)
```

## 常用快捷键速查

### Vim
| 快捷键 | 功能 |
|--------|------|
| F4 | 开关 NERDTree 文件树 |
| Ctrl+p | 文件模糊搜索 |
| leader + / | 全局文本搜索 (Rg) |
| leader + b | Buffer 搜索 |
| F8/F9 | 开启/关闭粘贴模式 |

### Tmux
| 快捷键 | 功能 |
|--------|------|
| Ctrl+a | 前缀键 |
| Ctrl+h/j/k/l | pane 间跳转 |
| \ | 垂直分屏 |
| - | 水平分屏 |
| prefix + z | 最大化 pane |
| prefix + b | 弹出小终端 |
| prefix + x | 关闭 pane (确认) |

## 高级用法

### 多设备同步

将 `~/dotfiles` 目录放入 Git 版本控制：

```bash
cd ~/dotfiles
git init
git remote add origin <your-git-url>
git add .
git commit -m "Initial dotfiles"
git push origin main
```

### 在新设备上快速配置

```bash
git clone <your-git-url> ~/dotfiles
~/dotfiles/setup-env.sh
```

## 版本要求

| 软件 | 最低版本 | 推荐版本 | 关键特性依赖 |
|------|----------|----------|--------------|
| Vim | 8.0+ | 8.2+ / 9.0+ | termguicolors, ALE, fzf.vim |
| Tmux | 3.2+ | 3.4+ | popup 窗口, OSC52 剪贴板同步 |

### 版本兼容性说明

**Vim 8.0+** 需要：
- `set termguicolors` - 真彩色支持
- ALE 异步语法检查
- fzf.vim 模糊搜索
- `has('persistent_undo')` - 持久化 undo

**Tmux 3.2+** 需要：
- `bind popup` - 弹出式终端
- `set -g allow-passthrough on` - OSC 52 剪贴板
- `set -s set-clipboard on` - 剪贴板同步

**Tmux 2.1-3.1** 兼容，但：
- `set -g mouse on` → `set -g mode-mouse on`
- 无 popup 功能
- 剪贴板功能受限

### 升级方法

```bash
# Ubuntu/Debian 编译安装新版 Tmux
sudo apt install build-essential libevent-dev ncurses-dev
wget https://github.com/tmux/tmux/releases/download/3.4/tmux-3.4.tar.gz
tar xzf tmux-3.4.tar.gz
cd tmux-3.4
./configure && make
sudo make install
```

## OSC 52 剪贴板同步配置

OSC 52 是一个终端 escape sequence，允许在 SSH 远程会话中自动将 Vim/Tmux 的复制内容同步到本地剪贴板。

### 原理说明

```
Vim/Tmux 复制  -->  OSC 52 escape sequence  -->  终端  -->  本地剪贴板
```

### 各终端支持情况与配置

#### ✅ iTerm2 (macOS)

默认已启用 OSC 52 支持。

**检查/配置**:
```
iTerm2 → Preferences → General → Selection → Applications in terminal may access clipboard
```

---

#### ✅ Windows Terminal

默认已启用 OSC 52 支持。

**配置** (settings.json):
```json
{
    "profiles": {
        "defaults": {
            "experimentalPixelShaderEnabled": true,
            "enableBuiltinGlyphs": true
        }
    }
}
```

> 注意：需要 Windows Terminal 1.0+ 和 PowerShell/WLS 配置剪贴板复制。

---

#### ✅ Alacritty (跨平台)

需要 0.13.0+ 版本。

**配置** (`~/.config/alacritty/alacritty.yml`):
```yaml
window:
  options:
    class: { instance: Alacritty, general: Alacritty }
  dynamic_title: true

# Alacritty 0.13.0+ 默认支持 OSC 52
```

**旧版本** (0.12.0 及以下):
```bash
# 需要打补丁或使用 nightly 版本
cargo install alacritty --git https://github.com/alacritty/alacritty
```

---

#### ⚠️ macOS Terminal.app

**默认不支持** OSC 52。

**解决方案**:
1. 使用 **iTerm2** 替代（推荐）
2. 或安装 **iTerm2 shell integration**：
   ```bash
   curl -L https://iterm2.com/shell_integration/install_shell_integration.bash | bash
   ```

---

#### ⚠️ GNOME Terminal

**默认不支持** OSC 52。

**解决方案**:
```bash
# 安装支持 OSC 52 的替代终端
sudo apt install gnome-terminal  # 确保是 3.40+

# 或使用其他替代终端
sudo apt install terminology    # EFL 终端
sudo apt install kitty          # GPU 加速终端
```

---

#### ✅ Kitty (跨平台)

默认已启用 OSC 52 支持。

**配置** (`~/.config/kitty/kitty.conf`):
```conf
# OSC 52 剪贴板支持（默认开启）
clipboard_control write-primary write-clipboard no-append
```

---

#### ✅ foot (Wayland)

默认已启用 OSC 52 支持。

**配置** (`~/.config/foot/foot.ini`):
```ini
[term]
search-case-sensitive=no

[clipboard]
max-size=1048576  # 1MB 限制
```

---

#### ✅ WSL (Windows Subsystem for Linux)

**组合方案**：

1. **Windows Terminal + WSL** (推荐):
   ```
   Windows Terminal → Settings → Profiles → WSL → Copy on select ✓
   ```

2. **VcXsrv / WSLg**:
   ```bash
   # 安装 wslu
   sudo apt install wslu

   # 配置 wsl-copy
   echo "export DISPLAY=:0" >> ~/.bashrc
   ```

---

#### ✅ SSH 配置

**客户端配置** (`~/.ssh/config`):
```
Host *
    SetEnv TERM=xterm-256color
    ForwardX11Trusted yes
    # 保持连接防止超时
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**服务器端要求**:
```bash
# 确保服务器终端支持 OSC 52
# 大多数现代 Linux 终端都支持
```

### 故障排查

#### 1. 检查终端是否支持 OSC 52

```bash
# 测试命令（应该在本地剪贴板看到 "test"）
printf "\033]52;c;dGVzdA==\a"

# base64 解码 "dGVzdA==" = "test"
echo "dGVzdA==" | base64 -d
```

#### 2. 检查 Vim OSC 52 函数

在 Vim 中：
```vim
" 测试 OSC 52 是否工作
:echo system('echo -n test | base64')

" 查看调试信息
:verbose function OscYank
```

#### 3. Tmux 剪贴板模式

```bash
# 检查 tmux 剪贴板设置
tmux show-options -s set-clipboard

# 手动设置
tmux set -s set-clipboard on
```

#### 4. 常见错误

| 症状 | 可能原因 | 解决方案 |
|------|----------|----------|
| 复制无反应 | 终端不支持 OSC 52 | 更换终端（iTerm2/Windows Terminal/Alacritty） |
| 远程复制失败 | SSH 配置问题 | 检查 SSH config 中的 TERM 设置 |
| 大文本无法复制 | 剪贴板大小限制 | 调整终端/服务器配置（通常 64KB 限制） |
| tmux 复制失效 | passthrough 未开 | 确认 `set -g allow-passthrough on` |

### 工作流示例

```bash
# 本地 iTerm2 → SSH 远程 → Vim 复制 → 自动同步到本地剪贴板
# 1. 本地终端运行
ssh user@remote

# 2. 远程 tmux/vim 中 y 复制

# 3. 直接在本地粘贴
Cmd+v
```

---

## 故障排除

### 1. 插件安装失败

```bash
# 检查 vim 是否支持 python/python3
vim --version | grep python

# 手动安装插件
vim
:PlugInstall
```

### 2. fzf 不工作

```bash
# 手动安装 fzf
git clone https://github.com/junegunn/fzf ~/.fzf
~/.fzf/install
```

### 4. 配色方案不生效（无颜色）

**症状**: 所有文件显示黑白色，配色方案（如 gruvbox）不生效。

**诊断**:
```bash
# 检查终端类型
echo $TERM

# 如果显示 dumb，说明终端不支持颜色
# 正常应该显示: xterm-256color, tmux-256color, screen-256color 等
```

**原因**: TERM 环境变量被设为 `dumb`，vim 认为终端不支持颜色。

**解决方案**:

1. **SSH 连接时设置正确的 TERM**:
   ```bash
   # 在远程服务器上
   export TERM=xterm-256color
   ```

2. **SSH 配置文件** (`~/.ssh/config`):
   ```
   Host *
       SetEnv TERM=xterm-256color
   ```

3. **Tmux 内设置**:
   ```bash
   # 在 tmux 中
   tmux set -g default-terminal "tmux-256color"
   ```

4. **永久设置** (添加到 `~/.bashrc`):
   ```bash
   export TERM=xterm-256color
   ```

**自动降级**: 配置已添加自动检测，当 TERM=dumb 时会自动降级到 256 色 desert 配色。

---

### 5. tmux 内 TERM 设置导致问题

**症状**: 进入 tmux 后 vim 配色丢失，TERM 变为 `dumb`。

**原因**: tmux 配置中设置了 `set -g default-terminal "tmux-256color"`，但某些终端或 SSH 环境不识别这个值。

**解决方案**:

1. **检查新设备的 SSH 配置** (`~/.ssh/config`):
   ```
   Host *
       SetEnv TERM=xterm-256color
   ```

2. **如果 tmux 仍不工作，降级 TERM 值** (在 `~/.tmux.conf.local`):
   ```bash
   # 改为更通用的值
   set -g default-terminal "screen-256color"
   # 或
   set -g default-terminal "xterm-256color"
   ```

3. **临时修复**:
   ```bash
   # 进入 tmux 后手动设置
   export TERM=xterm-256color
   ```

**说明**: `tmux-256color` 是推荐值，但如果新设备环境特殊，可降级使用。

---

### 6. tmux 插件不工作

```bash
# 确保 tpm 安装
ls ~/.tmux/plugins/tpm

# 检查 tmux.conf 语法
tmux source-file ~/.tmux.conf

# 手动安装插件
~/.tmux/plugins/tpm/bin/install_plugins
```

## 自定义配置

在 `~/.vimrc.local` 或 `~/.tmux.conf.local` 中添加自定义配置（不会被 dotfiles 覆盖）：

```vim
" ~/.vimrc.local
let g:ale_enabled = 0  " 禁用 ALE
```

```bash
# ~/.tmux.conf.local
set -g mouse off  " 禁用鼠标
```

---

## 配置版本

- Vim: 基于 vim-plug
- Tmux: 基于 tpm
- 生成日期: $(date +%Y-%m-%d)
