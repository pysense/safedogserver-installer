#!/bin/bash
# by pysense (pysense@gmail.com)

[[ $(id -u) != "0" ]] && { echo "该脚本需要以 root 权限执行。"; exit 127; }

set -o errexit
set -o nounset

check_os() {
    # 返回变量
    #     $OS_BIT 系统位数
    #     $OS 系统名称
    #     $OS_VERSION 系统版本号

    OS_BIT=$(getconf LONG_BIT)

    # 获取 CentOS, RedHat 系统版本
    if [[ -r /etc/redhat-release ]]; then
        eval $(awk '/release/ {for(i=1;i<=NF;i++) if($i ~ /[0-9.]+/) {print "OS="$1"\nOS_VERSION="$i}}' /etc/redhat-release)
        [[ "$OS" == "Red" ]] && OS="RedHat"
        [[ -n "$OS" && -n "$OS_VERSION" ]] && return
    fi

    # 获取 Ubuntu 系统版本
    if [[ -r /etc/lsb-release ]]; then
        eval $(awk '/^DISTRIB_ID/ || /^DISTRIB_RELEASE/ {print}' /etc/lsb-release)
        OS=$DISTRIB_ID; OS_VERSION=$DISTRIB_RELEASE
        [[ -n "$OS" && -n "$OS_VERSION" ]] && return
    fi

    error "脚本暂时不支持该系统。"
}

sdserver_install() {
    tmp_dir=sdserver-installer_$(date +%s)
    mkdir -p /tmp/$tmp_dir
    pushd /tmp/$tmp_dir > /dev/null
    soft_url="http://down.safedog.cn/$soft_name"
    echo "下载客户端：$soft_url"
    set +e
    http_code=$(curl -s -w %{http_code} $soft_url -o $soft_name)
    set -e
    if [[ "$http_code" != "200" ]]; then
        error "客户端下载失败，请检查网络是否可用。"
    fi
    tar xzf $soft_name
    cd $(tar tzf $soft_name | head -1)
    chmod +x ./install.py
    ./install.py -w web_no
    cd; clean
}

fuyun_login() {
    cat << EOF
可以通过以下其中一种方式登陆服云：

方法1：

  执行命令：'sdcloud -u 账号名'

方法2：

  1. 登陆网页：http://fuyun.safedog.cn
  2. 下载证书
  3. 将证书文件（safedog_user.psf）存放到目录：/etc/safedog/sdcc/
  4. 执行命令：'sdmonitor -r sdcc'

如果是覆盖安装（升级），并且之前已登陆服云，请忽略该操作。
EOF
}

check_selinux() {
    if [[ -f /etc/selinux/config ]]; then
        if [[ $(getenforce) != "Disabled" ]]; then
            setenforce 0
            sed -i 's/\(SELINUX=\).*/\1disabled/' /etc/selinux/config
        fi
    fi
}

set_python_path() {
    if which python &> /dev/null; then
        return
    else
        if which python3 &> /dev/null; then
            ln -s $(which python3) /bin/python
        else
            error "当前系统未发现可用的 Python，请安装 Python 后重试。"
        fi
    fi
}

error() {
    echo "错误：$1"
    clean
    exit 1
}

clean() {
    [[ -d "/tmp/$tmp_dir" ]] && rm -fr /tmp/$tmp_dir
}

usage() {
    cat << EOF
服务器安全狗客户端安装脚本

用法：

  $0

EOF
}

if [[ $# != 0 ]]; then
    usage && exit
fi

echo "检查 SELinux 状态"
check_selinux

check_os
echo "安装依赖包，请确保系统存在可用软件源。"
case "${OS}" in
    "CentOS"|"RedHat")
        yum install -y pciutils dmidecode net-tools psmisc mlocate lsof zip
        # for Docker
        #yum install -y pciutils dmidecode net-tools psmisc mlocate lsof which file iptables initscripts e2fsprogs
        ;;
    "Debian"|"Ubuntu")
        apt-get install -y pciutils dmidecode net-tools psmisc mlocate lsof ifupdown zip
        ;;
    *)
        error "脚本暂时不支持该系统。"
        ;;
esac

case "${OS_BIT}" in
    "64")
        soft_name=safedog_linux64.tar.gz
        ;;
    "32")
        soft_name=safedog_linux32.tar.gz
        ;;
esac

echo "安装服务器安全狗"
set_python_path
sdserver_install

echo "登陆服云账号"
fuyun_login
