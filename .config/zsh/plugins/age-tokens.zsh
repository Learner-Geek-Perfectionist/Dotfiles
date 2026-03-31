# age-tokens: 使用 age + SSH 密钥加密管理环境变量 tokens
# 依赖: age (https://github.com/FiloSottile/age)
# 密钥: 复用 ~/.ssh/id_ed25519，无需额外管理 age 专用密钥

if (( ! ${+AGE_SSH_KEY} )); then
  readonly AGE_SSH_KEY="${HOME}/.ssh/id_ed25519"
  readonly AGE_SSH_PUB="${HOME}/.ssh/id_ed25519.pub"
  readonly AGE_TOKENS="${HOME}/.tokens.sh.age"
fi

# 启动时自动加载加密的 tokens
if (( $+commands[age] )) && [[ -f "$AGE_TOKENS" && -f "$AGE_SSH_KEY" ]]; then
  local _age_out
  if _age_out=$(age -d -i "$AGE_SSH_KEY" "$AGE_TOKENS" 2>/dev/null); then
    [[ -n "$_age_out" ]] && eval "$_age_out"
  else
    print -P "%F{yellow}[age-tokens] 解密失败，tokens 未加载%f" >&2
  fi
fi

# 编辑 tokens 的便捷函数
edit-tokens() {
  if [[ ! -f "$AGE_SSH_KEY" ]]; then
    echo "错误：未找到 SSH 密钥 $AGE_SSH_KEY"
    echo "请先生成：ssh-keygen -t ed25519"
    return 1
  fi

  if [[ ! -f "$AGE_SSH_PUB" ]]; then
    echo "错误：未找到 SSH 公钥 $AGE_SSH_PUB"
    return 1
  fi

  local tmp tmp_age
  tmp=$(umask 077 && mktemp) || { echo "无法创建临时文件"; return 1; }
  trap "rm -f ${(q)tmp}" EXIT INT TERM

  if [[ -f "$AGE_TOKENS" ]]; then
    age -d -i "$AGE_SSH_KEY" "$AGE_TOKENS" > "$tmp" || { echo "解密失败"; rm -f "$tmp"; trap - EXIT INT TERM; return 1; }
  else
    echo '# 每行一个 export，例如：' > "$tmp"
    echo '# export GITHUB_TOKEN="ghp_xxx"' >> "$tmp"
  fi

  local editor=$(command -v nvim || command -v vim)
  if [[ -z "$editor" ]]; then
    echo "错误：未找到 nvim 或 vim"
    rm -f "$tmp"; trap - EXIT INT TERM; return 1
  fi

  if ! "$editor" "$tmp"; then
    echo "编辑器异常退出，放弃保存"
    rm -f "$tmp"; trap - EXIT INT TERM; return 1
  fi

  # 先加密到临时文件，成功后原子替换，避免损坏原文件
  tmp_age=$(mktemp)
  trap "rm -f ${(q)tmp} ${(q)tmp_age}" EXIT INT TERM
  if age -R "$AGE_SSH_PUB" -o "$tmp_age" "$tmp"; then
    mv "$tmp_age" "$AGE_TOKENS"
  else
    echo "加密失败，原文件未修改"
    rm -f "$tmp_age" "$tmp"; trap - EXIT INT TERM; return 1
  fi

  # 从仍在内存可达的明文直接 source，避免多余的解密
  source "$tmp"
  rm -f "$tmp"
  trap - EXIT INT TERM
  echo "Tokens updated and reloaded."
}
