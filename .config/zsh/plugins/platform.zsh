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
	# Linux: 添加 zsh 补全路径到 FPATH
	# ========================================
	if [[ -d "/usr/share/zsh" ]]; then
		for dir in /usr/share/zsh/*/; do
			[[ ":$FPATH:" != *":${dir%/}:"* ]] && FPATH="${dir%/}:$FPATH"
		done
		export FPATH
	fi
fi
