#!/bin/bash

# 一旦错误，就退出
set -e

git clone --depth=1 git@github.com:Learner-Geek-Perfectionist/Dotfiles.git

cd Dotfiles

source ./main.sh
