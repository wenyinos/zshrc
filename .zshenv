# ============================================================================
# bash 兼容层（仅非交互 shell 生效，供 AI agent / 自动化脚本调用）
# 背景：agent 以 `zsh -l -c` 方式调用（非交互登录 shell），不会读取 ~/.zshrc，
#       只读取本文件。把 zsh 特有的解析/展开行为对齐 bash，避免 agent 命令
#       因 "no matches found" 中止整个脚本、变量不分词、数组下标错位等问题。
# 交互式终端不受影响（[[ ! -o interactive ]] 守卫），保留 zsh 原生习惯用法。
# ============================================================================
if [[ ! -o interactive ]]; then
  setopt NO_NOMATCH          # 通配符无匹配时按字面传给命令（bash 行为），不再中止整个脚本
  setopt SH_WORD_SPLIT       # 未加引号的变量展开按空白分词（bash 行为）
  setopt GLOB_SUBST          # 变量展开结果再做通配符展开（bash 行为）
  setopt KSH_ARRAYS          # 数组下标从 0 开始、$arr 取首元素（bash 行为）
  setopt BASH_REMATCH        # [[ 字符串 =~ 正则 ]] 的捕获写入 BASH_REMATCH（bash 行为）
  unsetopt MULTIOS           # `cmd >a >b` 只写最后一个文件（bash 行为），不再同时双写
  unsetopt EQUALS            # 不把 =cmd 展开为命令路径（bash 无此行为；此前会连累 [ a == a ] 报错）
  unsetopt FUNCTION_ARGZERO  # 函数内 $0 保持 shell/脚本名而非函数名（bash 行为）
fi
