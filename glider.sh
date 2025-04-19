#!/usr/bin/env bash

Folder="/usr/local/glider"
Config_folder="/root/.glider"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
Separator_1="————————————————————"

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	fi
	bit=`uname -m`
}

check_pid(){
	PID=`ps -ef | grep "glider" | grep -v "grep" | grep -v "glider.sh"| grep -v "init.d" | grep -v "service" | awk '{print $2}'`
}

check_instance_pid(){
	local config_name=$1
	INSTANCE_PID=`ps -ef | grep "glider -config ${Config_folder}/${config_name}.conf" | grep -v "grep" | awk '{print $2}'`
}

get_ip(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}

check_new_ver(){
	echo -e "${Info} 请输入 glider 版本号，格式如：[ 1.34.0 ]，获取地址：[ https://github.com/nadoo/glider/releases ]"
	read -e -p "默认回车自动获取最新版本号:" glider_new_ver
	if [[ -z ${glider_new_ver} ]]; then
		glider_new_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/nadoo/glider/releases | grep -o '"tag_name": ".*"' |head -n 1| sed 's/"//g;s/v//g' | sed 's/tag_name: //g')
		if [[ -z ${glider_new_ver} ]]; then
			echo -e "${Error} glider 最新版本获取失败，请手动获取最新版本号[ https://github.com/nadoo/glider/releases ]"
			read -e -p "请输入版本号 [ 格式如 1.34.0 ] :" glider_new_ver
			[[ -z "${glider_new_ver}" ]] && echo "取消..." && exit 1
		else
			echo -e "${Info} 检测到 glider 最新版本为 [ ${glider_new_ver} ]"
		fi
	else
		echo -e "${Info} 即将准备下载 glider 版本为 [ ${glider_new_ver} ]"
	fi
}

check_install_status(){
	[[ ! -e "/usr/bin/glider" ]] && echo -e "${Error} glider 没有安装，请检查 !" && exit 1
	if [[ $1 == "check_conf" ]]; then
		[[ ! -e "${Config_folder}/glider.conf" ]] && echo -e "${Error} glider 配置文件不存在，请检查 !" && [[ $2 != "un" ]] && exit 1
	fi
}

download_glider(){
	cd "/usr/local"
	if [[ ${bit} == "x86_64" ]]; then
		bit="amd64"
	elif [[ ${bit} == "i386" || ${bit} == "i686" ]]; then
		bit="386"
	else
		bit="arm64"
	fi
	wget -N --no-check-certificate "https://github.com/nadoo/glider/releases/download/v${glider_new_ver}/glider_${glider_new_ver}_linux_${bit}.tar.gz"
	glider_name="glider_${glider_new_ver}_linux_${bit}"
	
	[[ ! -s "${glider_name}.tar.gz" ]] && echo -e "${Error} glider 压缩包下载失败 !" && exit 1
	tar zxvf "${glider_name}.tar.gz"
	[[ ! -e "/usr/local/${glider_name}" ]] && echo -e "${Error} glider 解压失败 !" && rm -rf "${glider_name}.tar.gz" && exit 1
	rm -rf "${glider_name}.tar.gz"
	mv "/usr/local/${glider_name}" "${Folder}"
	[[ ! -e "${Folder}" ]] && echo -e "${Error} glider 文件夹重命名失败 !" && rm -rf "${glider_name}.tar.gz" && rm -rf "/usr/local/${glider_name}" && exit 1
	rm -rf "${glider_name}.tar.gz"
	cd "${Folder}"
	chmod +x glider
	cp glider /usr/bin/glider
	mkdir -p ${Config_folder}
	wget --no-check-certificate https://raw.githubusercontent.com/ooxoop/glider-install/master/glider.conf.example -O ${Config_folder}/glider.conf
	echo -e "${Info} glider 主程序安装完毕！开始配置服务文件..."
}

service_glider(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ooxoop/glider-install/master/glider_centos.service -O /etc/init.d/glider; then
			echo -e "${Error} glider服务 管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/glider
		chkconfig --add glider
		chkconfig glider on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ooxoop/glider-install/master/glider_debian.service -O /etc/init.d/glider; then
			echo -e "${Error} glider服务 管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/glider
		update-rc.d -f glider defaults
	fi
	echo -e "${Info} glider服务 管理脚本安装完毕 !"
}

config_ss(){
	local config_name=$1
	[[ -z "${config_name}" ]] && config_name="glider"
	
	Set_config_port
	Set_config_password
	Set_config_method
	ss_link="ss://${ss_method}:${ss_password}@:${port}"
	
	local config_path="${Config_folder}/${config_name}.conf"
	[[ -e "${config_path}" ]] && rm -rf "${config_path}"
	
	echo -e "verbose=True\nlisten=${ss_link}" >> "${config_path}"
	echo -e "${Info} 配置文件 ${config_name}.conf 已创建！"
}

