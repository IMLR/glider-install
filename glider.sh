#!/usr/bin/env bash

Folder="/usr/local/glider"
Config_folder="/root/.glider"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
Monitor="${Green_font_prefix}[监控]${Font_color_suffix}"
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

List_instances_with_number(){
	echo -e "${Info} 当前所有实例："
	local i=1
	instance_array=()
	while read -r config_path; do
		config_name=$(basename ${config_path} .conf)
		instance_array[${i}]=${config_name}
		check_instance_pid ${config_name}
		if [[ ! -z "${INSTANCE_PID}" ]]; then
			echo -e "${Green_font_prefix}${i}.${Font_color_suffix} ${Green_font_prefix}${config_name}${Font_color_suffix} [${Green_font_prefix}运行中${Font_color_suffix}] - PID: ${INSTANCE_PID}"
		else
			echo -e "${Green_font_prefix}${i}.${Font_color_suffix} ${Green_font_prefix}${config_name}${Font_color_suffix} [${Red_font_prefix}未运行${Font_color_suffix}]"
		fi
		let i++
	done < <(ls -1 ${Config_folder}/*.conf 2>/dev/null)
	
	instance_count=$((i-1))
	if [ ${instance_count} -eq 0 ]; then
		echo -e "${Error} 未找到任何实例配置文件！"
		return 1
	fi
	return 0
}

Start_instance(){
	List_instances_with_number
	if [ $? -ne 0 ]; then
		return
	fi
	
	echo -e "${Green_font_prefix}0.${Font_color_suffix} 启动全部实例"
	echo
	read -e -p "请输入实例编号 [0-${instance_count}]:" instance_num
	
	if [[ -z "${instance_num}" ]]; then
		echo "已取消..." && return
	fi
	
	if [[ "${instance_num}" == "0" ]]; then
		echo -e "${Info} 正在启动全部实例..."
		for ((i=1; i<=${instance_count}; i++)); do
			instance_name=${instance_array[${i}]}
			check_instance_pid ${instance_name}
			if [[ -z "${INSTANCE_PID}" ]]; then
				echo -e "${Info} 启动实例 ${instance_name}..."
				glider -config "${Config_folder}/${instance_name}.conf" > "${Config_folder}/${instance_name}.log" 2>&1 &
				sleep 1
			else
				echo -e "${Info} 实例 ${instance_name} 已在运行中，跳过..."
			fi
		done
		echo -e "${Info} 全部实例启动完成！"
		return
	fi
	
	if ! [[ "${instance_num}" =~ ^[0-9]+$ ]] || [ ${instance_num} -lt 1 ] || [ ${instance_num} -gt ${instance_count} ]; then
		echo -e "${Error} 请输入正确的实例编号 [0-${instance_count}]"
		return
	fi
	
	instance_name=${instance_array[${instance_num}]}
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
	List_instances_with_number
	if [ $? -ne 0 ]; then
		return
	fi
	
	echo -e "${Green_font_prefix}0.${Font_color_suffix} 停止全部实例"
	echo
	read -e -p "请输入实例编号 [0-${instance_count}]:" instance_num
	
	if [[ -z "${instance_num}" ]]; then
		echo "已取消..." && return
	fi
	
	if [[ "${instance_num}" == "0" ]]; then
		echo -e "${Info} 正在停止全部实例..."
		for ((i=1; i<=${instance_count}; i++)); do
			instance_name=${instance_array[${i}]}
			check_instance_pid ${instance_name}
			if [[ ! -z "${INSTANCE_PID}" ]]; then
				echo -e "${Info} 停止实例 ${instance_name}..."
				kill -9 ${INSTANCE_PID}
				sleep 1
			else
				echo -e "${Info} 实例 ${instance_name} 未在运行，跳过..."
			fi
		done
		echo -e "${Info} 全部实例已停止！"
		return
	fi
	
	if ! [[ "${instance_num}" =~ ^[0-9]+$ ]] || [ ${instance_num} -lt 1 ] || [ ${instance_num} -gt ${instance_count} ]; then
		echo -e "${Error} 请输入正确的实例编号 [0-${instance_count}]"
		return
	fi
	
	instance_name=${instance_array[${instance_num}]}
	check_instance_pid ${instance_name}
	if [[ -z "${INSTANCE_PID}" ]]; then
		echo -e "${Error} 实例 ${instance_name} 未在运行！"
		return
	fi
	
	echo -e "${Info} 停止实例 ${instance_name}..."
	kill -9 ${INSTANCE_PID}
	echo -e "${Info} 实例 ${instance_name} 已停止！"
}

List_instances(){
	echo -e "${Info} 当前所有实例："
	found_instances=0
	ls -1 ${Config_folder}/*.conf 2>/dev/null | while read config_path; do
		found_instances=1
		config_name=$(basename ${config_path} .conf)
		check_instance_pid ${config_name}
		if [[ ! -z "${INSTANCE_PID}" ]]; then
			echo -e "${Green_font_prefix}${config_name}${Font_color_suffix} [${Green_font_prefix}运行中${Font_color_suffix}] - PID: ${INSTANCE_PID}"
		else
			echo -e "${Green_font_prefix}${config_name}${Font_color_suffix} [${Red_font_prefix}未运行${Font_color_suffix}]"
		fi
	done
	
	# 更可靠的检测方法：使用计数变量
	if [ $(ls -1 ${Config_folder}/*.conf 2>/dev/null | wc -l) -eq 0 ]; then
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

Restart_instance(){
	List_instances_with_number
	if [ $? -ne 0 ]; then
		return
	fi
	
	echo -e "${Green_font_prefix}0.${Font_color_suffix} 重启全部实例"
	echo
	read -e -p "请输入实例编号 [0-${instance_count}]:" instance_num
	
	if [[ -z "${instance_num}" ]]; then
		echo "已取消..." && return
	fi
	
	if [[ "${instance_num}" == "0" ]]; then
		echo -e "${Info} 正在重启全部实例..."
		for ((i=1; i<=${instance_count}; i++)); do
			instance_name=${instance_array[${i}]}
			check_instance_pid ${instance_name}
			if [[ ! -z "${INSTANCE_PID}" ]]; then
				echo -e "${Info} 停止实例 ${instance_name}..."
				kill -9 ${INSTANCE_PID}
				sleep 1
			fi
			echo -e "${Info} 启动实例 ${instance_name}..."
			glider -config "${Config_folder}/${instance_name}.conf" > "${Config_folder}/${instance_name}.log" 2>&1 &
			sleep 1
		done
		echo -e "${Info} 全部实例重启完成！"
		return
	fi
	
	if ! [[ "${instance_num}" =~ ^[0-9]+$ ]] || [ ${instance_num} -lt 1 ] || [ ${instance_num} -gt ${instance_count} ]; then
		echo -e "${Error} 请输入正确的实例编号 [0-${instance_count}]"
		return
	fi
	
	instance_name=${instance_array[${instance_num}]}
	check_instance_pid ${instance_name}
	if [[ ! -z "${INSTANCE_PID}" ]]; then
		echo -e "${Info} 停止实例 ${instance_name}..."
		kill -9 ${INSTANCE_PID}
		sleep 1
	else
		echo -e "${Info} 实例 ${instance_name} 未在运行，将直接启动..."
	fi
	
	echo -e "${Info} 启动实例 ${instance_name}..."
	glider -config "${Config_folder}/${instance_name}.conf" > "${Config_folder}/${instance_name}.log" 2>&1 &
	sleep 2
	check_instance_pid ${instance_name}
	if [[ ! -z "${INSTANCE_PID}" ]]; then
		echo -e "${Info} 实例 ${instance_name} 已重启！"
		View_config ${instance_name}
	else
		echo -e "${Error} 实例 ${instance_name} 启动失败！请查看日志文件 ${Config_folder}/${instance_name}.log"
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

# 监控功能：检查实例日志并自动更新问题实例
monitor_instances() {
    local monitor_log="${Config_folder}/monitor.log"
    local any_issues=false
    
    # 获取所有配置文件
    local conf_files=$(find "${Config_folder}" -name "*.conf")
    if [[ -z "${conf_files}" ]]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] 未找到任何实例配置文件" >> "${monitor_log}"
        return
    fi
    
    # 首先检查实例运行状态并启动未运行的实例
    local running_count=0
    local not_running_count=0
    local instance_array=()
    local not_running_instances=()
    
    for conf_file in ${conf_files}; do
        local instance_name=$(basename "${conf_file}" .conf)
        instance_array+=("${instance_name}")
        
        # 检查实例是否在运行
        check_instance_pid "${instance_name}"
        if [[ -z "${INSTANCE_PID}" ]]; then
            not_running_instances+=("${instance_name}")
            ((not_running_count++))
        else
            ((running_count++))
        fi
    done
    
    # 只有在发现未运行实例时才记录日志
    if [[ ${not_running_count} -gt 0 ]]; then
        any_issues=true
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] 发现 ${not_running_count} 个未运行的实例: ${not_running_instances[*]}" >> "${monitor_log}"
        
        # 如果所有实例都未运行，启动所有实例
        if [[ ${running_count} -eq 0 ]]; then
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 所有实例都未运行，启动所有实例..." >> "${monitor_log}"
            for instance_name in "${instance_array[@]}"; do
                local config_path="${Config_folder}/${instance_name}.conf"
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] 启动实例 ${instance_name}..." >> "${monitor_log}"
                glider -config "${config_path}" > "${Config_folder}/${instance_name}.log" 2>&1 &
                sleep 2
                check_instance_pid "${instance_name}"
                if [[ ! -z "${INSTANCE_PID}" ]]; then
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 实例 ${instance_name} 启动成功 (PID: ${INSTANCE_PID})" >> "${monitor_log}"
                else
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 实例 ${instance_name} 启动失败" >> "${monitor_log}"
                fi
            done
        # 如果部分实例未运行，只启动那些未运行的实例
        else
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 开始启动未运行的实例..." >> "${monitor_log}"
            for instance_name in "${not_running_instances[@]}"; do
                local config_path="${Config_folder}/${instance_name}.conf"
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] 启动实例 ${instance_name}..." >> "${monitor_log}"
                glider -config "${config_path}" > "${Config_folder}/${instance_name}.log" 2>&1 &
                sleep 2
                check_instance_pid "${instance_name}"
                if [[ ! -z "${INSTANCE_PID}" ]]; then
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 实例 ${instance_name} 启动成功 (PID: ${INSTANCE_PID})" >> "${monitor_log}"
                else
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 实例 ${instance_name} 启动失败" >> "${monitor_log}"
                fi
            done
        fi
    fi
    
    # 健康检查逻辑 - 只记录异常情况
    # 遍历每个配置文件进行健康检查
    for conf_file in ${conf_files}; do
        local instance_name=$(basename "${conf_file}" .conf)
        local log_file="${Config_folder}/${instance_name}.log"
        
        # 检查日志文件是否存在
        if [[ ! -e "${log_file}" ]]; then
            any_issues=true
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 警告: 实例 ${instance_name} 的日志文件不存在" >> "${monitor_log}"
            continue
        fi
        
        # 获取日志的最后100行
        local recent_logs=$(tail -n 100 "${log_file}")
        if [[ -z "${recent_logs}" ]]; then
            any_issues=true
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 警告: 实例 ${instance_name} 的日志为空" >> "${monitor_log}"
            continue
        fi
        
        # 解析检查结果
        local fail_count=0
        local fail_ips=()
        
        while read -r line; do
            if [[ "${line}" == *"[check]"* && "${line}" != *"SUCCESS"* ]]; then
                # 提取IP地址和端口
                local ip_port=$(echo "${line}" | grep -oE "main: [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+" | sed 's/main: //')
                if [[ -n "${ip_port}" ]]; then
                    # 检查是否已计入此IP
                    local is_duplicate=0
                    for ip in "${fail_ips[@]}"; do
                        if [[ "${ip}" == "${ip_port}" ]]; then
                            is_duplicate=1
                            break
                        fi
                    done
                    
                    if [[ ${is_duplicate} -eq 0 ]]; then
                        fail_ips+=("${ip_port}")
                        ((fail_count++))
                    fi
                fi
            fi
        done <<< "${recent_logs}"
        
        # 如果失败数量超过阈值，触发更新
        if [[ ${fail_count} -ge 3 ]]; then
            any_issues=true
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 警告: 实例 ${instance_name} 检测到 ${fail_count} 个不同IP的失败: ${fail_ips[*]}" >> "${monitor_log}"
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] 开始自动更新实例 ${instance_name}..." >> "${monitor_log}"
            
            # 调用更新函数
            if _update_single_instance "${instance_name}" "auto"; then
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] 实例 ${instance_name} 自动更新成功" >> "${monitor_log}"
            else
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] 实例 ${instance_name} 自动更新失败" >> "${monitor_log}"
            fi
        fi
    done
    
    # 只有在发现问题时才记录完成信息
    if [[ "${any_issues}" == "true" ]]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] 监控检查完成，发现并处理了问题" >> "${monitor_log}"
    fi
}

# 更新单个实例的辅助函数，添加自动更新标记
_update_single_instance() {
    local instance_name=$1
    local config_path="${Config_folder}/${instance_name}.conf"
    
    # 检查配置文件是否存在
    if [[ ! -f "${config_path}" ]]; then
        echo -e "${Error} 配置文件 ${instance_name}.conf 不存在!"
        return 1
    fi
    
    # 从配置文件中提取订阅链接
    local subscription_url=$(grep -E "^# (http|https)://" "${config_path}" | head -n 1 | sed 's/^# //')
    
    if [[ -z "${subscription_url}" ]]; then
        echo -e "${Error} 配置文件 ${instance_name}.conf 中未找到订阅链接!"
        return 1
    fi
    
    echo -e "${Info} 正在获取订阅内容..."
    local subscription_content=$(curl -s "${subscription_url}")
    if [[ -z "${subscription_content}" ]]; then
        echo -e "${Error} 获取订阅内容失败，请检查链接是否正确!"
        return 1
    fi
    
    echo -e "${Info} 正在解码订阅内容..."
    local decoded_content=$(echo "${subscription_content}" | base64 -d 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo -e "${Error} 解码失败，可能不是有效的base64内容!"
        return 1
    fi
    
    # 获取现有配置文件的头部
    local config_header=$(awk '/^forward=/{exit} {print}' "${config_path}")
    
    # 获取当前配置的监听端口
    local listen_port=$(grep -E "^listen=:" "${config_path}" | sed -E 's/^listen=:([0-9]+).*$/\1/')
    if [[ -z "${listen_port}" ]]; then
        echo -e "${Error} 在配置文件中未找到有效的监听端口!"
        return 1
    fi
    
    echo -e "${Info} 正在解析服务器信息..."
    IFS=$'\n'
    local config_lines=()
    
    # 将头部配置添加到数组中
    while IFS= read -r line; do
        config_lines+=("$line")
    done <<< "$config_header"
    
    # 将内容按行拆分到数组中
    local link_array
    readarray -t link_array <<< "$decoded_content"
    
    # 计数有效链接数量，最多保留5个
    local valid_links=0
    local max_links=5
    
    for line in "${link_array[@]}"; do
        # 如果已经有5个有效链接，跳出循环
        if [[ ${valid_links} -ge ${max_links} ]]; then
            echo -e "${Info} 已达到最大链接数量限制(${max_links})，忽略剩余链接"
            break
        fi
        
        if [[ "${line}" == ss://* ]]; then
            # 处理SS链接
            local ss_full=${line}
            # 移除ss://前缀
            local ss_b64=${ss_full#ss://}
            # 分离标签部分
            local ss_b64=${ss_b64%%#*}
            # 解码base64
            local ss_decoded=$(echo "${ss_b64}" | base64 -d 2>/dev/null)
            
            if [[ "${ss_decoded}" == *:*@*:* ]]; then
                # 已经是解码后的格式 method:password@server:port
                config_lines+=("forward=ss://${ss_decoded}")
                ((valid_links++))
            else
                # 处理特殊情况或错误
                echo -e "${Tip} 跳过无法解析的SS链接: ${ss_full}"
            fi
        elif [[ "${line}" == vmess://* ]]; then
            # 处理VMESS链接
            local vmess_full=${line}
            # 移除vmess://前缀
            local vmess_b64=${vmess_full#vmess://}
            # 解码base64
            local vmess_json=$(echo "${vmess_b64}" | base64 -d 2>/dev/null)
            
            # 提取服务器信息
            local vmess_server=$(echo "${vmess_json}" | sed -n 's/.*"add"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            local vmess_port=$(echo "${vmess_json}" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            local vmess_uuid=$(echo "${vmess_json}" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            
            if [[ -n "${vmess_server}" && -n "${vmess_port}" && -n "${vmess_uuid}" ]]; then
                config_lines+=("forward=vmess://aes-128-gcm:${vmess_uuid}@${vmess_server}:${vmess_port}")
                ((valid_links++))
            else
                echo -e "${Tip} 跳过无法解析的VMESS链接: ${vmess_full}"
            fi
        fi
    done
    
    # 检查是否有解析的服务器
    local forward_count=0
    for line in "${config_lines[@]}"; do
        if [[ "${line}" == forward=* ]]; then
            ((forward_count++))
        fi
    done
    
    if [[ ${forward_count} -eq 0 ]]; then
        echo -e "${Error} 没有找到可用的服务器信息!"
        return 1
    fi
    
    echo -e "${Info} 已解析并保留 ${valid_links} 个服务器（最多保留${max_links}个）"
    
    # 备份当前配置文件
    cp "${config_path}" "${config_path}.bak"
    
    # 写入配置文件
    > "${config_path}"
    # 在第一行添加订阅链接作为注释
    echo "# ${subscription_url}" >> "${config_path}"
    # 添加更新时间
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    echo "# 更新时间: ${current_time}" >> "${config_path}"
    for line in "${config_lines[@]}"; do
        echo "${line}" >> "${config_path}"
    done
    
    echo -e "${Info} 配置文件 ${instance_name}.conf 已更新!"
    
    # 重启实例
    check_instance_pid ${instance_name}
    if [[ ! -z "${INSTANCE_PID}" ]]; then
        echo -e "${Info} 重启实例 ${instance_name}..."
        kill -9 ${INSTANCE_PID}
        sleep 1
    else
        echo -e "${Info} 启动实例 ${instance_name}..."
    fi
    
    glider -config "${config_path}" > "${Config_folder}/${instance_name}.log" 2>&1 &
    sleep 2
    check_instance_pid ${instance_name}
    if [[ ! -z "${INSTANCE_PID}" ]]; then
        echo -e "${Info} 实例 ${instance_name} 已重启，监听端口为 ${listen_port}!"
    else
        echo -e "${Error} 实例 ${instance_name} 启动失败! 请查看日志文件 ${Config_folder}/${instance_name}.log"
        # 恢复备份
        echo -e "${Info} 恢复配置文件..."
        mv "${config_path}.bak" "${config_path}"
    fi
    
    return 0
}

# 查看监控日志的函数
View_monitor_log(){
	local monitor_log="${Config_folder}/monitor.log"
	if [[ ! -e "${monitor_log}" ]]; then
		echo -e "${Error} 监控日志不存在，可能从未进行过监控!"
		return
	fi
	
	echo -e "${Info} 监控日志:"
	cat "${monitor_log}"
}

# 处理命令行参数，在主函数之前
if [[ "$1" == "monitor" ]]; then
    # 监控模式，直接执行监控功能
    monitor_instances
    exit 0
fi

Manage_instances(){
	echo && echo -e " glider 多实例管理
————————————
${Green_font_prefix} 1.${Font_color_suffix} 查看所有实例
${Green_font_prefix} 2.${Font_color_suffix} 创建新实例
${Green_font_prefix} 3.${Font_color_suffix} 启动实例
${Green_font_prefix} 4.${Font_color_suffix} 停止实例
${Green_font_prefix} 5.${Font_color_suffix} 重启实例
${Green_font_prefix} 6.${Font_color_suffix} 删除实例
${Green_font_prefix} 7.${Font_color_suffix} 编辑实例配置
${Green_font_prefix} 8.${Font_color_suffix} 查看实例日志
${Green_font_prefix} 9.${Font_color_suffix} 查看更新历史
${Green_font_prefix}10.${Font_color_suffix} 查看监控日志
————————————" && echo
	read -e -p " 请输入数字 [1-10]:" instances_num
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
		Restart_instance
		;;
		6)
		Delete_instance
		;;
		7)
		Edit_instance_config
		;;
		8)
		View_instance_log
		;;
		9)
		View_update_history
		;;
		10)
		View_monitor_log
		;;
		*)
		echo "请输入正确数字 [1-10]"
		;;
	esac
}

Manage_legacy(){
	echo && echo -e " glider 单实例管理
————————————
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
————————————" && echo
	read -e -p " 请输入数字 [1-8]:" legacy_num
	case "$legacy_num" in
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
		*)
		echo "请输入正确数字 [1-8]"
		;;
	esac
}

Parse_subscription(){
	echo -e "${Info} 开始解析订阅链接"
	read -e -p "请输入订阅链接:" subscription_url
	[[ -z "${subscription_url}" ]] && echo "已取消..." && return
	
	echo -e "${Info} 正在获取订阅内容..."
	subscription_content=$(curl -s ${subscription_url})
	if [[ -z "${subscription_content}" ]]; then
		echo -e "${Error} 获取订阅内容失败，请检查链接是否正确!"
		return
	fi
	
	echo -e "${Info} 正在解码订阅内容..."
	decoded_content=$(echo "${subscription_content}" | base64 -d 2>/dev/null)
	if [[ $? -ne 0 ]]; then
		echo -e "${Error} 解码失败，可能不是有效的base64内容!"
		return
	fi
	
	# 设置监听端口
	while true
	do
	echo -e "请输入要设置的本地监听端口"
	read -e -p "(默认: 8392):" listen_port
	[[ -z "$listen_port" ]] && listen_port="8392"
	echo $((${listen_port}+0)) &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${listen_port} -ge 1 ]] && [[ ${listen_port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	监听端口 : ${Green_font_prefix}${listen_port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} 请输入正确的数字(1-65535)"
		fi
	else
		echo -e "${Error} 请输入正确的数字(1-65535)"
	fi
	done
	
	echo -e "${Info} 正在解析服务器信息..."
	IFS=$'\n'
	config_lines=()
	
	# 固定的配置头部
	config_lines+=("verbose=True")
	config_lines+=("listen=:${listen_port}")
	config_lines+=("")
	config_lines+=("strategy=lha")
	config_lines+=("")
	config_lines+=("# strategy=rr")
	config_lines+=("check=http://www.msftconnecttest.com/connecttest.txt#expect=200")
	config_lines+=("checkinterval=60")
	config_lines+=("")
	
	# 将内容按行拆分到数组中
	local link_array
	readarray -t link_array <<< "$decoded_content"
	
	# 计数有效链接数量，最多保留5个
	local valid_links=0
	local max_links=5
	
	for line in "${link_array[@]}"; do
		# 如果已经有5个有效链接，跳出循环
		if [[ ${valid_links} -ge ${max_links} ]]; then
			echo -e "${Info} 已达到最大链接数量限制(${max_links})，忽略剩余链接"
			break
		fi
		
		if [[ "${line}" == ss://* ]]; then
			# 处理SS链接
			ss_full=${line}
			# 移除ss://前缀
			ss_b64=${ss_full#ss://}
			# 分离标签部分
			ss_b64=${ss_b64%%#*}
			# 解码base64
			ss_decoded=$(echo "${ss_b64}" | base64 -d 2>/dev/null)
			
			if [[ "${ss_decoded}" == *:*@*:* ]]; then
				# 已经是解码后的格式 method:password@server:port
				config_lines+=("forward=ss://${ss_decoded}")
				((valid_links++))
			else
				# 处理特殊情况或错误
				echo -e "${Tip} 跳过无法解析的SS链接: ${ss_full}"
			fi
		elif [[ "${line}" == vmess://* ]]; then
			# 处理VMESS链接
			vmess_full=${line}
			# 移除vmess://前缀
			vmess_b64=${vmess_full#vmess://}
			# 解码base64
			vmess_json=$(echo "${vmess_b64}" | base64 -d 2>/dev/null)
			
			# 提取服务器信息 - 使用更可靠的方法
			vmess_server=$(echo "${vmess_json}" | sed -n 's/.*"add"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
			vmess_port=$(echo "${vmess_json}" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
			vmess_uuid=$(echo "${vmess_json}" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
			
			if [[ -n "${vmess_server}" && -n "${vmess_port}" && -n "${vmess_uuid}" ]]; then
				config_lines+=("forward=vmess://aes-128-gcm:${vmess_uuid}@${vmess_server}:${vmess_port}")
				((valid_links++))
				echo -e "${Info} 成功添加VMESS链接"
			else
				echo -e "${Tip} 跳过无法解析的VMESS链接: ${vmess_full}"
			fi
		fi
	done
	
	# 检查是否有解析的服务器
	if [[ ${valid_links} -eq 0 ]]; then
		echo -e "${Error} 没有找到可用的服务器信息!"
		return
	fi
	
	echo -e "${Info} 已解析并保留 ${valid_links} 个服务器（最多保留${max_links}个）"
	
	read -e -p "请输入配置名称 (默认: subscription):" config_name
	[[ -z "${config_name}" ]] && config_name="subscription"
	
	config_path="${Config_folder}/${config_name}.conf"
	if [[ -e "${config_path}" ]]; then
		echo -e "${Tip} 配置文件 ${config_name}.conf 已存在!"
		read -e -p "是否覆盖? [Y/n]:" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Nn] ]]; then
			echo "已取消..."
			return
		fi
	fi
	
	# 写入配置文件
	> "${config_path}"
	# 在第一行添加订阅链接作为注释，简化格式
	echo "# ${subscription_url}" >> "${config_path}"
	# 添加更新时间
	current_time=$(date "+%Y-%m-%d %H:%M:%S")
	echo "# 更新时间: ${current_time}" >> "${config_path}"
	for line in "${config_lines[@]}"; do
		echo "${line}" >> "${config_path}"
	done
	
	echo -e "${Info} 配置文件 ${config_name}.conf 已创建!"
	echo -e "${Tip} 你现在可以启动此配置了，监听端口为 ${listen_port}"
	read -e -p "是否立即启动? [Y/n]:" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		check_instance_pid ${config_name}
		if [[ ! -z "${INSTANCE_PID}" ]]; then
			echo -e "${Info} 停止实例 ${config_name}..."
			kill -9 ${INSTANCE_PID}
			sleep 1
		fi
		echo -e "${Info} 启动实例 ${config_name}..."
		glider -config "${config_path}" > "${Config_folder}/${config_name}.log" 2>&1 &
		sleep 2
		check_instance_pid ${config_name}
		if [[ ! -z "${INSTANCE_PID}" ]]; then
			echo -e "${Info} 实例 ${config_name} 已启动，监听端口为 ${listen_port}!"
		else
			echo -e "${Error} 实例 ${config_name} 启动失败! 请查看日志文件 ${Config_folder}/${config_name}.log"
		fi
	fi
}

Update_instance(){
	List_instances_with_number
	if [ $? -ne 0 ]; then
		return
	fi
	
	echo -e "${Green_font_prefix}0.${Font_color_suffix} 更新全部实例"
	echo
	read -e -p "请输入实例编号 [0-${instance_count}]:" instance_num
	
	if [[ -z "${instance_num}" ]]; then
		echo "已取消..." && return
	fi
	
	if [[ "${instance_num}" == "0" ]]; then
		echo -e "${Info} 正在更新全部实例..."
		for ((i=1; i<=${instance_count}; i++)); do
			instance_name=${instance_array[${i}]}
			_update_single_instance ${instance_name}
		done
		echo -e "${Info} 全部实例更新完成！"
		return
	fi
	
	if ! [[ "${instance_num}" =~ ^[0-9]+$ ]] || [ ${instance_num} -lt 1 ] || [ ${instance_num} -gt ${instance_count} ]; then
		echo -e "${Error} 请输入正确的实例编号 [0-${instance_count}]"
		return
	fi
	
	instance_name=${instance_array[${instance_num}]}
	_update_single_instance ${instance_name}
}

# 添加查看更新历史的函数
View_update_history(){
	local update_log="${Config_folder}/update_history.log"
	if [[ ! -e "${update_log}" ]]; then
		echo -e "${Error} 更新历史日志不存在，可能从未进行过更新!"
		return
	fi
	
	echo -e "${Info} 更新历史日志:"
	cat "${update_log}"
}

echo && echo -e " glider 一键安装管理脚本beta ${Red_font_prefix}[v1.2.0]${Font_color_suffix}
 -- ooxoop | lajiblog.com --

${Green_font_prefix} 1.${Font_color_suffix} 查看所有实例
${Green_font_prefix} 2.${Font_color_suffix} 创建新实例
${Green_font_prefix} 3.${Font_color_suffix} 启动实例
${Green_font_prefix} 4.${Font_color_suffix} 停止实例
${Green_font_prefix} 5.${Font_color_suffix} 删除实例
${Green_font_prefix} 6.${Font_color_suffix} 编辑实例配置
${Green_font_prefix} 7.${Font_color_suffix} 查看实例日志
${Green_font_prefix} 8.${Font_color_suffix} 重启实例
${Green_font_prefix} 9.${Font_color_suffix} 从订阅创建配置
${Green_font_prefix}10.${Font_color_suffix} 更新实例配置
${Green_font_prefix}11.${Font_color_suffix} 查看更新历史
${Green_font_prefix}12.${Font_color_suffix} 查看监控日志
————————————
${Green_font_prefix}13.${Font_color_suffix} 安装 glider
${Green_font_prefix}14.${Font_color_suffix} 单实例管理(旧版菜单)
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
echo -e " 提示: 使用 ${Green_font_prefix}bash glider.sh monitor${Font_color_suffix} 执行监控检查"
echo
read -e -p " 请输入数字 [1-14]:" num
case "$num" in
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
	8)
	Restart_instance
	;;
	9)
	Parse_subscription
	;;
	10)
	Update_instance
	;;
	11)
	View_update_history
	;;
	12)
	View_monitor_log
	;;
	13)
	Install_glider
	;;
	14)
	Manage_legacy
	;;
	*)
	echo "请输入正确数字 [1-14]"
	;;
esac


