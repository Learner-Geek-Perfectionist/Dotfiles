# 平台相关配置
# macOS: Homebrew 镜像源
# Pixi: 补全路径

# ========================================
# Pixi: 添加补全路径到 FPATH
# ========================================
if [[ -d "$HOME/.pixi/envs/default/share/zsh/site-functions" ]]; then
	FPATH="$HOME/.pixi/envs/default/share/zsh/site-functions:$FPATH"
fi

if [[ "$OSTYPE" == darwin* ]]; then
	# ========================================
	# macOS: Homebrew 镜像加速
	# ========================================
	export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
	export HOMEBREW_API_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
	export HOMEBREW_PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

fi

