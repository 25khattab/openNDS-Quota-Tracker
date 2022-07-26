#!/bin/sh
# this script is being called every 10 mins to check if the current connected devices
# have consumed quota more than it should have.
# and disconnects them if they reached the maximum amount of quota


parse_json() {

		for param in gatewayname gatewayaddress gatewayfqdn version client_type mac ip clientif session_start session_end \
			last_active token state custom download_rate_limit_threshold download_packet_rate download_bucket_size \
			upload_rate_limit_threshold upload_packet_rate upload_bucket_size  \
			download_quota upload_quota download_this_session download_session_avg upload_this_session  upload_session_avg 
		do
			val=$(echo "$param_str" | grep "$param" | awk -F'"' '{printf "%s", $4}')

			if [ "$val" = "null" ]; then
				val="Unlimited"
			fi

			if [ -z "$val" ]; then
				eval $param=$(echo "Unavailable")
			else
				eval $param=$(echo "\"$val\"")
			fi
		done

}
do_ndsctl () {
	local timeout=4

	for tic in $(seq $timeout); do
		ndsstatus="ready"
		ndsctlout=$(ndsctl $ndsctlcmd)

		for keyword in $ndsctlout; do

			if [ $keyword = "locked" ]; then
				ndsstatus="busy"
				sleep 1
				break
			fi

			if [ $keyword = "Failed" ]; then
				ndsstatus="failed"
				break
			fi

			if [ $keyword = "authenticated." ]; then
				ndsstatus="authenticated"
				break
			fi

		done

		keyword=""

		if [ $tic = $timeout ] ; then
			busy_page
		fi

		if [ "$ndsstatus" = "authenticated" ]; then
			break
		fi

		if [ "$ndsstatus" = "failed" ]; then
			break
		fi

		if [ "$ndsstatus" = "ready" ]; then
			break
		fi
	done
}

#getting all devices that are connected to the account being searched
check_account() {
	logfile="/tmp/ndslog/binauthlog.log"
	userstr="username=$username"
	total=0
	echo "$userstr"
	tokens=$(cat $logfile | awk -F "$userstr" 'NF>1{print $0}'| awk -F"token=" '{print $2}' | awk -F", " '{print $1}' | sort |uniq)
	for token in $tokens; do
		ndsctlcmd="json $token"
		do_ndsctl
		param_str=$ndsctlout

		if [ "$param_str" = "{}" ] || [ "$ndsctlstatus" = "busy" ]; then
			continue
		fi
		parse_json
		if [ "$state" = "Authenticated"  ]; then
			total=$(($total+($upload_this_session+$download_this_session)/1024))
			echo "$total $upload_this_session $download_this_session"
		fi
	done
}

#running the scipt only if opennds is working
if [[  $(pgrep opennds) ]] ;then
	while read user pw aq; do
		username=$user
		password=$pw
		account_quota=$(($aq+0))
		echo "reading $user $pw $aq"
		if [ ! -z "$username" ] && [ ! -z "$password" ]; then
			echo "checking account"
			check_account
			echo "done checking account  $total $account_quota"
			if [ $total -ge $account_quota ]; then
				for token in $tokens; do
					echo "device $mac username=$user exceeded account quota disconnecting now" >>"/mnt/sda1/out.log"
					ndsctlcmd="deauth $token"
					do_ndsctl
				done
			fi
		fi
	done < "/mnt/sda1/users.txt"
fi
