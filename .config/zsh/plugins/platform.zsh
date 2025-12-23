# 平台相关配置
# macOS: Homebrew 镜像源
# Linux: FPATH 补全路径

if [[ "$(uname -s)" == "Darwin" ]]; then
	# ========================================
	# macOS: Homebrew 镜像加速
	# ========================================
	export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
	export HOMEBREW_API_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
	export HOMEBREW_PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

elif [[ "$(uname -s)" == "Linux" ]]; then
	# ========================================
	# Linux: 修复 pixi 可能覆盖的 HOST 变量
	# pixi 激活时会设置 HOST 为平台三元组 (如 aarch64-conda-linux-gnu)
	# 这会导致 p10k 的 context segment 显示错误的主机名
	# ========================================
	export HOST=$(hostname -s 2>/dev/null || hostname)

	# ========================================
	# Linux: 添加 zsh 补全路径到 FPATH
	# ========================================
	if [[ -d "/usr/share/zsh" ]]; then
		for dir in /usr/share/zsh/*/; do
			[[ ":$FPATH:" != *":${dir%/}:"* ]] && FPATH="${dir%/}:$FPATH"
		done
		export FPATH
	fi
fi

