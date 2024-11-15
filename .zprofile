
# 删除 Apple Terminal 的 .zsh_sessions 文件
[ -e "$HOME/.zsh_sessions" ] && rm -r "$HOME/.zsh_sessions" && echo "Deleted $HOME/zsh_sessions successfully."


# 删除 $HOME 目录下的 .zcompdump 缓存文件
[[ -f $HOME/.zcompdump ]] && rm $HOME/.zcompdump && echo "Deleted $HOME/.zcompdump successfully."
