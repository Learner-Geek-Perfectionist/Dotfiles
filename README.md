 Dotfiles for macOS and Linux machine

1.
```
 git clone --depth 1 git@github.com:Learner-Geek-Perfectionist/dotfiles.git
 cd Dotfiles
 chmod +x ./install.sh
 ./install.sh
```

2.
```
# macOS 
caffeinate -d -i -s -t 86400

# GitHub
caffeinate -i /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh)"

# Gitee
caffeinate -i /bin/zsh -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/install.sh)"


#Linux

# GitHub

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh)"


# Gitee
/bin/bash -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/install.sh)"
```


