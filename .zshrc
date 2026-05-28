# ============================================================================
# 模块一：终端颜色定义
# 功能：预定义终端颜色变量，供提示符、补全菜单、命令高亮等模块使用
#   autoload colors / colors —— 加载 zsh 内置颜色支持
#   for 循环遍历 7 种颜色，为每种生成两个变量：
#     大写如 RED —— 普通前景色   %{$fg[red]%}
#     下划线如 _RED —— 加粗前景色  %{$terminfo[bold]$fg[red]%}
#   FINISH —— 颜色重置序列 %{$terminfo[sgr0]%}，取消所有颜色/样式
#   用法示例：echo "$RED 这是红色文字 $FINISH 恢复正常"
# ============================================================================
autoload colors
colors

for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
eval _$color='%{$terminfo[bold]$fg[${(L)color}]%}'
eval $color='%{$fg[${(L)color}]%}'
(( count = $count + 1 ))
done
FINISH="%{$terminfo[sgr0]%}"

# ============================================================================
# 模块二：命令提示符
# 功能：设置终端的命令行提示符样式（agnoster 风格，无需 Nerd Font）
#   PROMPT —— 双行提示符：
#     第一行：[绿色背景 用户@主机] ▸ [蓝色背景 路径] ▸ [深灰背景 Git 信息]
#     第二行：提示符（成功绿色/失败红色）
#   分段设计（agnoster 风格）：
#     %K{green} = 绿色背景（用户@主机），%K{blue} = 蓝色背景（路径）
#     %K{236} = 深灰色背景（Git 信息），▸ = 分段箭头
#   Git 信息格式：
#     git:(分支名) ✔ —— 无修改时显示绿色 ✔
#     git:(分支名) ✚ —— 有修改时显示红色 ✚
#     分支名始终为浅蓝色
#   虚拟环境显示：
#     ${VENV} —— 仅在激活虚拟环境时显示（如 Python venv）
#   gentoo_precmd —— 每次命令执行前更新 git_seg 和 VENV 变量
# ============================================================================
setopt PROMPT_SUBST
PROMPT='%F{cyan}%D{%H:%M}%f %K{green}%F{15} %n@%m %f%k%K{236}%F{15} %~ %f%k${git_seg:+ $git_seg}
${VENV}%(?.%F{green}.%F{red})%(!.#.$)%f '

gentoo_precmd() {
  VENV=""
  if [[ -n "$VIRTUAL_ENV" ]]; then
    VENV="%F{242}(%F{cyan}${VIRTUAL_ENV:t}%f) "
  fi
  git_seg=""
  if git rev-parse --git-dir &>/dev/null; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
      if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        git_seg="%F{blue}git:(%F{15}${branch}%F{red} ✚%F{blue})%f"
      else
        git_seg="%F{blue}git:(%F{15}${branch}%F{green} ✔%F{blue})%f"
      fi
    fi
  fi
}

autoload -U add-zsh-hook
add-zsh-hook precmd gentoo_precmd

# ============================================================================
# 模块三：终端标题栏自动更新
# 功能：在图形终端的标题栏实时显示当前路径和正在执行的命令
#   仅在 xterm/rxvt/kterm/Eterm 等图形终端下生效
#   precmd() —— 每次命令执行前调用，将标题设为 "用户名@主机名//路径"
#   preexec() —— 每次命令执行时调用，将标题追加正在运行的命令名称
# ============================================================================
#标题栏、任务栏样式{{{
case $TERM in (*xterm*|*rxvt*|(dt|k|E)term)
precmd () { print -Pn "\e]0;%n@%M//%/\a" }
preexec () { print -Pn "\e]0;%n@%M//%/\ $1\a" }
;;
esac

# ============================================================================
# 模块四：历史记录配置
# 功能：控制命令历史的存储方式和行为
#   HISTSIZE=10000 —— 内存中保留最近 10000 条命令历史
#   SAVEHIST=10000 —— 注销后写入文件的历史条数上限
#   HISTFILE=~/.zhistory —— 历史记录持久化文件路径
#   INC_APPEND_HISTORY —— 命令执行后立即追加到历史文件（不等 shell 退出）
#   HIST_IGNORE_DUPS —— 连续输入相同命令时，历史中只保留一条（去重）
#   EXTENDED_HISTORY —— 为每条历史记录附加执行时间戳（Unix 时间戳格式）
#   AUTO_PUSHD —— cd 命令自动维护目录栈，支持 cd -[TAB] 浏览历史路径
#   PUSHD_IGNORE_DUPS —— 目录栈中相同路径只保留一个
#   HIST_IGNORE_SPACE（已注释）—— 以空格开头的命令不记入历史（可用于执行敏感命令）
# ============================================================================
#关于历史纪录的配置 {{{
#历史纪录条目数量
export HISTSIZE=10000
#注销后保存的历史纪录条目数量
export SAVEHIST=10000
#历史纪录文件
export HISTFILE=~/.zhistory
#以附加的方式写入历史纪录
setopt INC_APPEND_HISTORY
#如果连续输入的命令相同，历史纪录中只保留一个
setopt HIST_IGNORE_DUPS
#为历史纪录中的命令添加时间戳
setopt EXTENDED_HISTORY

#启用 cd 命令的历史纪录，cd -[TAB]进入历史路径
setopt AUTO_PUSHD
#相同的历史路径只保留一个
setopt PUSHD_IGNORE_DUPS


# ============================================================================
# 模块五：目录独立历史记录
# 功能：为每个目录维护独立的命令历史文件，实现"目录级"历史隔离
#   cd() 函数 —— 重写 cd 命令，每次切换目录时：
#     1. 保存当前目录的历史到文件
#     2. 创建/加载目标目录的独立历史文件
#     历史文件存储在 ~/.zsh_dir_history<路径>/zhistory
#   自动迁移 —— 检测旧版 ~/.zsh_history 目录：
#     仅有旧目录 → 重命名为新路径
#     新旧共存   → 合并旧目录到新目录，删除旧目录
#   辅助函数：
#     allhistory —— 聚合查看所有目录的历史记录
#     convhistory —— 将原始历史转换为 "日期时间 | 命令" 可读格式
#     histall —— 查看全部历史（带时间戳，过滤掉 cd 命令）
#     hist —— 查看当前目录的历史记录
#     top50 —— 统计所有历史中使用频率最高的 50 条命令
# ============================================================================
#每个目录使用独立的历史纪录{{{

#自动迁移旧版历史目录（~/.zsh_history → ~/.zsh_dir_history）
if [ -d "$HOME/.zsh_history" ] && [ ! -d "$HOME/.zsh_dir_history" ]; then
    echo "[zsh] 正在迁移旧版历史目录 ~/.zsh_history → ~/.zsh_dir_history ..."
    mv "$HOME/.zsh_history" "$HOME/.zsh_dir_history"
    echo "[zsh] 迁移完成"
elif [ -d "$HOME/.zsh_history" ] && [ -d "$HOME/.zsh_dir_history" ]; then
    echo "[zsh] 发现新旧两个历史目录，合并旧目录到新目录..."
    cp -r "$HOME/.zsh_history"/* "$HOME/.zsh_dir_history"/ 2>/dev/null
    rm -rf "$HOME/.zsh_history"
    echo "[zsh] 合并完成，旧目录已删除"
fi

cd() {
builtin cd "$@"                             # do actual cd
fc -W                                       # write current history  file
local HISTDIR="$HOME/.zsh_dir_history$PWD"      # use nested folders for history
if  [ ! -d "$HISTDIR" ] ; then          # create folder if needed
mkdir -p "$HISTDIR"
fi
export HISTFILE="$HISTDIR/zhistory"     # set new history file
touch $HISTFILE
local ohistsize=$HISTSIZE
HISTSIZE=0                              # Discard previous dir's history
HISTSIZE=$ohistsize                     # Prepare for new dir's history
fc -R                                       #read from current histfile
}
mkdir -p $HOME/.zsh_dir_history$PWD
export HISTFILE="$HOME/.zsh_dir_history$PWD/zhistory"

function allhistory { cat $(find $HOME/.zsh_dir_history -name zhistory) }
function convhistory {
sort $1 | uniq |
sed 's/^:\([ 0-9]*\):[0-9]*;\(.*\)/\1::::::\2/' |
awk -F"::::::" '{ $1=strftime("%Y-%m-%d %T",$1) "|"; print }'
}
#使用 histall 命令查看全部历史纪录
function histall { convhistory =(allhistory) |
sed '/^.\{20\} *cd/i\\' }
#使用 hist 查看当前目录历史纪录
function hist { convhistory $HISTFILE }

#全部历史纪录 top50
function top50 { allhistory | awk -F':[ 0-9]*:[0-9]*;' '{ $1="" ; print }' | sed 's/ /\n/g' | sed '/^$/d' | sort | uniq -c | sort -nr | head -n 50 }

#}}}

# ============================================================================
# 模块六：杂项设置
# 功能：各类零散但实用的 shell 行为配置
#   INTERACTIVE_COMMENTS —— 允许在交互模式下使用 # 注释（如 ls -la # 列出文件）
#   AUTO_CD —— 输入目录名直接进入（不需要 cd），如输入 ~/Downloads 自动进入
#   complete_in_word —— 补全时支持路径缩写（如 /v/c/p 补全为 /var/cache/pacman）
#   limit coredumpsize 0 —— 禁用 core dump 生成，节省磁盘空间
#   bindkey -e —— 使用 Emacs 键绑定（Ctrl+A 行首、Ctrl+E 行尾、Ctrl+R 搜索等）
#   WORDCHARS —— 定义哪些字符被视为单词的一部分，影响 Ctrl+W/Alt+D 等操作的删除粒度
# ============================================================================
#杂项 {{{
#允许在交互模式中使用注释  例如：
#cmd #这是注释
setopt INTERACTIVE_COMMENTS

#启用自动 cd，输入目录名回车进入目录
#稍微有点混乱，不如 cd 补全实用
setopt AUTO_CD

#扩展路径
#/v/c/p/p => /var/cache/pacman/pkg
setopt complete_in_word

#禁用 core dumps
limit coredumpsize 0

#Emacs风格 键绑定
bindkey -e

#以下字符视为单词的一部分
WORDCHARS='*?_-[]~=&;!#$%^(){}<>'


# ============================================================================
# 模块七：自动补全系统
# 功能：配置 zsh 强大的 Tab 补全功能
#   基础开关：
#     AUTO_LIST —— 有多个候选时自动列出所有补全选项
#     AUTO_MENU —— 按 Tab 时自动弹出补全菜单（连续 Tab 切换候选）
#     compinit —— 加载 zsh 补全系统核心
#   补全行为：
#     verbose yes —— 补全时显示详细描述信息
#     menu select —— 补全菜单支持方向键上下选择
#     completer —— 补全器优先级链：_complete(正常) → _prefix(前缀) → _correct(纠正) → _match(匹配)
#     expand 'yes' —— 启用路径展开（如 ~/f → ~/foo）
#     squeeze-slashes 'yes' —— 压缩多余的斜杠（如 /usr//bin → /usr/bin）
#   大小写与纠错：
#     matcher-list —— 补全时大小写不敏感（输入 FOO 能匹配 foo）
#   颜色：
#     list-colors —— 补全菜单使用 LS_COLORS 着色（目录蓝色、可执行文件绿色等）
#   kill 补全：
#     compdef —— pkill/killall 借用 kill 的补全逻辑
#     processes —— 进程列表使用 ps -au$USER 格式
#   分组与提示：
#     group-name '' —— 所有补全项默认归为一组
#     descriptions/messages/warnings/corrections —— 各类提示使用不同颜色格式
#     cd ~ 补全顺序 —— 命名目录 → 路径目录 → 用户名 → 展开
# ============================================================================
#自动补全功能 {{{
setopt AUTO_LIST
setopt AUTO_MENU

autoload -U compinit
compinit

#自动补全选项
zstyle ':completion:*' verbose yes
zstyle ':completion:*' menu select
zstyle ':completion:*:*:default' force-list always
zstyle ':completion:*' select-prompt '%SSelect:  lines: %L  matches: %M  [%p]'

zstyle ':completion:*:match:*' original only
zstyle ':completion::prefix-1:*' completer _complete
zstyle ':completion:predict:*' completer _complete
zstyle ':completion:incremental:*' completer _complete _correct
zstyle ':completion:*' completer _complete _prefix _correct _match

#路径补全
zstyle ':completion:*' expand 'yes'
zstyle ':completion:*' squeeze-shlashes 'yes'
zstyle ':completion::complete:*' '\\'

#彩色补全菜单
eval $(dircolors -b)
export ZLSCOLORS="${LS_COLORS}"
zmodload zsh/complist
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

#修正大小写
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
#错误校正
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

#kill 命令补全
compdef pkill=kill
compdef pkill=killall
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:*:*:processes' force-list always
zstyle ':completion:*:processes' command 'ps -au$USER'

#补全类型提示分组
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:descriptions' format $'\e[01;33m -- %d --\e[0m'
zstyle ':completion:*:messages' format $'\e[01;35m -- %d --\e[0m'
zstyle ':completion:*:warnings' format $'\e[01;31m -- No Matches Found --\e[0m'
zstyle ':completion:*:corrections' format $'\e[01;32m -- %d (errors: %e) --\e[0m'

# cd ~ 补全顺序
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'

# ============================================================================
# 模块八：行编辑高亮模式
# 功能：设置 zle（zsh line editor）的视觉高亮样式
#   region:bg=magenta —— 选中区域（Ctrl+@ 标记到光标之间）背景为品红色
#   special:bold —— 特殊字符（如管道符 |、重定向 >）加粗显示
#   isearch:underline —— Ctrl+R 搜索时，匹配的关键字加下划线
# ============================================================================
##行编辑高亮模式 {{{
# Ctrl+@ 设置标记，标记和光标点之间为 region
zle_highlight=(region:bg=magenta #选中区域
special:bold      #特殊字符
isearch:underline) #搜索时使用的关键字

# ============================================================================
# 模块九：智能 Tab 补全逻辑
# 功能：自定义 Tab 键行为，根据当前输入内容做不同处理
#   空行时按 Tab → 自动填入 "cd " 并触发路径补全
#   输入 "cd --" 按 Tab → 替换为 "cd +" 并补全（cd + = 上一个目录）
#   输入 "cd +-" 按 Tab → 替换为 "cd -" 并补全（cd - = 前一个目录）
#   其他情况 → 正常触发补全
# ============================================================================
##空行(光标在行首)补全 "cd " {{{
user-complete(){
case $BUFFER in
"" )                       # 空行填入 "cd "
BUFFER="cd "
zle end-of-line
zle expand-or-complete
;;
"cd --" )                  # "cd --" 替换为 "cd +"
BUFFER="cd +"
zle end-of-line
zle expand-or-complete
;;
"cd +-" )                  # "cd +-" 替换为 "cd -"
BUFFER="cd -"
zle end-of-line
zle expand-or-complete
;;
* )
zle expand-or-complete
;;
esac
}
zle -N user-complete
bindkey "\t" user-complete

# ============================================================================
# 模块十：sudo 快捷键
# 功能：双击 Esc 键在当前命令前插入 sudo
#   sudo-command-line() —— 检查当前命令是否已有 sudo 前缀：
#     若命令行为空 → 取上一条历史命令并在前面加 sudo
#     若命令没有 sudo → 在前面加 sudo
#     最后将光标移动到行末
#   绑定键：双击 Esc（\e\e）
# ============================================================================
##在命令前插入 sudo {{{
#定义功能
sudo-command-line() {
[[ -z $BUFFER ]] && zle up-history
[[ $BUFFER != sudo\ * ]] && BUFFER="sudo $BUFFER"
zle end-of-line                 #光标移动到行末
}
zle -N sudo-command-line
#定义快捷键为： [Esc] [Esc]
bindkey "\e\e" sudo-command-line

# ============================================================================
# 模块十一：命令别名
# 功能：为常用命令设置简短别名，提高效率并增加安全性
#   安全类（覆盖前确认）：
#     cp='cp -i' / mv='mv -i' / rm='rm -i' —— 覆盖或删除前询问确认
#   显示类：
#     ls='ls -F --color=auto' —— 彩色显示，目录加 /、可执行文件加 *
#     ll='ls -al' —— 列出所有文件详情（含隐藏文件）
#     la='ls -a' —— 显示隐藏文件（以 . 开头的文件）
#     grep='grep --color=auto' —— grep 结果高亮匹配内容
#   工具类：
#     h='htop' —— 快速启动 htop 系统监控
#   run-help —— 将 run-help 绑定到 Esc+h，执行 man 当前命令时显示简短说明
#   top10 —— 统计历史命令中使用频率最高的 10 条
# ============================================================================
#命令别名 {{{
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias ls='ls -F --color=auto'
alias ll='ls -al'
alias grep='grep --color=auto'
alias la='ls -a'
alias h='htop'

#[Esc][h] man 当前命令时，显示简短说明
alias run-help >&/dev/null && unalias run-help
autoload run-help

#历史命令 top10
alias top10='print -l  ${(o)history%% *} | uniq -c | sort -nr | head -n 10'

# ============================================================================
# 模块十二：路径别名（命名目录）
# 功能：设置快速跳转别名，输入 cd ~x 即可跳转到指定路径
#   hash -d E="/etc/" —— cd ~E 等同于 cd /etc/
#   用法：cd ~E 即可快速进入 /etc/ 目录
# ============================================================================
#路径别名 {{{
#进入相应的路径时只要 cd ~xxx
hash -d E="/etc/"

# ============================================================================
# 模块十三：自定义补全
# 功能：为特定命令配置自定义的补全候选列表
#   ping 补全 —— 按 Tab 自动补全为预设的主机地址：
#     192.168.1.{1,50,51,100,101} 和 www.google.com
#   ssh/scp/sftp 补全（已注释）—— 从 /etc/ssh_hosts 和 ~/.ssh/known_hosts
#     自动读取已知主机列表用于 SSH 类命令的补全
# ============================================================================
#{{{自定义补全
#补全 ping
zstyle ':completion:*:ping:*' hosts 192.168.1.{1,50,51,100,101} www.google.com

# ============================================================================
# 模块十四：F1 计算器
# 功能：按 F1 键将当前命令行内容包裹为算术表达式并求值
#   arith-eval-echo() —— 在光标处插入 echo $(( ... ))
#   绑定键：F1（^[[11~）
#   使用方法：输入 3+5，按 F1 → 自动变为 echo $(( 3+5 ))，回车后输出 8
# ============================================================================
#{{{ F1 计算器
arith-eval-echo() {
LBUFFER="${LBUFFER}echo \$(( "
RBUFFER=" ))$RBUFFER"
}
zle -N arith-eval-echo
bindkey "^[[11~" arith-eval-echo

# ============================================================================
# 模块十五：工具函数与扩展加载
# 功能：提供实用工具函数和加载 zsh 扩展模块
#   timeconv —— 将 Unix 时间戳转换为可读格式
#     用法：timeconv 1672531200 → 2023-01-01 08:00:00
#   zsh/mathfunc —— 加载数学函数库（支持 sin、sqrt、log 等运算）
#   zsh-mime-setup —— 根据文件扩展名自动用默认程序打开文件
#     如 .pdf 用 PDF 阅读器，.png 用图片查看器
#   EXTENDED_GLOB —— 启用扩展 glob 模式（** 递归、~ 排除、^ 取反等高级通配符）
#   correctall —— 自动修正命令拼写错误（如输入 gnome-desptop 会提示修正为 gnome-desktop）
# ============================================================================

function timeconv { date -d @$1 +"%Y-%m-%d %T" }


zmodload zsh/mathfunc
autoload -U zsh-mime-setup
zsh-mime-setup
setopt EXTENDED_GLOB

setopt correctall
autoload compinstall

# ============================================================================
# 模块十六：命令语法高亮
# 功能：在命令行中根据命令类型动态显示不同颜色
#   recolor-cmd() 函数逐个分析命令行中的 token，根据类型着色：
#     保留字（if/then/for）→ 品红色粗体
#     别名（ll/la）→ 青色粗体
#     shell 内建命令（cd/echo）→ 黄色粗体
#     shell 函数 → 绿色粗体
#     sudo → 红色粗体
#     外部命令 → 蓝色粗体
#   TOKENS_FOLLOWED_BY_COMMANDS —— 定义哪些 token 后面跟的是命令名
#     如 |、&&、;、sudo、do 等，用于判断下一个 token 是否需要高亮为命令
# ============================================================================
#漂亮又实用的命令高亮界面
setopt extended_glob
 TOKENS_FOLLOWED_BY_COMMANDS=('|' '||' ';' '&' '&&' 'sudo' 'do' 'time' 'strace')

recolor-cmd() {
     region_highlight=()
     colorize=true
     start_pos=0
     for arg in ${(z)BUFFER}; do
         ((start_pos+=${#BUFFER[$start_pos+1,-1]}-${#${BUFFER[$start_pos+1,-1]## #}}))
         ((end_pos=$start_pos+${#arg}))
         if $colorize; then
             colorize=false
             res=$(LC_ALL=C builtin type $arg 2>/dev/null)
             case $res in
                 *'reserved word'*)   style="fg=magenta,bold";;
                 *'alias for'*)       style="fg=cyan,bold";;
                 *'shell builtin'*)   style="fg=yellow,bold";;
                 *'shell function'*)  style='fg=green,bold';;
                 *"$arg is"*)
                     [[ $arg = 'sudo' ]] && style="fg=red,bold" || style="fg=blue,bold";;
                 *)                   style='none,bold';;
             esac
             region_highlight+=("$start_pos $end_pos $style")
         fi
         [[ ${${TOKENS_FOLLOWED_BY_COMMANDS[(r)${arg//|/\|}]}:+yes} = 'yes' ]] && colorize=true
         start_pos=$end_pos
     done
}

# ============================================================================
# 模块十七：pnpm 包管理器配置
# 功能：将 pnpm 的安装目录加入 PATH 环境变量
#   PNPM_HOME —— pnpm 全局包的安装目录（~/.local/share/pnpm）
#   case 语句 —— 防止重复添加 PATH（先检查是否已存在）
# ============================================================================
export PNPM_HOME="/home/zemi/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# ============================================================================
# 模块十八：npm 全局包路径
# 功能：将 npm 全局安装的包的可执行文件目录加入 PATH
#   ~/.npm-global/bin —— npm install -g 安装的命令行工具存放位置
# ============================================================================
export PATH=~/.npm-global/bin:$PATH

# ============================================================================
# 模块十九：代理开关函数
# 功能：一键开启/关闭 HTTP/HTTPS 代理（适用于 Clash 等本地代理工具）
#   proxy_on —— 设置 http_proxy/https_proxy 环境变量指向 127.0.0.1:7890
#     同时设置 no_proxy 排除本地地址（127.0.0.1, localhost）
#     大写和小写环境变量都设置，确保兼容不同工具
#   proxy_off —— 清除所有代理环境变量，恢复直连
#   使用方法：终端输入 proxy_on 开启代理，proxy_off 关闭代理
# ============================================================================
# proxy
proxy_on () {
    export http_proxy=http://127.0.0.1:7890
    export https_proxy=http://127.0.0.1:7890
    export no_proxy=127.0.0.1,localhost
    export HTTP_PROXY=http://127.0.0.1:7890
    export HTTPS_PROXY=http://127.0.0.1:7890
    export NO_PROXY=127.0.0.1,localhost
    echo -e "\033[32m[√] 已开启代理\033[0m"
}
proxy_off () {
    unset http_proxy
    unset https_proxy
    unset no_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset NO_PROXY
    echo -e "\033[31m[×] 已关闭代理\033[0m"
}

# ============================================================================
# 模块二十：Rust 工具链配置
# 功能：配置 Rust 开发环境的路径和国内镜像源
#   RUSTUP_DIST_SERVER / RUSTUP_UPDATE_ROOT —— 使用 rsproxy.cn 国内镜像
#     替代官方 rustup 源，大幅加速国内下载速度
#   CARGO_HOME —— Cargo（Rust 包管理器）的根目录（~/.cargo）
#   PATH —— 将 ~/.cargo/bin 加入 PATH，使 rustc/cargo 等命令全局可用
# ============================================================================

export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
export CARGO_HOME="$HOME/.cargo"
export PATH="$CARGO_HOME/bin:$PATH"

# ============================================================================
# 模块二十一：Bun 运行时配置
# 功能：配置 Bun（JavaScript 运行时/包管理器）的环境
#   _bun 补全脚本 —— 加载 bun 的 Tab 补全支持（仅在文件存在时加载）
#   BUN_INSTALL —— Bun 的安装目录（~/.bun）
#   PATH —— 将 ~/.bun/bin 加入 PATH，使 bun 命令全局可用
# ============================================================================
[ -s "/home/zemi/.bun/_bun" ] && source "/home/zemi/.bun/_bun"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ============================================================================
# 模块二十二：其他工具 PATH
# 功能：将各类自定义工具目录加入 PATH
#   ~/cc-haha/bin —— 自定义工具目录
#   ~/.local/bin —— Antigravity CLI 等用户级工具安装目录
# ============================================================================
export PATH="$HOME/cc-haha/bin:$PATH"

export PATH="/home/zemi/.local/bin:$PATH"
