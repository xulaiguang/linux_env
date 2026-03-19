#!/usr/bin/env bash
#=====================================================================
# 一键自动化 Vim + Tmux 环境配置工具
# 用法: ./setup-env.sh [--vim-only] [--tmux-only] [--backup] [--restore]
#                      [--uninstall] [--dry-run]
#=====================================================================

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置路径
DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)
VIMRC_SOURCE="$DOTFILES_DIR/vim/.vimrc"
TMUX_SOURCE="$DOTFILES_DIR/tmux/.tmux.conf"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# 全局标志
DRY_RUN=false

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# dry-run 包装器：如果 --dry-run 模式则只打印不执行
run() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} $*"
    else
        "$@"
    fi
}

#=====================================================================
# 依赖检查
#=====================================================================
check_dependencies() {
    log_info "检查依赖..."

    local missing=()

    # 检查必需命令
    for cmd in curl git; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "缺少必要依赖: ${missing[*]}"
        echo "请安装: apt install ${missing[*]}"
        exit 1
    fi

    log_success "依赖检查完成"
}

#=====================================================================
# 版本检查
#=====================================================================
check_versions() {
    log_info "检查 Vim/Tmux 版本..."

    # Vim 版本检查
    if command -v vim &> /dev/null; then
        local vim_version=$(vim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+')
        local vim_major=$(echo $vim_version | cut -d. -f1)
        local vim_minor=$(echo $vim_version | cut -d. -f2)

        if [ "$vim_major" -lt 8 ]; then
            log_warn "Vim 版本 ($vim_version) 较旧，建议升级到 8.0+"
            log_warn "termguicolors、ALE、fzf.vim 等功能需要 Vim 8.0+"
        else
            log_success "Vim 版本: $vim_version ✓"
        fi

        # 剪贴板支持检查
        local vim_features=$(vim --version 2>/dev/null)
        if echo "$vim_features" | grep -q "+clipboard"; then
            log_success "Vim 剪贴板支持: ✓"
        else
            log_error "Vim 缺少剪贴板支持 (+clipboard)"
            log_warn "vim 配置中的剪贴板功能将无法工作"
            log_warn "解决方案: 安装 vim-gtk3 或编译时启用 clipboard"
        fi

        # xterm_clipboard 支持（远程 SSH 复制需要）
        if echo "$vim_features" | grep -q "+xterm_clipboard"; then
            log_success "xterm_clipboard 支持: ✓ (SSH 远程剪贴板可用)"
        else
            log_warn "xterm_clipboard 未启用（SSH 远程复制可能受限）"
        fi
    else
        log_warn "Vim 未安装，插件安装步骤将跳过"
    fi

    # Tmux 版本检查
    if command -v tmux &> /dev/null; then
        local tmux_version=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+')
        local tmux_major=$(echo $tmux_version | cut -d. -f1)
        local tmux_minor=$(echo $tmux_version | cut -d. -f2)

        # 2.1: mouse mode 语法变化; 3.2+: popup, passthrough, set-clipboard
        if [ "$tmux_major" -lt 3 ] || ([ "$tmux_major" -eq 3 ] && [ "$tmux_minor" -lt 2 ]); then
            log_warn "Tmux 版本 ($tmux_version) 较旧，建议升级到 3.2+"
            log_warn "popup 窗口、OSC52 剪贴板同步等功能需要 Tmux 3.2+"
        else
            log_success "Tmux 版本: $tmux_version ✓"
        fi
    else
        log_warn "Tmux 未安装"
    fi
}

#=====================================================================
# 备份现有配置
#=====================================================================
backup_existing() {
    if [ ! -d "$BACKUP_DIR" ]; then
        run mkdir -p "$BACKUP_DIR"
        log_info "备份目录: $BACKUP_DIR"
    fi

    # 备份 Vim 配置
    if [ -f "$HOME/.vimrc" ]; then
        run cp "$HOME/.vimrc" "$BACKUP_DIR/.vimrc.bak"
        log_info "已备份 .vimrc"
    fi

    if [ -d "$HOME/.vim" ]; then
        run cp -r "$HOME/.vim" "$BACKUP_DIR/.vim.bak" 2>/dev/null || true
        log_info "已备份 .vim 目录"
    fi

    # 备份 Tmux 配置
    if [ -f "$HOME/.tmux.conf" ]; then
        run cp "$HOME/.tmux.conf" "$BACKUP_DIR/.tmux.conf.bak"
        log_info "已备份 .tmux.conf"
    fi

    log_success "备份完成"
}

#=====================================================================
# 安装 Vim 插件管理器 (vim-plug)
#=====================================================================
install_vim_plug() {
    log_info "安装 vim-plug..."

    local autoload_dir="$HOME/.vim/autoload"
    run mkdir -p "$autoload_dir"

    run curl -fLo "$autoload_dir/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    log_success "vim-plug 安装完成"
}

#=====================================================================
# 创建 Vim 必要目录
#=====================================================================
setup_vim_dirs() {
    log_info "创建 Vim 目录结构..."

    run mkdir -p ~/.vim/{swap,undo,backup,plugged,autoload}

    log_success "Vim 目录创建完成"
}

#=====================================================================
# 安装 Vim 插件
#=====================================================================
install_vim_plugins() {
    log_info "安装 Vim 插件..."

    if command -v vim &> /dev/null; then
        run vim +PlugInstall +qall 2>/dev/null || true
        log_success "Vim 插件安装完成"
    else
        log_warn "Vim 未安装，跳过插件安装"
    fi
}

#=====================================================================
# 安装 fzf (fzf.vim 依赖)
#=====================================================================
install_fzf() {
    log_info "检查/安装 fzf..."

    if ! command -v fzf &> /dev/null; then
        # 尝试通过包管理器安装
        if command -v apt-get &> /dev/null && sudo -n true 2>/dev/null; then
            run sudo apt-get update && run sudo apt-get install -y fzf
        elif command -v brew &> /dev/null; then
            run brew install fzf
        elif command -v git &> /dev/null; then
            # 源码安装（无需 sudo）
            run git clone --depth 1 https://github.com/junegunn/fzf ~/.fzf
            run ~/.fzf/install --all --no-bash --no-zsh
        else
            log_warn "无法安装 fzf: 没有可用的包管理器或 sudo 权限"
            log_warn "请手动安装: https://github.com/junegunn/fzf#installation"
            return
        fi
    fi

    if command -v fzf &> /dev/null; then
        log_success "fzf 已就绪 ($(fzf --version))"
    else
        log_warn "fzf 安装失败，Ctrl+p 文件搜索将不可用"
    fi
}

#=====================================================================
# 安装 ripgrep (fzf :Rg 命令依赖)
#=====================================================================
install_ripgrep() {
    log_info "检查/安装 ripgrep..."

    if ! command -v rg &> /dev/null; then
        # 尝试通过包管理器安装
        if command -v apt-get &> /dev/null && sudo -n true 2>/dev/null; then
            run sudo apt-get update && run sudo apt-get install -y ripgrep
        elif command -v brew &> /dev/null; then
            run brew install ripgrep
        else
            log_warn "无法安装 ripgrep: 没有可用的包管理器或 sudo 权限"
            log_warn "请手动安装: https://github.com/BurntSushi/ripgrep#installation"
            return
        fi
    fi

    if command -v rg &> /dev/null; then
        log_success "ripgrep 已就绪 ($(rg --version | head -1))"
    else
        log_warn "ripgrep 安装失败，:Rg 全局搜索将不可用"
    fi
}

#=====================================================================
# 安装 Tmux 插件管理器 (tpm)
#=====================================================================
install_tpm() {
    log_info "安装 tmux-plugin-manager..."

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        run git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        log_success "tpm 安装完成"
    else
        log_info "tpm 已存在"
    fi
}

#=====================================================================
# 部署配置（使用符号链接）
#=====================================================================
deploy_vim_config() {
    log_info "部署 Vim 配置文件..."

    if [ -f "$VIMRC_SOURCE" ]; then
        # 如果已有非符号链接的 .vimrc，备份已在之前完成
        run ln -sf "$VIMRC_SOURCE" "$HOME/.vimrc"
        log_info "已链接 .vimrc -> $VIMRC_SOURCE"
    else
        log_warn "源文件不存在: $VIMRC_SOURCE"
    fi

    log_success "Vim 配置部署完成"
}

deploy_tmux_config() {
    log_info "部署 Tmux 配置文件..."

    if [ -f "$TMUX_SOURCE" ]; then
        run ln -sf "$TMUX_SOURCE" "$HOME/.tmux.conf"
        log_info "已链接 .tmux.conf -> $TMUX_SOURCE"
    else
        log_warn "源文件不存在: $TMUX_SOURCE"
    fi

    log_success "Tmux 配置部署完成"
}

#=====================================================================
# 安装 Tmux 插件
#=====================================================================
install_tmux_plugins() {
    log_info "安装 Tmux 插件..."

    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        # TPM 需要 tmux 服务器先加载配置才能获取 TMUX_PLUGIN_MANAGER_PATH，
        # 因此无法在脚本中直接调用 install_plugins。
        # 正确做法：提示用户在 tmux 中手动安装。
        echo ""
        log_info "请启动 tmux 后按以下快捷键安装插件:"
        echo -e "  ${GREEN}prefix + I${NC}   (Ctrl+a, 然后大写 I)"
        echo ""
        log_info "或者启动 tmux 后在 shell 中运行:"
        echo -e "  ${GREEN}~/.tmux/plugins/tpm/bin/install_plugins${NC}"
        echo ""
    else
        log_warn "tpm 未安装，跳过 Tmux 插件"
    fi
}

#=====================================================================
# 恢复配置（安全模式：只恢复特定文件）
#=====================================================================
restore_config() {
    log_info "恢复模式"
    echo ""

    # 列出可用备份目录
    local backups=()
    while IFS= read -r dir; do
        backups+=("$dir")
    done < <(find "$HOME" -maxdepth 1 -name '.config-backup-*' -type d 2>/dev/null | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        log_error "未找到任何备份目录 (~/.config-backup-*)"
        exit 1
    fi

    echo "可用备份:"
    for i in "${!backups[@]}"; do
        echo "  $((i+1))) ${backups[$i]}"
    done
    echo ""
    read -p "请选择备份 [1-${#backups[@]}]: " backup_idx

    # 验证输入
    if ! [[ "$backup_idx" =~ ^[0-9]+$ ]] || [ "$backup_idx" -lt 1 ] || [ "$backup_idx" -gt "${#backups[@]}" ]; then
        log_error "无效选择"
        exit 1
    fi

    local backup_dir="${backups[$((backup_idx-1))]}"
    log_info "从 $backup_dir 恢复..."

    # 安全恢复：只恢复特定的配置文件
    local restored=0

    if [ -f "$backup_dir/.vimrc.bak" ]; then
        run cp "$backup_dir/.vimrc.bak" "$HOME/.vimrc"
        log_info "已恢复 .vimrc"
        restored=$((restored + 1))
    fi

    if [ -d "$backup_dir/.vim.bak" ]; then
        run cp -r "$backup_dir/.vim.bak" "$HOME/.vim"
        log_info "已恢复 .vim 目录"
        restored=$((restored + 1))
    fi

    if [ -f "$backup_dir/.tmux.conf.bak" ]; then
        run cp "$backup_dir/.tmux.conf.bak" "$HOME/.tmux.conf"
        log_info "已恢复 .tmux.conf"
        restored=$((restored + 1))
    fi

    if [ "$restored" -eq 0 ]; then
        log_warn "备份目录中未找到可恢复的配置文件"
    else
        log_success "已恢复 $restored 个配置"
    fi
}

#=====================================================================
# 卸载
#=====================================================================
uninstall() {
    log_warn "即将卸载所有已安装的配置和插件"
    echo ""
    echo "将要删除:"
    echo "  - ~/.vimrc (符号链接)"
    echo "  - ~/.tmux.conf (符号链接)"
    echo "  - ~/.vim/plugged/ (Vim 插件)"
    echo "  - ~/.vim/autoload/plug.vim (vim-plug)"
    echo "  - ~/.tmux/plugins/ (Tmux 插件 + tpm)"
    echo ""
    read -p "确认卸载? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "已取消"
        exit 0
    fi

    # 先备份
    log_info "卸载前自动备份..."
    backup_existing

    # 删除符号链接（只删除链接到本项目的情况）
    if [ -L "$HOME/.vimrc" ]; then
        local target=$(readlink -f "$HOME/.vimrc" 2>/dev/null || true)
        if [[ "$target" == "$DOTFILES_DIR"* ]]; then
            run rm "$HOME/.vimrc"
            log_info "已删除 ~/.vimrc 符号链接"
        else
            log_warn "~/.vimrc 不是指向本项目的链接，跳过"
        fi
    elif [ -f "$HOME/.vimrc" ]; then
        run rm "$HOME/.vimrc"
        log_info "已删除 ~/.vimrc"
    fi

    if [ -L "$HOME/.tmux.conf" ]; then
        local target=$(readlink -f "$HOME/.tmux.conf" 2>/dev/null || true)
        if [[ "$target" == "$DOTFILES_DIR"* ]]; then
            run rm "$HOME/.tmux.conf"
            log_info "已删除 ~/.tmux.conf 符号链接"
        else
            log_warn "~/.tmux.conf 不是指向本项目的链接，跳过"
        fi
    elif [ -f "$HOME/.tmux.conf" ]; then
        run rm "$HOME/.tmux.conf"
        log_info "已删除 ~/.tmux.conf"
    fi

    # 删除插件
    if [ -d "$HOME/.vim/plugged" ]; then
        run rm -rf "$HOME/.vim/plugged"
        log_info "已删除 Vim 插件目录"
    fi

    if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
        run rm "$HOME/.vim/autoload/plug.vim"
        log_info "已删除 vim-plug"
    fi

    if [ -d "$HOME/.tmux/plugins" ]; then
        run rm -rf "$HOME/.tmux/plugins"
        log_info "已删除 Tmux 插件目录"
    fi

    echo ""
    log_success "卸载完成! 备份已保存在: $BACKUP_DIR"
}

#=====================================================================
# Vim 安装流程
#=====================================================================
install_vim() {
    backup_existing
    setup_vim_dirs
    install_vim_plug
    install_fzf
    install_ripgrep
    deploy_vim_config
    install_vim_plugins

    echo ""
    log_success "Vim 配置完成! 在 vim 中运行 :PlugInstall"
}

#=====================================================================
# Tmux 安装流程
#=====================================================================
install_tmux() {
    backup_existing
    install_tpm
    deploy_tmux_config
    install_tmux_plugins

    echo ""
    log_success "Tmux 配置完成! 在 tmux 中按 prefix + I"
}

#=====================================================================
# 完整安装流程
#=====================================================================
install_all() {
    backup_existing
    setup_vim_dirs
    install_vim_plug
    install_fzf
    install_ripgrep
    install_tpm
    deploy_vim_config
    deploy_tmux_config
    install_vim_plugins
    install_tmux_plugins

    echo ""
    log_success "========================================"
    log_success "  安装完成!"
    log_success "========================================"
    echo ""
    echo "后续步骤:"
    echo "  1. 启动 vim, 运行 :PlugInstall 安装插件"
    echo "  2. 启动 tmux, 按 prefix + I 安装插件"
    echo ""
}

#=====================================================================
# 显示帮助
#=====================================================================
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --vim-only      仅安装 Vim 配置"
    echo "  --tmux-only     仅安装 Tmux 配置"
    echo "  --backup        仅备份当前配置"
    echo "  --restore       从备份恢复配置"
    echo "  --uninstall     卸载所有已安装的配置和插件"
    echo "  --dry-run       预览模式，只显示将要执行的操作"
    echo "  --help          显示此帮助信息"
    echo ""
    echo "不带参数运行将显示交互式菜单。"
}

#=====================================================================
# 主函数
#=====================================================================
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║       Vim + Tmux 一键自动化配置工具 v2.0              ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    # 解析参数
    local VIM_ONLY=false
    local TMUX_ONLY=false
    local BACKUP=false
    local RESTORE=false
    local UNINSTALL=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --vim-only)
                VIM_ONLY=true
                shift
                ;;
            --tmux-only)
                TMUX_ONLY=true
                shift
                ;;
            --backup)
                BACKUP=true
                shift
                ;;
            --restore)
                RESTORE=true
                shift
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                log_warn "预览模式: 不会执行任何实际操作"
                echo ""
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 命令行参数直接执行模式（不进入交互菜单）
    if [ "$BACKUP" = true ]; then
        backup_existing
        log_success "备份完成: $BACKUP_DIR"
        exit 0
    fi

    if [ "$RESTORE" = true ]; then
        restore_config
        exit 0
    fi

    if [ "$UNINSTALL" = true ]; then
        uninstall
        exit 0
    fi

    # 依赖检查
    check_dependencies

    # 版本检查
    check_versions

    if [ "$VIM_ONLY" = true ]; then
        install_vim
        exit 0
    fi

    if [ "$TMUX_ONLY" = true ]; then
        install_tmux
        exit 0
    fi

    # 无参数：显示交互式菜单
    echo ""
    echo "请选择操作:"
    echo "  1) 完整安装 (Vim + Tmux)"
    echo "  2) 仅安装 Vim"
    echo "  3) 仅安装 Tmux"
    echo "  4) 仅备份当前配置"
    echo "  5) 卸载已安装的配置"
    echo "  6) 退出"
    echo ""
    read -p "请输入选项 [1-6]: " choice

    case $choice in
        1)
            install_all
            ;;
        2)
            install_vim
            ;;
        3)
            install_tmux
            ;;
        4)
            backup_existing
            log_success "备份完成: $BACKUP_DIR"
            ;;
        5)
            uninstall
            ;;
        6)
            echo "退出"
            exit 0
            ;;
        *)
            log_error "无效选项"
            exit 1
            ;;
    esac
}

main "$@"
