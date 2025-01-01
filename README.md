 Dotfiles for macOS and Linux machine

1.
```
 git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git
 cd Dotfiles
 ./main.sh
```

2.
```bash
# Setup Instructions for macOS and Linux

# macOS

caffeinate -d -i -s -t 86400

# GitHub

caffeinate -i /bin/zsh -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh?$(date +%s)")"  

# Gitee

caffeinate -i /bin/zsh -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://gitee.com/oyzxin/Dotfiles/raw/master/install.sh?$(date +%s)")"

# Linux

# GitHub

/bin/bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh?$(date +%s)")"  

# Gitee

/bin/bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://gitee.com/oyzxin/Dotfiles/raw/master/install.sh?$(date +%s)")" 
```

Only for zsh configuration


```bash
# GitHub

/bin/bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/zsh_config.sh?$(date +%s)")"

# Gitee

/bin/bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://gitee.com/oyzxin/Dotfiles/raw/master/zsh_config.sh?$(date +%s)")" 

```


Manual install
```
# GitHub

/bin/bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/manual_install_plugin.sh?$(date +%s)")"

# Gitee

/bin/bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL "https://gitee.com/oyzxin/Dotfiles/raw/master/manual_install_plugin.sh?$(date +%s)")" 


```

查找 Application 的 BundleId
```shell

mdls -name kMDItemCFBundleIdentifier /Applications/*.app | fzf
```
