#!/bin/bash

check_system(){
	[[ -z "`cat /etc/redhat-release | grep -iE "CentOS"`" ]] && echo -e "Error:Only support CentOS!" && exit 1
	[[ "`uname -m`" != "x86_64" ]] && echo "Error:Only support 64bit!" && exit 1
}

check_root(){
	[[ "`id -u`" != "0" ]] && echo "Error:Must be root user!" && exit 1
}

check_ovz(){
	yum update && yum install -y virt-what
	[[ "`virt-what`" != "openvz" ]] && echo "Error:Only support OpenVZ!" && exit 1
}

check_requirement(){
	yum install -y iptables
	for CMD in iptables grep cut xargs ip awk
	do
		if ! type -p ${CMD}; then
			echo -e "Error:requirement not found, please check!" && exit 1
		fi
	done
}

directory(){
	[[ ! -d /home/ovzbbr ]] && mkdir -p /home/ovzbbr
	cd /home/ovzbbr
}

download(){
	wget https://raw.githubusercontent.com/tcp-nanqinlang/lkl-rinetd/master/module/rinetd
	[[ ! -f rinetd ]] && echo -e "Error:rinetd download failed, please check!" && exit 1
	chmod +x rinetd
}

config-port(){
	echo "请输入你想加速的端口，然后回车"
	read -p "(此端口应与ssr的端口一致, 默认使用 443):" ports

	if [[ -z "${ports}" ]]; then
		echo -e "0.0.0.0 443 0.0.0.0 443\c" >> config-port.conf
	else
		for port in ${ports}
		do
			echo "0.0.0.0 ${port} 0.0.0.0 ${port}" >> config-port.conf
		done
	fi
}

config-rinetd(){
	IFACE=`ip -4 addr | awk '{if ($1 ~ /inet/ && $NF ~ /^[ve]/) {a=$NF}} END{print a}'`
	echo -e "#!/bin/bash \n cd /home/ovzbbr \n nohup ./rinetd -f -c config-port.conf raw ${IFACE} &" >> config-rinetd.sh && chmod +x config-rinetd.sh
}

self-start(){
	sed -i "s/exit 0/ /ig" /etc/rc.d/rc.local
	echo -e "\n/home/ovzbbr/config-rinetd.sh\c" >> /etc/rc.d/rc.local
	chmod +x /etc/rc.d/rc.local
}

run-it-now(){
	./config-rinetd.sh
}

install(){
	check_system
	check_root
	check_ovz
	check_requirement
	directory
	download
	config-port
	config-rinetd
	self-start
	run-it-now
	status
}

status(){
	if [[ ! -z `ps -A | grep rinetd` ]]; then
		echo -e "rinetd-bbr is running !"
		else echo -e "Error:rinetd-bbr not running, please check!"
	fi
}

uninstall(){
	check_root
	kill -9 `ps -A | grep rinetd | awk '{print $1}'`
	rm -rf /home/ovzbbr
	iptables -t raw -F
	sed -i '/\/home\/ovzbbr\/config-rinetd.sh/d' /etc/rc.d/rc.local
	echo "uninstall finished."
}

echo "请选择你要使用的功能: "
echo -e "1.安装 rinetd-bbr\n2.检查 rinetd-bbr 运行状态\n3.卸载 rinetd-bbr"
read -p "输入数字以选择:" function

while [[ ! "${function}" =~ ^[1-3]$ ]]
do
	echo "Error:无效输入"
	echo "请重新选择" && read -p "输入数字以选择:" function
done

if [[ "${function}" == "1" ]]; then
	install
elif [[ "${function}" == "2" ]]; then
	status
else
	uninstall
fi
