# age-tokens: 使用 age 加密管理环境变量 tokens
# 依赖: age (https://github.com/FiloSottile/age)

# 启动时自动加载加密的 tokens
if [[ -f ~/.tokens.sh.age && -f ~/.age/key.txt ]]; then
  source <(age -d -i ~/.age/key.txt ~/.tokens.sh.age 2>/dev/null)
fi

# 编辑 tokens 的便捷函数
edit-tokens() {
  # 首次使用：自动初始化密钥和空 tokens 文件
  if [[ ! -f ~/.age/key.txt ]]; then
    echo "首次使用，生成 age 密钥..."
    mkdir -p ~/.age
    age-keygen -o ~/.age/key.txt
    chmod 600 ~/.age/key.txt
  fi

  local pubkey=$(grep 'public key:' ~/.age/key.txt | awk '{print $NF}')

  local tmp=$(mktemp)
  if [[ -f ~/.tokens.sh.age ]]; then
    age -d -i ~/.age/key.txt ~/.tokens.sh.age > "$tmp"
  else
    echo '# 每行一个 export，例如：' > "$tmp"
    echo '# export GITHUB_TOKEN="ghp_xxx"' >> "$tmp"
  fi

  # 优先 VSCode，其次 nvim，最后 vi
  local editor
  if command -v code &>/dev/null; then
    editor="code --wait"
  elif command -v nvim &>/dev/null; then
    editor="nvim"
  else
    editor="vi"
  fi
  ${=editor} "$tmp"

  age -r "$pubkey" -o ~/.tokens.sh.age "$tmp"
  rm -f "$tmp"
  source <(age -d -i ~/.age/key.txt ~/.tokens.sh.age 2>/dev/null)
  echo "Tokens updated and reloaded."
}
