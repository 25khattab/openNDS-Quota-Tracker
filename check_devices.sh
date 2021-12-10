#!/bin/sh

parse_json() {

	for param in gatewayname gatewayaddress gatewayfqdn mac version ip clientif session_start session_end last_active token state upload_rate_limit \
		download_rate_limit upload_quota download_quota upload_this_session download_this_session  \
		upload_session_avg  download_session_avg
	do
		val=$(echo "$json_str" | grep "$param" | awk -F'"' '{printf "%s", $4}')

		if [ "$val" = "null" ]; then
			val="Unlimited"
		fi

		eval $param=$(echo "\"$val\"")
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
		done

		if [ "$ndsstatus" = "ready" ]; then
			break
		fi
	done
}

#getting all devices that are connected to the account being searched
check_account() {
	logfile="/tmp/ndslog/binauthlog.log"
	userstr="custom=$username"
	total=0

	tokens=$(cat $logfile | awk -F "$userstr" 'NF>1{print $0}'| awk -F"token=" '{print $2}' | awk -F", " '{print $1}' | sort |uniq)

	for token in $tokens; do
		ndsctlcmd="json $token"
		do_ndsctl
		json_str=$ndsctlout

		if [ "$json_str" = "{}" ] || [ "$ndsctlstatus" = "busy" ]; then
			continue
		fi

		parse_json

		if [ "$state" = "Authenticated"  ]; then
			total=$(($total+($upload_this_session+$download_this_session)/1048576))
		fi
	done
}

#running the scipt only if opennds is working
if [[  $(pgrep opennds) ]] ;then
	while read user pw aq; do
		
		username=$user
		password=$pw
		account_quota=$(($aq+0))
		if [ ! -z "$username" ] && [ ! -z "$password" ]; then
			check_account
			if [ $total -ge $account_quota ]; then
				for token in $tokens; do
					ndsctlcmd="deauth $token"
					do_ndsctl
				done
			fi
		fi
	done < "/mnt/sda1/users.txt"
fi
