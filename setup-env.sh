#!/usr/bin/env bash
#=====================================================================
# 一键自动化 Vim + Tmux 环境配置工具
# 用法: ./setup-env.sh [--vim-only] [--tmux-only] [--backup] [--restore]
#=====================================================================

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置路径
DOTFILES_DIR="$HOME/dotfiles"
VIMRC_SOURCE="$DOTFILES_DIR/vim/.vimrc"
TMUX_SOURCE="$DOTFILES_DIR/tmux/.tmux.conf"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
        mkdir -p "$BACKUP_DIR"
        log_info "备份目录: $BACKUP_DIR"
    fi

    # 备份 Vim 配置
    if [ -f "$HOME/.vimrc" ]; then
        cp "$HOME/.vimrc" "$BACKUP_DIR/.vimrc.bak"
        log_info "已备份 .vimrc"
    fi

    if [ -d "$HOME/.vim" ]; then
        cp -r "$HOME/.vim" "$BACKUP_DIR/.vim.bak" 2>/dev/null || true
        log_info "已备份 .vim 目录"
    fi

    # 备份 Tmux 配置
    if [ -f "$HOME/.tmux.conf" ]; then
        cp "$HOME/.tmux.conf" "$BACKUP_DIR/.tmux.conf.bak"
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
    mkdir -p "$autoload_dir"

    curl -fLo "$autoload_dir/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    log_success "vim-plug 安装完成"
}

#=====================================================================
# 创建 Vim 必要目录
#=====================================================================
setup_vim_dirs() {
    log_info "创建 Vim 目录结构..."

    mkdir -p ~/.vim/{swap,undo,backup,plugged,autoload}

    log_success "Vim 目录创建完成"
}

#=====================================================================
# 安装 Vim 插件
#=====================================================================
install_vim_plugins() {
    log_info "安装 Vim 插件..."

    if command -v vim &> /dev/null; then
        vim +PlugInstall +qall 2>/dev/null || true
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
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y fzf
        elif command -v brew &> /dev/null; then
            brew install fzf
        elif command -v git &> /dev/null; then
            # 源码安装
            git clone --depth 1 https://github.com/junegunn/fzf ~/.fzf
            ~/.fzf/install --all --no-bash --no-zsh
        fi
    fi

    if command -v fzf &> /dev/null; then
        log_success "fzf 已就绪 ($(fzf --version))"
    else
        log_warn "fzf 安装失败，但插件仍可工作"
    fi
}

#=====================================================================
# 安装 Tmux 插件管理器 (tpm)
#=====================================================================
install_tpm() {
    log_info "安装 tmux-plugin-manager..."

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        log_success "tpm 安装完成"
    else
        log_info "tpm 已存在"
    fi
}

#=====================================================================
# 部署配置
#=====================================================================
deploy_config() {
    log_info "部署配置文件..."

    # Vim
    if [ -f "$VIMRC_SOURCE" ]; then
        cp "$VIMRC_SOURCE" "$HOME/.vimrc"
        log_info "已部署 .vimrc"
    fi

    # Tmux
    if [ -f "$TMUX_SOURCE" ]; then
        cp "$TMUX_SOURCE" "$HOME/.tmux.conf"
        log_info "已部署 .tmux.conf"
    fi

    log_success "配置部署完成"
}

#=====================================================================
# 安装 Tmux 插件
#=====================================================================
install_tmux_plugins() {
    log_info "安装 Tmux 插件..."

    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        # 设置 tpm 环境变量并安装插件
        if command -v tmux &> /dev/null; then
            tmux new-session -d -s tmp-install 2>/dev/null || true
            tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins" 2>/dev/null || true

            # 提示用户手动安装插件
            echo ""
            log_info "请在 tmux 中运行以下命令安装插件:"
            echo -e "${GREEN}  prefix + I${NC}   (大写 I)"
            echo ""

            # 清理临时 session
            tmux kill-session -t tmp-install 2>/dev/null || true
        fi
    else
        log_warn "tpm 未安装，跳过 Tmux 插件"
    fi
}

#=====================================================================
# 主函数
#=====================================================================
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║       Vim + Tmux 一键自动化配置工具 v1.0              ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    # 解析参数
    VIM_ONLY=false
    TMUX_ONLY=false
    BACKUP=false
    RESTORE=false

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
            *)
                log_error "未知参数: $1"
                echo "用法: $0 [--vim-only] [--tmux-only] [--backup] [--restore]"
                exit 1
                ;;
        esac
    done

    # 如果需要备份，先执行备份
    if [ "$BACKUP" = true ]; then
        backup_existing
    fi

    # 恢复模式
    if [ "$RESTORE" = true ]; then
        log_info "恢复模式: 请指定备份目录路径"
        read -p "备份目录路径: " backup_dir
        if [ -d "$backup_dir" ]; then
            cp -r "$backup_dir/." "$HOME/"
            log_success "配置已恢复"
        else
            log_error "备份目录不存在"
        fi
        exit 0
    fi

    # 依赖检查
    check_dependencies

    # 版本检查
    check_versions

    echo ""
    echo "请选择操作:"
    echo "  1) 完整安装 (Vim + Tmux)"
    echo "  2) 仅安装 Vim"
    echo "  3) 仅安装 Tmux"
    echo "  4) 仅备份当前配置"
    echo "  5) 退出"
    echo ""
    read -p "请输入选项 [1-5]: " choice

    case $choice in
        1)
            # 完整安装
            backup_existing
            setup_vim_dirs
            install_vim_plug
            install_fzf
            install_tpm
            deploy_config
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
            ;;
        2)
            # 仅 Vim
            backup_existing
            setup_vim_dirs
            install_vim_plug
            install_fzf
            deploy_config
            install_vim_plugins

            echo ""
            log_success "Vim 配置完成! 在 vim 中运行 :PlugInstall"
            ;;
        3)
            # 仅 Tmux
            backup_existing
            install_tpm
            deploy_config
            install_tmux_plugins

            echo ""
            log_success "Tmux 配置完成! 在 tmux 中按 prefix + I"
            ;;
        4)
            backup_existing
            log_success "备份完成: $BACKUP_DIR"
            ;;
        5)
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