Set_config_port(){
	while true
	do
	echo -e "请输入要设置的 端口"
	read -e -p "(默认: 9999):" port
	[[ -z "$port" ]] && port="9999"
	echo $((${port}+0)) &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${port} -ge 1 ]] && [[ ${port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	端口 : ${Green_font_prefix}${port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} 请输入正确的数字(1-65535)"
		fi
	else
		echo -e "${Error} 请输入正确的数字(1-65535)"
	fi
	done
}

Set_config_password(){
	echo "请输入要设置的Shadowsocks账号 密码"
	read -e -p "(默认: somebody):" ss_password
	[[ -z "${ss_password}" ]] && ss_password="somebody"
	echo && echo ${Separator_1} && echo -e "	密码 : ${Green_font_prefix}${ss_password}${Font_color_suffix}" && echo ${Separator_1} && echo
}

Set_config_method(){
	echo -e "请选择要设置的Shadowsocks账号 加密方式
	
${Green_font_prefix}1.${Font_color_suffix} RC4-MD5

${Green_font_prefix}2.${Font_color_suffix} AES-128-GCM
${Green_font_prefix}3.${Font_color_suffix} AES-192-GCM
${Green_font_prefix}4.${Font_color_suffix} AES-256-GCM

${Green_font_prefix}5.${Font_color_suffix} CHACHA20
${Green_font_prefix}6.${Font_color_suffix} CHACHA20-IETF
${Green_font_prefix}7.${Font_color_suffix} XCHACHA20

${Green_font_prefix}8.${Font_color_suffix} CHACHA20-IETF-POLY1305
${Green_font_prefix}9.${Font_color_suffix} XCHACHA20-IETF-POLY1305
${Tip} CHACHA20-*系列加密方式，需要额外安装依赖 libsodium ，否则会无法启动glider !" && echo
	read -e -p "(默认: 6. CHACHA20-IETF):" ss_method
	[[ -z "${ss_method}" ]] && ss_method="6"
	if [[ ${ss_method} == "1" ]]; then
		ss_method="RC4-MD5"
	elif [[ ${ss_method} == "2" ]]; then
		ss_method="AEAD_AES_128_GCM"
	elif [[ ${ss_method} == "3" ]]; then
		ss_method="AEAD_AES_192_GCM"
	elif [[ ${ss_method} == "4" ]]; then
		ss_method="AEAD_AES_256_GCM"
	elif [[ ${ss_method} == "5" ]]; then
		ss_method="CHACHA20"
	elif [[ ${ss_method} == "6" ]]; then
		ss_method="CHACHA20-IETF"
	elif [[ ${ss_method} == "7" ]]; then
		ss_method="XCHACHA20"
	elif [[ ${ss_method} == "8" ]]; then
		ss_method="AEAD_CHACHA20_IETF_POLY1305"
	elif [[ ${ss_method} == "9" ]]; then
		ss_method="AEAD_XCHACHA20_IETF_POLY1305"
	else
		ss_method="CHACHA20-IETF"
	fi
	echo && echo ${Separator_1} && echo -e "	加密 : ${Green_font_prefix}${ss_method}${Font_color_suffix}" && echo ${Separator_1} && echo
}

View_config(){
	local config_name=$1
	[[ -z "${config_name}" ]] && config_name="glider"
	
	local config_path="${Config_folder}/${config_name}.conf"
	if [[ ! -e "${config_path}" ]]; then
		echo -e "${Error} 配置文件 ${config_name}.conf 不存在！"
		return
	fi
	
	echo -e "配置文件 ${config_name}.conf 内容如下："
	listen=`cat "${config_path}" | grep -v '#' | grep "listen=" | awk -F "=" '{print $NF}'`
	if [[ "${listen}" != "" ]]; then
		echo -e "当前监听端口的协议是： 
${Green_font_prefix}${listen}${Font_color_suffix}"
	else
		echo "读取不到配置信息，请检查配置文件"
	fi
	forward=`cat "${config_path}" | grep -v '#' | grep "forward=" | awk -F "=" '{print $NF}'`
	if [[ "${forward}" != "" ]]; then
		echo -e "监听接收的数据将转发到： 
${Green_font_prefix}${forward}${Font_color_suffix}"
	fi
}

List_instances(){
	echo -e "${Info} 当前所有实例："
	ls -1 ${Config_folder}/*.conf 2>/dev/null | while read config_path; do
		config_name=$(basename ${config_path} .conf)
		check_instance_pid ${config_name}
		if [[ ! -z "${INSTANCE_PID}" ]]; then
			echo -e "${Green_font_prefix}${config_name}${Font_color_suffix} [${Green_font_prefix}运行中${Font_color_suffix}] - PID: ${INSTANCE_PID}"
		else
			echo -e "${Green_font_prefix}${config_name}${Font_color_suffix} [${Red_font_prefix}未运行${Font_color_suffix}]"
		fi
	done
	
	if [[ ! -e "${Config_folder}/"*.conf ]]; then
		echo -e "${Error} 未找到任何实例配置文件！"
	fi
}

Create_instance(){
	echo -e "${Info} 创建新的glider实例"
	read -e -p "请输入实例名称 (默认: glider_new):" instance_name
	[[ -z "${instance_name}" ]] && instance_name="glider_new"
	
	if [[ -e "${Config_folder}/${instance_name}.conf" ]]; then
		echo -e "${Error} 实例 ${instance_name} 已存在！"
		read -e -p "是否覆盖? [Y/n]:" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Nn] ]]; then
			echo "已取消..."
			return
		fi
	fi
	
	config_ss ${instance_name}
	echo -e "${Info} 实例 ${instance_name} 创建完成！"
}

Delete_instance(){
	List_instances
	echo
	read -e -p "请输入要删除的实例名称:" instance_name
	[[ -z "${instance_name}" ]] && echo "已取消..." && return
	
	if [[ ! -e "${Config_folder}/${instance_name}.conf" ]]; then
		echo -e "${Error} 实例 ${instance_name} 不存在！"
		return
	fi
	
	check_instance_pid ${instance_name}
	if [[ ! -z "${INSTANCE_PID}" ]]; then
		echo -e "${Info} 停止实例 ${instance_name}..."
		kill -9 ${INSTANCE_PID}
	fi
	
	rm -f "${Config_folder}/${instance_name}.conf"
	echo -e "${Info} 实例 ${instance_name} 已删除！"
}

Start_instance(){
	List_instances
	echo
	read -e -p "请输入要启动的实例名称:" instance_name
	[[ -z "${instance_name}" ]] && echo "已取消..." && return
	
	if [[ ! -e "${Config_folder}/${instance_name}.conf" ]]; then
		echo -e "${Error} 实例 ${instance_name} 不存在！"
		return
	fi
	
	check_instance_pid ${instance_name}
	if [[ ! -z "${INSTANCE_PID}" ]]; then
		echo -e "${Error} 实例 ${instance_name} 已在运行！"
		return
	fi
	
	echo -e "${Info} 启动实例 ${instance_name}..."
	glider -config "${Config_folder}/${instance_name}.conf" > "${Config_folder}/${instance_name}.log" 2>&1 &
	sleep 2
	check_instance_pid ${instance_name}
	if [[ ! -z "${INSTANCE_PID}" ]]; then
		echo -e "${Info} 实例 ${instance_name} 已启动！"
		View_config ${instance_name}
	else
		echo -e "${Error} 实例 ${instance_name} 启动失败！请查看日志文件 ${Config_folder}/${instance_name}.log"
	fi
}

Stop_instance(){
	List_instances
	echo
	read -e -p "请输入要停止的实例名称:" instance_name
	[[ -z "${instance_name}" ]] && echo "已取消..." && return
	
	if [[ ! -e "${Config_folder}/${instance_name}.conf" ]]; then
		echo -e "${Error} 实例 ${instance_name} 不存在！"
		return
	fi
	
	check_instance_pid ${instance_name}
	if [[ -z "${INSTANCE_PID}" ]]; then
		echo -e "${Error} 实例 ${instance_name} 未在运行！"
		return
	fi
	
	echo -e "${Info} 停止实例 ${instance_name}..."
	kill -9 ${INSTANCE_PID}
	echo -e "${Info} 实例 ${instance_name} 已停止！"
}

View_instance_log(){
	List_instances
	echo
	read -e -p "请输入要查看日志的实例名称:" instance_name
	[[ -z "${instance_name}" ]] && echo "已取消..." && return
	
	if [[ ! -e "${Config_folder}/${instance_name}.conf" ]]; then
		echo -e "${Error} 实例 ${instance_name} 不存在！"
		return
	fi
	
	if [[ ! -e "${Config_folder}/${instance_name}.log" ]]; then
		echo -e "${Error} 实例 ${instance_name} 的日志文件不存在！"
		return
	fi
	
	cat "${Config_folder}/${instance_name}.log"
}

Edit_instance_config(){
	List_instances
	echo
	read -e -p "请输入要编辑配置的实例名称:" instance_name
	[[ -z "${instance_name}" ]] && echo "已取消..." && return
	
	if [[ ! -e "${Config_folder}/${instance_name}.conf" ]]; then
		echo -e "${Error} 实例 ${instance_name} 不存在！"
		return
	fi
	
	vi "${Config_folder}/${instance_name}.conf"
	echo -e "${Info} 配置文件已编辑，是否重启实例？[Y/n]"
	read -e -p ":" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		check_instance_pid ${instance_name}
		if [[ ! -z "${INSTANCE_PID}" ]]; then
			kill -9 ${INSTANCE_PID}
			sleep 1
		fi
		echo -e "${Info} 重启实例 ${instance_name}..."
		glider -config "${Config_folder}/${instance_name}.conf" > "${Config_folder}/${instance_name}.log" 2>&1 &
		sleep 2
		check_instance_pid ${instance_name}
		if [[ ! -z "${INSTANCE_PID}" ]]; then
			echo -e "${Info} 实例 ${instance_name} 已重启！"
			View_config ${instance_name}
		else
			echo -e "${Error} 实例 ${instance_name} 重启失败！请查看日志文件 ${Config_folder}/${instance_name}.log"
		fi
	fi
}

Install_glider(){
	check_sys
	check_new_ver
	download_glider
	service_glider
	echo -e "glider 已安装完成！请重新运行脚本进行配置~"
}

Start_glider(){
	check_install_status "check_conf"
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} glider 正在运行，请检查 !" && exit 1
	/etc/init.d/glider start
	View_config
}

Stop_glider(){
	check_install_status "check_conf"
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} glider 没有运行，请检查 !" && exit 1
	/etc/init.d/glider stop
}

Restart_glider(){
	check_install_status "check_conf"
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/glider stop
	/etc/init.d/glider start
	View_config
}

Manage_instances(){
	echo && echo -e " glider 多实例管理
————————————
${Green_font_prefix} 1.${Font_color_suffix} 查看所有实例
${Green_font_prefix} 2.${Font_color_suffix} 创建新实例
${Green_font_prefix} 3.${Font_color_suffix} 启动实例
${Green_font_prefix} 4.${Font_color_suffix} 停止实例
${Green_font_prefix} 5.${Font_color_suffix} 删除实例
${Green_font_prefix} 6.${Font_color_suffix} 编辑实例配置
${Green_font_prefix} 7.${Font_color_suffix} 查看实例日志
————————————" && echo
	read -e -p " 请输入数字 [1-7]:" instances_num
	case "$instances_num" in
		1)
		List_instances
		;;
		2)
		Create_instance
		;;
		3)
		Start_instance
		;;
		4)
		Stop_instance
		;;
		5)
		Delete_instance
		;;
		6)
		Edit_instance_config
		;;
		7)
		View_instance_log
		;;
		*)
		echo "请输入正确数字 [1-7]"
		;;
	esac
}

echo && echo -e " glider 一键安装管理脚本beta ${Red_font_prefix}[v1.1.0]${Font_color_suffix}
 -- ooxoop | lajiblog.com --

${Green_font_prefix} 1.${Font_color_suffix} 安装 glider
————————————
${Green_font_prefix} 2.${Font_color_suffix} 启动 glider
${Green_font_prefix} 3.${Font_color_suffix} 停止 glider
${Green_font_prefix} 4.${Font_color_suffix} 重启 glider
————————————
${Green_font_prefix} 5.${Font_color_suffix} 查看 当前配置
${Green_font_prefix} 6.${Font_color_suffix} 设置 配置文件
${Green_font_prefix} 7.${Font_color_suffix} 打开 配置文件
${Green_font_prefix} 8.${Font_color_suffix} 查看 日志文件
————————————
${Green_font_prefix} 9.${Font_color_suffix} 管理 多实例
————————————" && echo
if [[ -e "/usr/bin/glider" ]]; then
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
	fi
else
	echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo
read -e -p " 请输入数字 [0-9]:" num
case "$num" in
	1)
	Install_glider
	;;
	2)
	Start_glider
	;;
	3)
	Stop_glider
	;;
	4)
	Restart_glider
	;;
	5)
	View_config
	;;
	6)
	Set_config
	;;
	7)
	vi ${Config_folder}/glider.conf
	Restart_glider
	;;
	8)
	cat ${Config_folder}/glider.log
	;;
	9)
	Manage_instances
	;;
	*)
	echo "请输入正确数字 [0-9]"
	;;
esac


