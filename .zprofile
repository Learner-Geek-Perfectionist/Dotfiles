# 删除 Apple Terminal 的 .zsh_sessions 文件
if [ -e "$HOME/.zsh_sessions" ]; then
    rm -r "$HOME/.zsh_sessions"
    echo "Deleted .zsh_sessions successfully."
fi
