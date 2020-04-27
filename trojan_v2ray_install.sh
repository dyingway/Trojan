#!/bin/bash

# fonts color
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}


function getGithubLatestReleaseVersion() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" | grep -Po '"tag_name": "v\K.*?(?=")'
}

function setDateZone(){
    if [[ -f /etc/localtime ]] && [[ -f /usr/share/zoneinfo/Asia/Shanghai ]];  then
        mv /etc/localtime /etc/localtime.bak
        cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    fi

    date -R
}


function installOnMyZsh(){
    testPortUsage

    green "======================="
    yellow "准备安装 ZSH and oh-my-zsh"
    green "======================="

    if [ "$osRelease" == "centos" ]; then

        sudo $osSystemPackage update && sudo $osSystemPackage install zsh -y

    elif [ "$osRelease" == "ubuntu" ]; then

        $osSystemPackage install zsh -y

    elif [ "$osRelease" == "debian" ]; then

        $osSystemPackage install zsh -y
    fi

    # 安装 oh-my-zsh
    if [[ ! -d "${HOME}/.oh-my-zsh" ]] ;  then
        curl -Lo ${HOME}/ohmyzsh_install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
        chmod +x ${HOME}/ohmyzsh_install.sh
        sh ${HOME}/ohmyzsh_install.sh --unattended
    fi

    if [[ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]] ;  then
        git clone "https://github.com/zsh-users/zsh-autosuggestions" "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

        # 配置 zshrc 文件
        zshConfig=${HOME}/.zshrc
        zshTheme="maran"
        sed -i 's/ZSH_THEME=.*/ZSH_THEME="'${zshTheme}'"/' $zshConfig
        sed -i 's/plugins=(git)/plugins=(git cp history z rsync colorize zsh-autosuggestions)/' $zshConfig

        zshAutosuggestionsConfig=${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
        sed -i "s/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=1'/" $zshAutosuggestionsConfig


        # Actually change the default shell to zsh
        zsh=$(which zsh)

        if ! chsh -s "$zsh"; then
            error "chsh command unsuccessful. Change your default shell manually."
        else
            export SHELL="$zsh"
            green "===== Shell successfully changed to '$zsh'."
        fi

    fi


    # 设置vim 中文乱码
    if [[ ! -d "${HOME}/.vimrc" ]] ;  then
        cat > "${HOME}/.vimrc" <<-EOF
set fileencodings=utf-8,gb2312,gb18030,gbk,ucs-bom,cp936,latin1
set enc=utf8
set fencs=utf8,gbk,gb2312,gb18030

syntax on
set nu!
set autoindent
EOF
    fi


    # 安装 micro 编辑器
    mkdir -p ${HOME}/bin
    cd ${HOME}/bin
    curl https://getmic.ro | bash

    cp ${HOME}/bin/micro /usr/local/bin
}




osRelease=""
osSystemPackage=""
osSystemmdPath=""

function getLinuxOSVersion(){
    # copy from 秋水逸冰 ss scripts
    if [[ -f /etc/redhat-release ]]; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemmdPath="/usr/lib/systemd/system/"
    elif cat /etc/issue | grep -Eqi "debian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemmdPath="/lib/systemd/system/"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemmdPath="/lib/systemd/system/"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemmdPath="/usr/lib/systemd/system/"
    elif cat /proc/version | grep -Eqi "debian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemmdPath="/lib/systemd/system/"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemmdPath="/lib/systemd/system/"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemmdPath="/usr/lib/systemd/system/"
    fi
    echo "OS info: ${osRelease}, ${osSystemPackage}, ${osSystemmdPath}"
}


osPort80=""
osPort443=""
osSELINUXCheck=""
osSELINUXCheckIsReboot=""

function testPortUsage() {
    $osSystemPackage -y install net-tools socat

    osPort80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
    osPort443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`

    if [ -n "$osPort80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
        red "==========================================================="
        red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
        red "==========================================================="
        exit 1
    fi

    if [ -n "$osPort443" ]; then
        process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
        red "============================================================="
        red "检测到443端口被占用，占用进程为：${process443}，本次安装结束"
        red "============================================================="
        exit 1
    fi

    osSELINUXCheck=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$osSELINUXCheck" == "SELINUX=enforcing" ]; then
        red "======================================================================="
        red "检测到SELinux为开启强制模式状态，为防止申请证书失败，请先重启VPS后，再执行本脚本"
        red "======================================================================="
        read -p "是否现在重启? 请输入 [Y/n] :" osSELINUXCheckIsReboot
        [ -z "${osSELINUXCheckIsReboot}" ] && osSELINUXCheckIsReboot="y"

        if [[ $osSELINUXCheckIsReboot == [Yy] ]]; then
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
            echo -e "VPS 重启中..."
            reboot
        fi
        exit
    fi

    if [ "$osSELINUXCheck" == "SELINUX=permissive" ]; then
        red "======================================================================="
        red "检测到SELinux为宽容模式状态，为防止申请证书失败，请先重启VPS后，再执行本脚本"
        red "======================================================================="
        read -p "是否现在重启? 请输入 [Y/n] :" osSELINUXCheckIsReboot
        [ -z "${osSELINUXCheckIsReboot}" ] && osSELINUXCheckIsReboot="y"

        if [[ $osSELINUXCheckIsReboot == [Yy] ]]; then
            sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
            echo -e "VPS 重启中..."
            reboot
        fi
        exit
    fi

    if [ "$osRelease" == "centos" ]; then
        if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ; then
            red "==============="
            red "当前系统不受支持"
            red "==============="
            exit
        fi

        if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ; then
            red "==============="
            red "当前系统不受支持"
            red "==============="
            exit
        fi

        systemctl stop firewalld
        systemctl disable firewalld
        rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
        $osSystemPackage update -y
        $osSystemPackage install curl wget xz git unzip zip tar -y

    elif [ "$osRelease" == "ubuntu" ]; then
        if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
        red "==============="
        red "当前系统不受支持"
        red "==============="
        exit
        fi
        if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
        red "==============="
        red "当前系统不受支持"
        red "==============="
        exit
        fi

        systemctl stop ufw
        systemctl disable ufw
        $osSystemPackage update -y
        $osSystemPackage install curl wget git unzip zip xz-utils tar -y

    elif [ "$osRelease" == "debian" ]; then
        $osSystemPackage update -y
        $osSystemPackage install curl wget git unzip zip xz-utils tar -y
    fi

}


configRealIp=""
configLocalIp=""
configDomainTrojan=""
configDomainV2ray=""

configTrojanPath="${HOME}/trojan"
configTrojanLogFile="${HOME}/trojan-access.log"
configTrojanCertPath="${HOME}/trojan/cert"
configTrojanWebsitePath="${HOME}/trojan/website/html"
configTrojanWindowsCliPath=$(cat /dev/urandom | head -1 | md5sum | head -c 16)


trojanVersion="1.15.1"

nginxConfigPath="/etc/nginx/nginx.conf"


function install_nginx(){


    green "======================="
    yellow "请输入绑定到本VPS的域名"
    green "======================="
    read configDomainTrojan
    configRealIp=`ping ${configDomainTrojan} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    configLocalIp=`curl ipv4.icanhazip.com`
    if [ $configRealIp == $configLocalIp ] ; then
        green "=========================================="
        green " 域名解析地址为 ${configRealIp}, 本VPS的IP为 ${configLocalIp}. 域名解析正常，开始安装 nginx !"
        green "=========================================="
        sleep 1s

        if test -s ${nginxConfigPath}; then
            green "==========================="
            green "      Nginx 已存在, 退出安装!"
            green "==========================="
            exit
        fi

        $osSystemPackage install nginx -y
        systemctl enable nginx.service
        systemctl stop nginx.service

        cat > "${nginxConfigPath}" <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /root/nginx-trojan-access.log  main;
    error_log /root/nginx-trojan-error.log;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $configDomainTrojan;
        root $configTrojanWebsitePath;
        index index.php index.html index.htm;
    }
}
EOF

        # 下载伪装站点 并设置伪装网站
        rm -rf ${configTrojanWebsitePath}/*
        mkdir -p ${configTrojanWebsitePath}
        wget -O ${configTrojanPath}/website/trojan_website.zip https://github.com/jinwyp/Trojan/raw/master/web.zip
        unzip -d ${configTrojanWebsitePath} ${configTrojanPath}/website/trojan_website.zip

        wget -O ${configTrojanPath}/website/trojan_client_all.zip https://github.com/jinwyp/Trojan/raw/master/trojan_client_all.zip
        unzip -d ${configTrojanWebsitePath} ${configTrojanPath}/website/trojan_client_all.zip

        systemctl start nginx.service

        green "=========================================="
        green "       Web服务器 nginx 安装成功!!"
        green "=========================================="


    else
        red "================================"
        red "域名解析地址与本VPS IP地址不一致"
        red "本次安装失败，请确保域名解析正常"
        red "================================"
        exit
    fi

}

function get_https_certificate(){

    #申请https证书
	mkdir -p ${configTrojanCertPath}
	curl https://get.acme.sh | sh


	if [[ s1 == "standalone" ]] ; then
	    green "===== acme.sh standalone mode !"
	    ~/.acme.sh/acme.sh  --issue  -d ${configDomainTrojan}  --standalone
	else
	    green "===== acme.sh nginx mode !"
        ~/.acme.sh/acme.sh  --issue  -d ${configDomainTrojan}  --webroot ${configTrojanWebsitePath}/
    fi

    ~/.acme.sh/acme.sh  --installcert  -d ${configDomainTrojan}   \
        --key-file   ${configTrojanCertPath}/private.key \
        --fullchain-file ${configTrojanCertPath}/fullchain.cer \
        --reloadcmd  "systemctl force-reload  nginx.service"

}


function download_trojan_server(){

    trojanPassword1=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword2=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword3=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword4=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword5=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword6=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword7=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword8=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword9=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword10=$(cat /dev/urandom | head -1 | md5sum | head -c 10)

    #wget https://github.com/trojan-gfw/trojan/releases/download/v1.15.1/trojan-1.15.1-linux-amd64.tar.xz
    trojanVersion=$(getGithubLatestReleaseVersion "trojan-gfw/trojan")
    #trojanVersion=$(curl --silent "https://api.github.com/repos/trojan-gfw/trojan/releases/latest" | grep -Po '"tag_name": "v\K.*?(?=")')

    if [[ -f ${configTrojanPath}/trojan-${trojanVersion}-linux-amd64.tar.xz ]]; then

        green "=========================================="
        green "  已安装过 Trojan v${trojanVersion}, 退出安装 !"
        green "=========================================="
        exit
    fi
    green "=========================================="
    green "       开始安装 Trojan Version: ${trojanVersion} !"
    green "=========================================="

    cd ${configTrojanPath}
    rm -rf ${configTrojanPath}/src

	wget -O ${configTrojanPath}/trojan-${trojanVersion}-linux-amd64.tar.xz  https://github.com/trojan-gfw/trojan/releases/download/v${trojanVersion}/trojan-${trojanVersion}-linux-amd64.tar.xz
	tar xf trojan-${trojanVersion}-linux-amd64.tar.xz -C ${configTrojanPath}
	mv ${configTrojanPath}/trojan ${configTrojanPath}/src


	cat > ${configTrojanPath}/src/server.conf <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojanPassword1",
        "$trojanPassword2",
        "$trojanPassword3",
        "$trojanPassword4",
        "$trojanPassword5",
        "$trojanPassword6",
        "$trojanPassword7",
        "$trojanPassword8",
        "$trojanPassword9",
        "$trojanPassword10",
        "jin202000",
        "jin202030",
        "jin202031",
        "jin202032",
        "jin202033",
        "jin202034",
        "jin202035",
        "jin202036",
        "jin202037",
        "jin202038",
        "jin202039",
        "jin202040",
        "jin202041",
        "jin202042",
        "jin202043",
        "jin202044",
        "jin202045",
        "jin202046",
        "jin202047",
        "jin202048",
        "jin202049",
        "jin202050",
        "jin202051",
        "jin202052",
        "jin202053",
        "jin202054",
        "jin202055",
        "jin202056",
        "jin202057",
        "jin202058",
        "jin202059",
        "jin202060",
        "jin202061",
        "jin202062",
        "jin202063",
        "jin202064",
        "jin202065",
        "jin202066",
        "jin202067",
        "jin202068",
        "jin202069",
        "jin202070",
        "jin202071",
        "jin202072",
        "jin202073",
        "jin202074",
        "jin202075",
        "jin202076",
        "jin202077",
        "jin202078",
        "jin202079",
        "jin202080",
        "jin202081",
        "jin202082",
        "jin202083",
        "jin202084",
        "jin202085",
        "jin202086",
        "jin202087",
        "jin202088",
        "jin202089",
        "jin202090",
        "jin202091",
        "jin202092",
        "jin202093",
        "jin202094",
        "jin202095",
        "jin202096",
        "jin202097",
        "jin202098",
        "jin202099"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "$configTrojanCertPath/fullchain.cer",
        "key": "$configTrojanCertPath/private.key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	    "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

    # 增加启动脚本
    cat > ${osSystemmdPath}trojan.service <<-EOF
[Unit]
Description=trojan
After=network.target

[Service]
Type=simple
PIDFile=${configTrojanPath}/src/trojan.pid
ExecStart=${configTrojanPath}/src/trojan -l $configTrojanLogFile -c "${configTrojanPath}/src/server.conf"
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=${configTrojanPath}/src/trojan
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

	chmod +x ${osSystemmdPath}trojan.service
	systemctl daemon-reload
	systemctl start trojan.service
	systemctl enable trojan.service



    # 下载并制作 trojan windows 下命令行启动文件
    rm -rf ${configTrojanPath}/trojan-win-cli

    wget -O ${configTrojanPath}/trojan-win-cli.zip https://github.com/jinwyp/Trojan/raw/master/trojan-win-cli.zip
    unzip -d ${configTrojanPath} ${configTrojanPath}/trojan-win-cli.zip
    rm ${configTrojanPath}/trojan-win-cli.zip

	cp ${configTrojanCertPath}/fullchain.cer ${configTrojanPath}/trojan-win-cli/fullchain.cer

    cat > ${configTrojanPath}/trojan-win-cli/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$configDomainTrojan",
    "remote_port": 443,
    "password": [
        "$trojanPassword1"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.cer",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	    "sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
    cd ${configTrojanPath}/trojan-win-cli/
    zip -r trojan-win-cli.zip ${configTrojanPath}/trojan-win-cli/
    mkdir -p ${configTrojanWebsitePath}/${configTrojanWindowsCliPath}
	mv ${configTrojanPath}/trojan-win-cli/trojan-win-cli.zip ${configTrojanWebsitePath}/${configTrojanWindowsCliPath}




    # 设置 cron 定时任务
    # https://stackoverflow.com/questions/610839/how-can-i-programmatically-create-a-new-cron-job

    # (crontab -l 2>/dev/null | grep -v '^[a-zA-Z]'; echo "15 4 * * 0,1,2,3,4,5,6 systemctl restart trojan.service") | sort - | uniq - | crontab -
    (crontab -l ; echo "15 4 * * 0,1,2,3,4,5,6 systemctl restart trojan.service") | sort - | uniq - | crontab -


	green "======================================================================"
	green "    Trojan Version: ${trojanVersion} 安装成功 !!"
	green "    伪装站点为 http://${configDomainTrojan}!"
	green "    伪装站点的静态html内容放置在目录 ${configTrojanWebsitePath}, 可自行更换网站内容!"
	red "    nginx 配置在目录 ${nginxConfigPath} !"
	red "    Trojan 服务器端配置在目录 ${configTrojanPath}/src/server.conf !"
	green "    trojan 停止命令: systemctl stop trojan.service 启动命令: systemctl start trojan.service"
	green "    nginx 停止命令: systemctl stop nginx.service 启动命令: systemctl start nginx.service"
	green "    Trojan 服务器 每天会自动重启,防止内存泄漏. 运行 crontab -l 命令 查看定时重启命令 !"
	green "======================================================================"
	blue  "----------------------------------------"
	yellow "Trojan 配置信息如下, 请自行复制保存, 密码任选其一 !!"
	yellow "服务器地址: ${configDomainTrojan}  端口: 443"
	yellow "密码1: ${trojanPassword1}"
	yellow "密码2: ${trojanPassword2}"
	yellow "密码3: ${trojanPassword3}"
	yellow "密码4: ${trojanPassword4}"
	yellow "密码5: ${trojanPassword5}"
	yellow "密码6: ${trojanPassword6}"
	yellow "密码7: ${trojanPassword7}"
	yellow "密码8: ${trojanPassword8}"
	yellow "密码9: ${trojanPassword9}"
	yellow "密码10: ${trojanPassword10}"
	blue  "----------------------------------------"
	green "======================================================================"
	green "请下载相应的trojan客户端:"
	yellow "1 Windows 客户端下载：http://${configDomainTrojan}/download/trojan-windows.zip"
	yellow "  Windows 客户端另一个版本下载：http://${configDomainTrojan}/download/Trojan-Qt5-windows.zip"
    yellow "2 MacOS 客户端下载：http://${configDomainTrojan}/download/trojan-mac.zip"
    yellow "  MacOS 客户端另一个版本下载：http://${configDomainTrojan}/download/Trojan-Qt5-macos.zip"
    yellow "3 Android 客户端下载 https://github.com/trojan-gfw/igniter/releases "
    yellow "4 iOS 客户端 请安装小火箭 https://shadowsockshelp.github.io/ios/ "
    yellow "  iOS 请安装小火箭另一个地址 https://lueyingpro.github.io/shadowrocket/index.html "
    yellow "  iOS 安装小火箭遇到问题 教程 https://github.com/shadowrocketHelp/help/ "
    green "======================================================================"
	green "教程与其他资源:"
	green "访问 https://www.v2rayssr.com/trojan-1.html ‎ 下载 浏览器插件 客户端 及教程"
	green "访问 https://westworldss.com/portal/page/download ‎ 下载 客户端 及教程"
	green "======================================================================"
	green "其他 Windows 客户端:"
	green "https://github.com/TheWanderingCoel/Trojan-Qt5/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Qv2ray/Qv2ray/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Dr-Incognito/V2Ray-Desktop/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Fndroid/clash_for_windows_pkg/releases"
	green "======================================================================"
	green "其他 Mac 客户端:"
	green "https://github.com/TheWanderingCoel/Trojan-Qt5/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Qv2ray/Qv2ray/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Dr-Incognito/V2Ray-Desktop/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/JimLee1996/TrojanX/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/yichengchen/clashX/releases "
	green "======================================================================"
	green "其他 Android 客户端:"
	green "https://github.com/trojan-gfw/igniter/releases "
	green "https://github.com/Kr328/ClashForAndroid/releases "
	green "======================================================================"
}



function install_trojan(){
    systemctl stop nginx.service
    testPortUsage
    install_nginx
    get_https_certificate

    if test -s ${configTrojanCertPath}/fullchain.cer; then
        green "=========================================="
        green "       证书获取成功!!"
        green "=========================================="

        download_trojan_server

	else
        red "==================================="
        red "https证书没有申请成果，自动安装失败"
        green "不要担心，你可以手动修复证书申请"
        green "1. 重启VPS"
        green "2. 重新执行脚本，使用修复证书功能"
        red "==================================="
	fi

}



function repair_cert(){
    systemctl stop nginx.service
    testPortUsage

    green "=============================="
    blue "请输入绑定到本VPS的域名"
    blue "务必与之前失败使用的域名一致"
    green "=============================="

    read configDomainTrojan
    configRealIp=`ping ${configDomainTrojan} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    configLocalIp=`curl ipv4.icanhazip.com`

    if [ $configRealIp == $configLocalIp ] ; then

        green "=========================================="
        green " 域名解析地址为 ${configRealIp}, 本VPS的IP为 ${configLocalIp}. 域名解析正常，开始重新申请证书 !"
        green "=========================================="

        get_https_certificate "standalone"

        if test -s ${configTrojanCertPath}/fullchain.cer; then
            green "=========================================="
            green "       证书获取成功!!"
            green "=========================================="

            download_trojan_server
        else
            red "==================================="
            red " 申请证书失败!  "
            red " 请检查域名和DNS是否生效, 稍后再尝试使用修复证书功能 ! "
            red "==================================="
        fi
    else
        red "================================"
        red "域名解析地址与本VPS IP地址不一致"
        red "本次安装失败，请确保域名解析正常"
        red "================================"
        exit
    fi
}




function remove_trojan(){
    green "================================"
    red "即将卸载trojan"
    red "同时卸载已安装的nginx"
    green "================================"
    systemctl stop nginx.service
    systemctl stop trojan
    systemctl disable trojan

    rm -f ${osSystemmdPath}trojan.service
    rm -rf ${configTrojanPath}

    if [ "$osRelease" == "centos" ]; then
        yum remove -y nginx
    else
        apt autoremove -y nginx
    fi

    crontab -r

    green "================================"
    green "  trojan 和 nginx 卸载完毕 !"
    green "  crontab 定时任务 删除完毕 !"
    green "================================"
}







function bbr_boost_sh(){
    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}







function start_menu(){
    clear
    green " ===================================="
    green " Trojan V2ray 一键安装自动脚本 2020-2-27 更新  "
    green " 系统：centos7+/debian9+/ubuntu16.04+"
    green " 网站：www.v2rayssr.com （已开启禁止国内访问）"
    green " 此脚本为 atrandys 的，波仔集成BBRPLUS加速及MAC客户端 "
    green " Youtube：波仔分享                "
    green " ===================================="
    blue " 声明："
    red " *请不要在任何生产环境使用此脚本"
    red " *请不要有其他程序占用80和443端口"
    red " *若是已安装trojan或第二次使用脚本，请先执行卸载trojan"
    green " ======================================="
    echo
    green " 1. 安装 trojan 和 nginx"
    red " 2. 卸载 trojan 与 nginx"
    green " 3. 修复证书 并继续安装 trojan 和 nginx"
    green " 4. 安装BBR-PLUS加速4合一脚本"
    green " 5. 安装v2ray websocket tls1.3"
    red " 6. 卸载v2ray websocket tls1.3"
    green " 7. 安装 trojan + v2ray websocket tls1.3"
    red " 8. 卸载 trojan + v2ray websocket tls1.3"
    green " 9. 安装 Oh My Zsh, 和插件zsh-autosuggestions"
    green " 10. 设置时区为北京时间+0800区, 这样cron定时脚本按照北京时间运行"
    blue " 0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    install_trojan
    ;;
    2)
    remove_trojan 
    ;;
    3)
    repair_cert 
    ;;
    4)
    bbr_boost_sh 
    ;;
    5)
    testPortUsage
    ;;
    6)
    setDateZone
    ;;
    7)
    testPortUsage
    ;;
    8)
    trojanVersion=$(getGithubLatestReleaseVersion "trojan-gfw/trojan")
    echo "${trojanVersion}"
    ;;
    9)
    installOnMyZsh
    ;;
    10)
    setDateZone
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "请输入正确数字"
    sleep 1s
    start_menu
    ;;
    esac
}


getLinuxOSVersion
start_menu
