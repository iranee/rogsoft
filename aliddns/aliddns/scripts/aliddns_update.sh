#!/bin/sh

source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】'
eval $(dbus export aliddns_)
LOG_FILE=/tmp/upload/aliddns_log.txt
LOG_MAX=1000
now=$(echo_date)
[ -z "$aliddns_dns" ] && aliddns_dns="223.5.5.5"
[ -z "$aliddns_ttl" ] && aliddns_ttl="600"

clean_log() {
	[ $(wc -l "$LOG_FILE" | awk '{print $1}') -le "$LOG_MAX" ] && return
	local logdata=$(tail -n 500 "$LOG_FILE")
	echo "$logdata" > $LOG_FILE 2> /dev/null
	unset logdata
	echo_date "[aliddns_update.sh]：日志超过1000条，删除之前995条！"
}

__valid_ip() {
	local format_4=$(echo "$1" | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
	local format_6=$(echo "$1" | grep -Eo '^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*')
	if [ -n "$format_4" ] && [ -z "$format_6" ]; then
		echo "$format_4"
		return 0
	elif [ -z "$format_4" ] && [ -n "$format_6" ]; then
		echo "$format_6"
		return 0
	else
		echo ""
		return 1
	fi
}

start_update() {
	#get resovled ip
	case "$aliddns_name" in
		\*)
			current_ip=$(nslookup koolshare.$aliddns_domain $aliddns_dns 2>&1)
		;;
		\@)
			current_ip=$(nslookup $aliddns_domain $aliddns_dns 2>&1)
		;;
		*)
			current_ip=$(nslookup $aliddns_name.$aliddns_domain $aliddns_dns 2>&1)
		;;
	esac
	current_ip=$(echo "$current_ip" | grep 'Address 1' | tail -n1 | awk '{print $NF}')
	current_ip=$(__valid_ip "$current_ip")
	
	# get public ip
	case "$aliddns_comd" in
		1)
			ip=$(curl -s --interface ppp0 whatismyip.akamai.com 2>&1 | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -v "Terminated")
			# incase user modify
			dbus set aliddns_curl="curl -s --interface ppp0 whatismyip.akamai.com"
		;;
		2)
			ip=$(curl -s --interface ppp0 ip.clang.cn 2>&1 | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -v "Terminated")
			# incase user modify
			dbus set aliddns_curl="curl -s --interface ppp0 ip.clang.cn"
		;;
		3)
			ip=$(curl -s whatismyip.akamai.com 2>&1 | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -v "Terminated")
			# incase user modify
			dbus set aliddns_curl="curl -s whatismyip.akamai.com"
		;;
		4)
			ip=$(curl -s ip.clang.cn 2>&1 | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -v "Terminated")
			# incase user modify
			dbus set aliddns_curl="curl -s ip.clang.cn"
		;;
		5)
			ip=$(nvram get wan0_realip_ip | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
			# incase user modify
			dbus set aliddns_curl="nvram get wan0_realip_ip"
		;;
		6)
			__valid_ip "$aliddns_curl" >/dev/null 2>&1
			if [ "$?" == "0" ]; then
				ip="$aliddns_curl"
				dbus set aliddns_userip="$aliddns_curl"
			else
				ip=$(eval $aliddns_curl 2>&1 | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -v "Terminated")
			fi
		;;
	esac
	ip=$(__valid_ip "$ip")

	# compare ip
	if [ -n "$ip" -a -n "$current_ip" ]; then
		echo_date "[aliddns_update.sh]：公网IP：$ip, 解析IP：$current_ip"
		# no ip change
		if [ "$ip" == "$current_ip" ]; then
			dbus set aliddns_last_act="$now: skipped($ip)"
			echo_date "[aliddns_update.sh]：IP地址无变化，不更新！"
			exit 0
		fi
	elif [ -z "$ip" -a -n "$current_ip" ]; then
		dbus set aliddns_last_act="$now: 失败，原因：无法获取外网IP地址！"
		echo_date "[aliddns_update.sh]：更新失败，原因：获取外网IP地址失败！"		
		exit 0
	elif [ -n "$ip" -a -z "$current_ip" ]; then
		dbus set aliddns_last_act="$now: 失败，原因：解析域名失败！"
		echo_date "[aliddns_update.sh]：更新失败，原因：解析域名失败！"		
		exit 0
	else
		dbus set aliddns_last_act="$now: 失败，原因：解析域名 + 外网IP失败！"
		echo_date "[aliddns_update.sh]：更新失败，原因：解析域名 + 外网IP失败！"		
		exit 0
	fi
	
	timestamp=$(date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ")
	urlencode() {
		# urlencode <string>
		out=""
		while read -n1 c
		do
			case $c in
				[a-zA-Z0-9._-]) out="$out$c" ;;
				*) out="$out$(printf '%%%02X' "'$c")" ;;
			esac
		done
		echo -n $out
	}
	
	enc() {
		echo -n "$1" | urlencode
	}
	
	send_request() {
		local args="AccessKeyId=$aliddns_ak&Action=$1&Format=json&$2&Version=2015-01-09"
		local hash=$(echo -n "GET&%2F&$(enc "$args")" | openssl dgst -sha1 -hmac "$aliddns_sk&" -binary | openssl base64)
		curl -s "http://alidns.aliyuncs.com/?$args&Signature=$(enc "$hash")"
	}
	
	get_recordid() {
		grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"'
	}
	
	query_recordid() {
		send_request "DescribeSubDomainRecords" "SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&SubDomain=$aliddns_name1.$aliddns_domain&Timestamp=$timestamp"
	}
	
	update_record() {
		send_request "UpdateDomainRecord" "RR=$aliddns_name1&RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=A&Value=$ip"
	}
	
	add_record() {
		send_request "AddDomainRecord&DomainName=$aliddns_domain" "RR=$aliddns_name1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=A&Value=$ip"
	}
	
	#add support */%2A and @/%40 record
	case "$aliddns_name" in
		\*)
			aliddns_name1=%2A
		;;
		\@)
			aliddns_name1=%40
		;;
		*)
			aliddns_name1="$aliddns_name"
		;;
	esac
	
	if [ -z "$aliddns_record_id" ];then
		aliddns_record_id=$(query_recordid | get_recordid)
	fi
	
	if [ -z "$aliddns_record_id" ];then
		aliddns_record_id=$(add_record | get_recordid)
		echo_date "[aliddns_update.sh]：添加记录 $aliddns_record_id"
	else
		update_record "$aliddns_record_id" >/dev/null 2>&1
		echo_date "[aliddns_update.sh]：更新记录 $aliddns_record_id"
	fi
	
	# result
	if [ -z "$aliddns_record_id" ]; then
		# failed
		dbus set aliddns_last_act="$now: 失败，原因：无法获取域名record id ！"
		echo_date "[aliddns_update.sh]：本次更新失败，原因：无法获取域名record id ！"
	else
		# success
		dbus set aliddns_record_id="$aliddns_record_id"
		dbus set aliddns_last_act="$now: success, ($ip)"
		echo_date "[aliddns_update.sh]：更新成功，本次IP：$ip！"
	fi
}

start_update | tee -a $LOG_FILE
clean_log | tee -a $LOG_FILE
