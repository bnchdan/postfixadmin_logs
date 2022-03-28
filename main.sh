#!/bin/bash
cd $(dirname $0)

lastLine=1
currentLine=0

logFile="/var/log/mail.log"
timeToSleep='300'

#Set initial time of file
LTIME=`stat -c %Z $logFile`



#move logs to postfix directory ../maillog
function moveLogs(){	
	
	file=$1

	#delete logs older than 30 days
	find ../maillog/ -type f -mtime +30 -delete

	#check if maillog directory exists
	if [ ! -d ../maillog ]
	then
	        #create direcory
		mkdir ../maillog
	fi


	data=`date --date='1 day ago' +%F`

	mysql -u root --skip-column-names --execute="USE postfix; SELECT username,domain FROM domain_admins WHERE active=1 AND domain <> 'ALL';" | while read username domain
		    do

			#check if folder for domain doesn t exists
			if [ ! -d ../maillog/$domain ]
			then
	    			echo "Directory does not exists for "$domain
				#create direcory
				mkdir ../maillog/$domain			
			fi

			#grep by domain
			grep @$domain $file | grep -v "postfix-policyd" | grep -v postgrey >> ../maillog/$domain/$data-bulk.log
			grep @$domain $file | grep "Password mismatch" >> ../maillog/$domain/$data-failed-auth.log
			
			if [ -d ../maillog/$domain/$data-bulk.log ]
			then
				rm ../maillog/$domain/$data-bulk.log
			fi
			
			if [ -d ../maillog/$domain/$data-failed-auth.log ]
			then
				rm ../maillog/$domain/$data-failed-auth.log
			fi
			
			#zip
			gzip ../maillog/$domain/$data-bulk.log
			gzip ../maillog/$domain/$data-failed-auth.log

			echo $domain			
		    done
}





#create a "diff" from current and last logs
function getLogs(){

	#get nr. of last line from $logFile
	currentLine=`wc -l $logFile | cut -d " " -f 1`


	file=`date '+logs_for_PostfixAdmin_%Y_%d_%m_%H_%M_%S'`

	if (( lastLine > currentLine )); then #if logrotate
		tail +1 /var/log/mail.log.1 | head -$((currentLine - lastLine )) > $file
    		lastLine=1
    		#move logs to postfixadmin
		moveLogs $file
    		return
	fi
	

	tail +$((lastLine)) /var/log/mail.log | head -$((currentLine - lastLine )) > $file
	#move logs to postfixadmin
	moveLogs $file

	lastLine=$currentLine

	#remove file
	rm $file
}



# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
        echo "** Trapped CTRL-C"

        #remove auxiliar log file 
        if ls logs_for_PostfixAdmin* 1> /dev/null 2>&1; then
        	rm logs_for_PostfixAdmin*
        fi
        exit
}





getLogs
while true
do
	ATIME=`stat -c %Z $logFile`

   	if [[ "$ATIME" != "$LTIME" ]]
   	then    
        	getLogs
        	LTIME=$ATIME
   	fi
   	sleep $timeToSleep

done
