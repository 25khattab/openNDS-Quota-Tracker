#!/bin/sh
#Copyright (C) The openNDS Contributors 2004-2021
#Copyright (C) BlueWave Projects and Services 2015-2021
#This software is released under the GNU GPL license.
#
# Warning - shebang sh is for compatibliity with busybox ash (eg on OpenWrt)
# This is changed to bash automatically by Makefile for generic Linux
#

# This is the Click To Continue Theme Specification (ThemeSpec) File with custom placeholders.
# functions:

generate_splash_sequence() {
	name_email_login
}
header() {
	# Define a common header html for every page served
	echo "<!DOCTYPE html>
		  <html lang=\"en\">
			<head>
				<meta charset=\"utf-8\">
				<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
				<title>Signin</title>
				<!-- Bootstrap core CSS -->
				<link href=\"/bootstrap/css/bootstrap.min.css\" rel=\"stylesheet\">
				<link href=\"/bootstrap/css/signin.css\" rel=\"stylesheet\">
				<style>
				  .bd-placeholder-img {
					font-size: 1.125rem;
					text-anchor: middle;
					-webkit-user-select: none;
					-moz-user-select: none;
					user-select: none;
				  }

				  @media (min-width: 768px) {
					.bd-placeholder-img-lg {
					  font-size: 3.5rem;
					}
				  }
				</style>
				<title>$gatewayname</title>
			</head>
			<body class=\"text-center\">
	"
}

footer() {
	# Define a common footer html for every page served
	echo "
		</body>
		</html>
	"

	exit 0
}

name_email_login() {
	# In this example, we check that both the username and email address fields have been filled in.
	# If not then serve the initial page, again if necessary.
	# We are not doing any specific validation here, but here is the place to do it if you need to.
	#
	# Note if only one of username or email address fields is entered then that value will be preserved
	# and displayed on the page when it is re-served.
	#
	# The client is required to accept the terms of service.

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
	year=$(date +'%Y')

	echo "
	<main class=\"wrapper form-signin\">
		<form action=\"/opennds_preauth/\" method=\"get\">
			<h1 class=\"h3 mb-3 fw-normal\">Please sign in</h1>
			<input type=\"hidden\" name=\"fas\" value=\"$fas\">
			<div class=\"form-floating\">
			  <input type=\"text\" class=\"form-control\" id=\"floatingInput\" placeholder=\"UserName\" name=\"username\" value=\"$username\" autocomplete=\"on\">
			  <label for=\"floatingInput\">UserName</label>
			</div>
			<div class=\"form-floating\">
			  <input type=\"password\" class=\"form-control\" id=\"floatingPassword\" placeholder=\"Password\" name=\"password\" value=\"$password\" autocomplete=\"on\">
			  <label for=\"floatingPassword\">Password</label>
			</div>

			<button class=\"w-100 btn btn-lg btn-primary\" type=\"submit\">Sign in</button>
			<p class=\"mt-5 mb-3 text-muted\">© 2017–$year</p>
		</form>
	</main>
			"
	footer
	
}

thankyou_page () {
	# If we got here, we have both the username and emailaddress fields as completed on the login page on the client,
	# or Continue has been clicked on the "Click to Continue" page
	# No further validation is required so we can grant access to the client. The token is not actually required.

	# We now output the "Thankyou page" with a "Continue" button.

	# This is the place to include information or advertising on this page,
	# as this page will stay open until the client user taps or clicks "Continue"

	# Be aware that many devices will close the login browser as soon as
	# the client user continues, so now is the time to deliver your message.

	# Add your message here:
	# You could retrieve text or images from a remote server using wget or curl
	# as this router has Internet access whilst the client device does not (yet).
	binauth_custom="$username"
	if [ -z "$binauth_custom" ]; then
		customhtml=""
	else
		htmlentityencode "$binauth_custom"
		binauth_custom=$entityencoded
		# Additionally convert any spaces
		binauth_custom=$(echo "$binauth_custom" | sed "s/ /\_/g")
		customhtml="<input type=\"hidden\" name=\"binauth_custom\" value=\"$binauth_custom\">"
	fi
	# Serve the rest of the page:
	landing_page
	footer
}

landing_page() {
	
		originurl=$(printf "${originurl//%/\\x}")

		# Add the user credentials to $userinfo for the log
		userinfo="$userinfo, username=$username, password=$password"


		#check if the account has avalibale quota or not
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
				# Welcome Messeage in the h2
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
			total=$(($total+($upload_this_session+$download_this_session)/1048576)) # the 1048576 is to convert bytes to megabytes
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
# Custom parameters are "Portal" information and are the same for all clients eg "admin_email" and "location" 
ndscustomparams=""
ndscustomimages=""
ndscustomfiles=""

ndsparamlist="$ndsparamlist $ndscustomparams $ndscustomimages $ndscustomfiles"

# The list of FAS Variables used in the Login Dialogue generated by this script is $fasvarlist and defined in libopennds.sh
#
# Additional custom FAS variables defined in this theme should be added to $fasvarlist here.
additionalthemevars="username password"

fasvarlist="$fasvarlist $additionalthemevars"

# Title of this theme:
title="theme_user-email-login-basic"

# You can choose to send a custom data string to BinAuth. Set the variable $binauth_custom to the desired value.
# Note1: As this script runs on the openNDS router and creates its own log file, there is little point also enabling Binauth.
#	BinAuth is intended more for use with EXTERNAL FAS servers that don't have direct access to the local router.
#	Nevertheless it can be enabled at the same time as this script if so desired.
# Note2: Spaces will be translated to underscore characters.
# Note3: You must escape any quotes.
#binauth_custom="$username=$username, password=$password"

# Set the user info string for logs (this can contain any useful information)
userinfo="$title"

# Customise the Logfile location. Note: the default uses the tmpfs "temporary" directory to prevent flash wear.
# Override the defaults to a custom location eg a mounted USB stick.
#mountpoint="/mylogdrivemountpoint"
#logdir="$mountpoint/ndslog/"
#logname="ndslog.log"



