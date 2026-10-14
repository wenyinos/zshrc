# My zshrc

## You must install zsh and Oh-my-zsh first.

### Oh My zsh Chinese mirror:

##### 在本地克隆后获取安装脚本。

```bash
git clone https://mirrors.cernet.edu.cn/ohmyzsh.git
cd ohmyzsh/tools
REMOTE=https://mirrors.cernet.edu.cn/ohmyzsh.git sh install.sh
```

##### 切换已有 ohmyzsh 至镜像源

```bash
git -C $ZSH remote set-url origin https://mirrors.cernet.edu.cn/ohmyzsh.git
git -C $ZSH pull
```

## .zshenv — 非交互 shell 的 bash 兼容层

zsh 仅在**交互模式**下读取 `.zshrc`。AI agent、编辑器任务与 CI 等通常以非交互方式调用 zsh（如 `zsh -l -c`），此时只会读取 `~/.zshenv`。为了让自动化命令的行为与 bash 一致（尤其是通配符无匹配时不再中止整个脚本），本仓库提供 `.zshenv` 兼容层：把它**追加**到目标机器的 `~/.zshenv` 末尾即可生效（已有内容时请勿覆盖，重复追加无害）。

| 设置 | 对齐的 bash 行为 |
| --- | --- |
| `setopt NO_NOMATCH` | 通配符无匹配时按字面传给命令，不再报 `no matches found` 中止脚本 |
| `setopt SH_WORD_SPLIT` | 未加引号的变量按空白分词，`for x in $list` 正常迭代 |
| `setopt GLOB_SUBST` | 变量展开的结果继续做通配符展开 |
| `setopt KSH_ARRAYS` | 数组下标从 0 开始，`${arr[0]}` 取首元素 |
| `setopt BASH_REMATCH` | `[[ 字符串 =~ 正则 ]]` 的捕获组写入 `BASH_REMATCH` |
| `unsetopt MULTIOS` | `cmd >a >b` 只写最后一个文件，不再同时双写 |
| `unsetopt EQUALS` | 不展开 `=cmd`；`[ a == a ]` 不再报 `= not found` |
| `unsetopt FUNCTION_ARGZERO` | 函数内 `$0` 保持 shell 名而非函数名 |

整个兼容层由 `[[ ! -o interactive ]]` 守卫包裹：**交互式终端不受影响**，zsh 原生的补全、纠错与高亮保持原样。

无法对齐的剩余差异（写脚本时避开即可）：`${v^^}` / `${v,,}` 大小写转换（zsh 用 `${v:u}` / `${v:l}`）、`shopt` / `mapfile` 等 bash 专有内建、`$PIPESTATUS`（zsh 为 `$pipestatus`）、`**` 默认递归（bash 需显式开启 globstar）。

使用方式：

```bash
cat .zshenv >> ~/.zshenv   # 已有 ~/.zshenv：追加到末尾
cp .zshenv ~/.zshenv       # 尚未有 ~/.zshenv：直接复制
```
