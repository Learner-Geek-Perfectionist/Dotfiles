 Dotfiles for macOS and Linux machine

1.
```
 git clone --depth 1 git@github.com:Learner-Geek-Perfectionist/dotfiles.git
 cd dotfiles
 chmod +x ./install.sh
 ./install.sh
```

2.
```bash
# Setup Instructions for macOS and Linux

# macOS

caffeinate -d -i -s -t 86400

# GitHub

caffeinate -i /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/bootstrap.sh)"  

# Gitee

caffeinate -i /bin/zsh -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/bootstrap.sh)" 

# Linux

# GitHub

/bin/bash -c "$(curl -H -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/bootstrap.sh)"  

# Gitee

/bin/bash -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/bootstrap.sh)"  

```
