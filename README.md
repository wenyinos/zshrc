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
