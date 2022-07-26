#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2022
#Copyright (C) BlueWave Projects and Services 2015-2022
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

# Title of this theme:
title="theme_user-password-login-basic"

# functions:

generate_splash_sequence() {
	name_password_login
}

header() {
# Define a common header html for every page served
	echo "<!DOCTYPE html>
		<html>
		<head>
		<meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">
		<meta http-equiv=\"Pragma\" content=\"no-cache\">
		<meta http-equiv=\"Expires\" content=\"0\">
		<meta charset=\"utf-8\">
		<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
		<link rel=\"shortcut icon\" href=\"/images/splash.jpg\" type=\"image/x-icon\">
		<link rel=\"stylesheet\" type=\"text/css\" href=\"/splash.css\">
		<title>$gatewayname</title>
		</head>
		<body>
		<div class=\"offset\">
		<med-blue>
			$gatewayname <br>
		</med-blue>
		<div class=\"insert\" style=\"max-width:100%;\">
	"
}

footer() {
	# Define a common footer html for every page served
	year=$(date +'%Y')
	echo "
		<hr>
		<div style=\"font-size:0.5em;\">
			<img style=\"height:30px; width:60px; float:left;\" src=\"$imagepath\" alt=\"Splash Page: For access to the Internet.\">
			&copy; The openNDS Project 2015 - $year<br>
			openNDS $version
			<br><br>
		</div>
		</div>
		</div>
		</body>
		</html>
	"

	exit 0
}



name_password_login() {

	if [ ! -z "$username" ] && [ ! -z "$password" ]; then
		file="/mnt/sda1/users.txt" #the users file that has the data
		flag="false"
		
		while read user pw aq; do
			
			if [ "$user" = "$username" ] && [ "$pw" = "$password" ]; then
			
				account_quota=$aq
				flag="true"
			fi
		done < $file
		
		
		if [ $flag == "true" ];then
			
			
				thankyou_page
				footer
			
		else 
			echo "auth_fail flag not true"
		fi
	fi

	login_form
	footer
}

login_form() {
	# Define a login form

	echo "
		<big-red>Welcome!</big-red><br>
		<med-blue>You are connected to $client_zone</med-blue><br>
		<italic-black>
			To access the Internet you must enter your full name and password address then Accept the Terms of Service to proceed.
		</italic-black>
		<hr>
		<form action=\"/opennds_preauth/\" method=\"get\">
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<input type=\"text\" name=\"username\" value=\"$username\" autocomplete=\"on\" ><br>Name<br><br>
			<input type=\"password\" name=\"password\" value=\"$password\" autocomplete=\"on\" ><br>password<br><br>
			<input type=\"submit\" value=\"Accept Terms of Service\" >
		</form>
		<br>
	"
	footer
}

thankyou_page () {

	binauth_custom="username=$username"
	encode_custom
	if [ -z "$custom" ]; then
		customhtml=""
	else
		customhtml="<input type=\"hidden\" name=\"custom\" value=\"$custom\">"
	fi

	# Continue to the landing page, the client is authenticated there
	

	# Serve the rest of the page:
	landing_page
	footer
}

landing_page() {
	originurl=$(printf "${originurl//%/\\x}")
	gatewayurl=$(printf "${gatewayurl//%/\\x}")

	# Add the user credentials to $userinfo for the log
	userinfo="$userinfo, user=$username"
	check_account

	account_quota=$(($account_quota+0))
	if [ $total -lt $account_quota ]; then
	
		#limit download rate and upload if the user is guest
		if [ "$username" = "guest"  ]; then
				upload_rate="50"
				download_rate="1000"
		fi
		quotas="$session_length $upload_rate $download_rate $upload_quota $download_quota"

		# authenticate and write to the log - returns with $ndsstatus set
		auth_log
		if [ "$ndsstatus" = "authenticated" ]; then
			current_user=$username
			account_giga_left=$((($account_quota-$total)/1024))
			echo "
					<div style=\"width:100%;max-width:400px;padding:15px;margin:auto\" >
						<h2>أهلا أهلا نورت يا بيه فاضلك $account_giga_left جيجا</h2>
						<br/>
						<a href=\"https://www.google.com\"class=\"btn btn-primary mt-3\">Continue</a>
					</div>
				"
		else
			echo "auth_fail ndsstatus"
		fi
	else
		#the account doesn't have enough quota 
		echo "
			<div style=\"width:100%;max-width:400px;padding:15px;margin:auto\" >
				<h2>خلصت النت بتاعك يا عسل اشوفك الشهر اللي جاي</h2>
			</div>"
	fi
	footer
}
check_account() {
	logfile="/tmp/ndslog/binauthlog.log"
	userstr="username=$username"
	total=0

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
			echo "checking $username $download_this_session $upload_this_session" >> "/mnt/sda1/log.log"
			total=$(($total+($upload_this_session+$download_this_session)/1024))
		fi
	done
}

#### end of functions ####


#################################################
#						#
#  Start - Main entry point for this Theme	#
#						#
#  Parameters set here overide those		#
#  set in libopennds.sh			#
#						#
#################################################

# Quotas and Data Rates
#########################################
# Set length of session in minutes (eg 24 hours is 1440 minutes - if set to 0 then defaults to global sessiontimeout value):
# eg for 100 mins:
# session_length="100"
#
# eg for 20 hours:
# session_length=$((20*60))
#
# eg for 20 hours and 30 minutes:
# session_length=$((20*60+30))
session_length="0"

# Set Rate and Quota values for the client
# The session length, rate and quota values could be determined by this script, on a per client basis.
# rates are in kb/s, quotas are in kB. - if set to 0 then defaults to global value).
upload_rate="0"
download_rate="0"
upload_quota="0"
download_quota="0"

quotas="$session_length $upload_rate $download_rate $upload_quota $download_quota"

# Define the list of Parameters we expect to be sent sent from openNDS ($ndsparamlist):
# Note you can add custom parameters to the config file and to read them you must also add them here.
# Custom parameters are "Portal" information and are the same for all clients eg "admin_password" and "location" 
ndscustomparams=""
ndscustomimages=""
ndscustomfiles=""

ndsparamlist="$ndsparamlist $ndscustomparams $ndscustomimages $ndscustomfiles"

# The list of FAS Variables used in the Login Dialogue generated by this script is $fasvarlist and defined in libopennds.sh
#
# Additional custom FAS variables defined in this theme should be added to $fasvarlist here.
additionalthemevars="username password"

fasvarlist="$fasvarlist $additionalthemevars"

# You can choose to define a custom string. This will be b64 encoded and sent to openNDS.
# There it will be made available to be displayed in the output of ndsctl json as well as being sent
#	to the BinAuth post authentication processing script if enabled.
# Set the variable $binauth_custom to the desired value.
# Values set here can be overridden by the themespec file

#binauth_custom="This is sample text sent from \"$title\" to \"BinAuth\" for post authentication processing."

# Encode and activate the custom string
#encode_custom

# Set the user info string for logs (this can contain any useful information)
userinfo="$title"

# Customise the Logfile location. Note: the default uses the tmpfs "temporary" directory to prevent flash wear.
# Override the defaults to a custom location eg a mounted USB stick.
#mountpoint="/mylogdrivemountpoint"
#logdir="$mountpoint/ndslog/"
#logname="ndslog.log"



