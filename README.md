# openNDS-Quota-Tracker
This is my work based on my current knowledge.

It's not secure enough but ehh it's a start.

all the credits goes to https://github.com/bluewavenet

# The Problem
I live in egypt and it's considered to be from third world countries and we have limited quotas with high prices,We are 6 members in the house
so I had to give every one of us an account with quota.

# The Solution
I had to research how to do it especially because no one did it before or maybe someone did but didn't share how.

My project is based on opennds and what does opennds do is just tracking the download / upload quota for every device.

I had to write my own code to do the solution.

# How It Works
What does this project do is simple, you setup account (username, password and quota in (megabytes)) like that 

```omar password123 1024(so this is 1GB)```

and every device that connects to the wifi will have to login throught login page.

It will check if that username and password exist and if they have quota to allow accessing the internet if every thing is okay then this device will access the internet.

If another device tried to access the internet using the same account it will check if the current devices connected to the internet using the same account exceeded the quota or not, if not they will access the internet.

Every 5 mins it will check for all the devices if the exceeded the current account quota or not if they exceeded it it will disconnect them, and when devices log out or disconnects from wifi it will automaticly compute the quota they used and decrease it from the account quota.

Every connected Device to any account it will be disconnect every 12 hours you can change it.

# Requirements
1. you must have opennwrt installed on your router(incase of running on router).
2. install opennds follow this : https://opennds.readthedocs.io/en/stable/
3. For  router users:

      You must have usbdrive because constant writing on the router will damage the flash memory,
      
      check this to see how to add drive to your system for openwrt otherwise check with yourself : 
      
      https://openwrt.org/docs/guide-user/storage/usb-drives-quickstart
# Setup

1. After installing opennds type this in the terminal : 
          
          cp /usr/lib/opennds/theme_user-email-login-basic.sh /usr/lib/opennds/mythemespec.sh
          chmod +x /usr/lib/opennds/theme_user-email-login-basic.sh /usr/lib/opennds/mythemespec.sh

      then go to the folder directory and open terminal and run this :

          scp opennds.txt root@192.168.1.1:/etc/config/opennds
          scp -r bootstrap root@192.168.1.1:/etc/opennds/htdocs
          scp binauth_log.sh root@192.168.1.1:/usr/lib/opennds
          scp check_devices.sh root@192.168.1.1:/usr/lib/opennds
          scp mythemespec.sh root@192.168.1.1:/usr/lib/opennds

      ## Be Careful
      you will copy now the file with accounts data you must put it in the usbdrive mount point mine for ex is ```/mnt/sda1```

      so this will be my mount point, it may change with you.
          
          scp users.txt root@192.168.1.1:/mnt/sda1/users.txt

      considring that root@192.168.1.1 is your login path to the router, now you have everything set.

2. Now you have 2 files that is changed :  ```/usr/lib/opennds/bin/binauth_log.sh``` and ```/usr/lib/opennds/bin/mythemespec.sh```
    and 2 new files : ```/usr/lib/check_devices.sh``` and ```/mnt/sda1/users.txt```
    
3. Check the files :
    1. binauth_log.sh from line 235 to 248 :

            currentUser=$(cat /tmp/ndslog/binauthlog.log | awk -F "token=$7" 'NF>1{print $2}'| awk -F"custom=" 'NF>1{print $2}' | awk -F", " '{print $1}' | sort |uniq)
            totalUsed=$(($3/1048576+$4/1048576))
            echo "Im in with $action $currentUser $totalUsed" >> "/mnt/sda1/temp.log"
            file="/mnt/sda1/users.txt"
            cp $file "/mnt/sda1/users_tmp.txt"
            echo "entering the file right now" >> "/mnt/sda1/test.log"
            while read user pw aq; do
                username=$user
                password=$pw
                account_quota=$(($aq+0))
                if [ ! -z "$username" ] && [ ! -z "$password" ] && [ "$currentUser" = "$username" ]; then
                    new_account_quota=$(($account_quota-$totalUsed))
                    sed -i "s/$username\t$password\t$account_quota/$username\t$password\t$new_account_quota/" $file
                fi
            done < "/mnt/sda1/users_tmp.txt"
            rm "/mnt/sda1/users_tmp.txt"
            
        the temp.log file is for debugging, remember /mnt/sda1 is your mount point donot write to many times on the router flash memory.
    2. check_devices.sh line 83 : ```done < "/mnt/sda1/users.txt"``` again /mnt/sda1 is your mount point.
    3. users.txt it should be something like this
        
        ```
        omar    omar123    1024
        ahmed   ahmed123   1024
        ```
    4. mythemespec.sh line 77 : ```file="/mnt/sda1/users.txt"``` again /mnt/sda1 is your mount point.
    5. /etc/config/opennds : option authidletimeout '720' change the `720` to any time you prefer so the device automaticly disconnect from the account (time in minutes)
4. Now you have to turn on the script that will check on the accounts every 5 mins,search for scheduling for your operating system

      if you are using openwrt just write this in terminal 

            ```*/5 * * * * /usr/bin/check_devices.sh```
5. Thats's it everything should be working right now
