#!/bin/bash

# ipinfo.io API Token（从 age-tokens 加密环境变量读取）
API_TOKEN="${IPINFO_TOKEN:?请先运行 edit-tokens 设置 IPINFO_TOKEN}"

# 🌐 获取公网IP
echo -e "\033[1;34m🌐 Fetching public IP address...\033[0m"
MY_IP=$(curl -s https://api.ipify.org)  # 获取公网IP
response=$(curl -s "https://ipinfo.io/${MY_IP}?token=${API_TOKEN}")

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
    SE) flag="🇸🇪" ;;
    IL) flag="🇮🇱" ;;
    IR) flag="🇮🇷" ;;
    IQ) flag="🇮🇶" ;;
    PK) flag="🇵🇰" ;;
    BD) flag="🇧🇩" ;;
    VN) flag="🇻🇳" ;;
    AR) flag="🇦🇷" ;;
    CL) flag="🇨🇱" ;;
    CO) flag="🇨🇴" ;;
    UA) flag="🇺🇦" ;;  # 乌克兰的旗帜
    TH) flag="🇹🇭" ;;  # 泰国旗帜
    CL) flag="🇨🇱" ;;  # 智利旗帜
    NG) flag="🇳🇬" ;;  # 尼日利亚旗帜
    # 可以继续添加更多国家
    *) flag="🌍" ;;
esac

# 打印公网IP信息和国家图标
echo -e "\033[1;32m✅ My public IP information ( $flag ):\033[0m"
echo "$response" | jq '.'

# 根据操作系统选择接口和获取私有IP地址的方法
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS 系统
    echo -e "\033[1;33m🔍 Detecting private IP address on macOS...\033[0m"
    PRIVATE_IP=$(ifconfig en0 | grep 'inet ' | awk '{print $2}')
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux 系统
    echo -e "\033[1;33m🔍 Detecting private IP address on Linux...\033[0m"
    PRIVATE_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
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
