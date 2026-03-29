#!/bin/bash
set -eo pipefail

# 依赖检查
command -v jq &>/dev/null || { echo -e "\033[1;31m❌ Error: jq is required\033[0m"; exit 1; }

# ipinfo.io API Token（从 age-tokens 加密环境变量读取）
API_TOKEN="${IPINFO_TOKEN:?请先运行 edit-tokens 设置 IPINFO_TOKEN}"

# 🌐 获取公网IP
echo -e "\033[1;34m🌐 Fetching public IP address...\033[0m"
MY_IP=$(curl -s --connect-timeout 5 --max-time 10 https://api.ipify.org)

# 校验 IP 格式（避免空值或错误响应传给下一个 API）
if [[ -z "$MY_IP" || ! "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "\033[1;31m❌ Failed to get public IP address\033[0m"
    exit 1
fi

# 使用 Bearer token 认证（避免 token 出现在 URL 参数、ps aux、服务器日志中）
response=$(curl -s --connect-timeout 5 --max-time 10 \
    -H "Authorization: Bearer ${API_TOKEN}" \
    "https://ipinfo.io/${MY_IP}")

# 检查是否成功获取信息
if [[ -z "$response" ]]; then
    echo -e "\033[1;31m❌ Failed to retrieve information for IP: $MY_IP\033[0m"
    exit 1
fi

# 提取国家代码
country_code=$(echo "$response" | jq -r '.country')

# 根据国家代码匹配 emoji
flag="🌍" # 默认全球图标
case $country_code in
    US) flag="🇺🇸" ;;
    CA) flag="🇨🇦" ;;
    GB) flag="🇬🇧" ;;
    DE) flag="🇩🇪" ;;
    FR) flag="🇫🇷" ;;
    JP) flag="🇯🇵" ;;
    CN) flag="🇨🇳" ;;
    IN) flag="🇮🇳" ;;
    HK) flag="🇭🇰" ;;
    RU) flag="🇷🇺" ;;
    BR) flag="🇧🇷" ;;
    SA) flag="🇸🇦" ;;
    ZA) flag="🇿🇦" ;;
    AU) flag="🇦🇺" ;;
    IT) flag="🇮🇹" ;;
    ES) flag="🇪🇸" ;;
    KR) flag="🇰🇷" ;;
    MX) flag="🇲🇽" ;;
    NL) flag="🇳🇱" ;;
    SE) flag="🇸🇪" ;;
    NO) flag="🇳🇴" ;;
    DK) flag="🇩🇰" ;;
    FI) flag="🇫🇮" ;;
    PL) flag="🇵🇱" ;;
    TR) flag="🇹🇷" ;;
    NZ) flag="🇳🇿" ;;
    SG) flag="🇸🇬" ;;
    MY) flag="🇲🇾" ;;
    TH) flag="🇹🇭" ;;
    ID) flag="🇮🇩" ;;
    PH) flag="🇵🇭" ;;
    AE) flag="🇦🇪" ;;
    NG) flag="🇳🇬" ;;
    EG) flag="🇪🇬" ;;
    KE) flag="🇰🇪" ;;
    GH) flag="🇬🇭" ;;
    GR) flag="🇬🇷" ;;
    PT) flag="🇵🇹" ;;
    BE) flag="🇧🇪" ;;
    CH) flag="🇨🇭" ;;
    AT) flag="🇦🇹" ;;
    IL) flag="🇮🇱" ;;
    IR) flag="🇮🇷" ;;
    IQ) flag="🇮🇶" ;;
    PK) flag="🇵🇰" ;;
    BD) flag="🇧🇩" ;;
    VN) flag="🇻🇳" ;;
    AR) flag="🇦🇷" ;;
    CL) flag="🇨🇱" ;;
    CO) flag="🇨🇴" ;;
    UA) flag="🇺🇦" ;;
    # 可以继续添加更多国家
    *) flag="🌍" ;;
esac

# 打印公网IP信息和国家图标
echo -e "\033[1;32m✅ My public IP information ( $flag ):\033[0m"
echo "$response" | jq '.'

# 根据操作系统获取私有 IP（自动检测接口，不硬编码 en0/eth0）
echo -e "\033[1;33m🔍 Detecting private IP address...\033[0m"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: 尝试常见接口（Wi-Fi 通常是 en0，有线可能是 en1 等）
    PRIVATE_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux: 通过默认路由获取出口 IP，不依赖特定接口名
    PRIVATE_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
else
    echo -e "\033[1;31m❌ Unsupported OS\033[0m"
    exit 1
fi

# 检查是否成功获取私有IP
if [[ -z "$PRIVATE_IP" ]]; then
    echo -e "\033[1;31m❌ Failed to retrieve private IP address.\033[0m"
    exit 1
fi

# 打印私有IP地址信息
echo -e "\033[1;32m✅ My private IP address: $PRIVATE_IP\033[0m"
