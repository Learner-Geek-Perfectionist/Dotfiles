#!/bin/bash

source ~/powerlevel10k/powerlevel10k.zsh-theme
source ~/fast-syntax-highlighting.plugin.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
fpath=(~/zsh-completions/src $fpath)
rm -f ~/.zcompdump; compinit
