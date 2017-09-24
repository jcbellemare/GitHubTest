#                                                                             
# Script Name:  Email_HB_Check.sh                                                        
#                                                                             
# Create by:    JCB                                                         
# Date:         2017-09-07                                                   
#                                                                             
# Description:  Email heartbeat generator and checker                                                  
#                                                                             
# Output:       screen/log                                                       
#                                                                             
# Syntax:       Email_HB_Check.sh                                                       
# Example:      Email_HB_Check.sh                                                      
#                                                                             
#                                                                             
# Modifications:                                                              
# Date       By       Description                                             
# 2017-09-07 JCB      Creation                                                 
# 2017-09-26 JCB      Added Maintenance check                                                                          
#                                                                             
#-----------------------------------------------------------------------------
# Variables section
#-----------------------------------------------------------------------------
LOGFILE=/dash/logs/Email_HB_Check.log    #-- IMAP Check log file
PWDFILE=/dash/bin/Email_HB_Check.pwd     #-- IMAP Password
HBLIST=/dash/bin/Dashboard_Check.lst     #-- List of HB Dash to check
PIDFILE=/tmp/EMAIL_HB_Check.pid          #-- used to prevent multiple Email_HB instances
#DEBUG="--debug"                         #-- To display extra information in LOGFILE
MAINTFLG=/dash/bin/MAINT.FLG             #-- Maintenance Flag file
MAINTLOG=/dash/logs/MAINT.LOG            #-- Maintenance LOG

#-----------------------------------------------------------------------------
# Configuration
#-----------------------------------------------------------------------------

. /dash/bin/Email_HB_Check.cfg

#-----------------------------------------------------------------------------
# Maintenance Check
#----------------------------------------------------------------------------
if [ -f $MAINTFLG ]
   then
       EXP=$(cat $MAINTFLG | sed -r 's/^.{4}/&-/;:a; s/([-:])(..)\B/\1\2:/;ta;s/:/-/;s/:/ /')
       echo "$(date) -- Maintenance FLAG Found - Expiration: $EXP - exiting $(basename $0)"| tee -a $LOGFILE $MAINTLOG > /dev/null
       exit
fi

echo "$(date)  ----- Start Email_HB_Check.sh --------" >> $LOGFILE
#----------------------------------------------------------------------------
# Create a PID file to prevent multiple execution of the script
#----------------------------------------------------------------------------

if [ -f $PIDFILE ]
then
  PID=$(cat $PIDFILE)
  ps -p $PID > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    echo "$(date) ERROR ---- Process already running" >> $LOGFILE
    exit 1
  else
    ## Process not found assume not running
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      echo "$(date) ERROR ---- Could not create PID file" >> $LOGFILE
      exit 1
    fi
  fi
else
  echo $$ > $PIDFILE
  if [ $? -ne 0 ]
  then
    echo "$(date) ERROR ---- Could not create PID file" >> $LOGFILE
    exit 1
  fi
fi
#--------------------------------------------------------------------------
# Send Email heartbeat 
#--------------------------------------------------------------------------

echo "$(date) -- Sending HB Email from $DASH"  >> $LOGFILE
echo "Email_HB from $DASH sent on $(date)" | mailx -s "$DASH" $EMAILTO

#-------------------------------------------------------------------------
# Check Inbox via IMAP Server for Email HeartBeat
#-------------------------------------------------------------------------
while read DASHCHECK
do 
   echo "$(date) -- checking $IMAP connectivity" >> $LOGFILE
   nc -w5 $IMAP $PORT < /dev/null
   if [ $? = 0 ]
     then
         echo "$(date) -- $IMAP - connection success" >> $LOGFILE
     else
         echo "$(date) -- $IMAP - ERROR CONNECTING" >> $LOGFILE
   fi
   echo "$(date) -- Checking Email - [$DASHCHECK]"  >> $LOGFILE
   perl /dash/bin/Email_HB_Check.pl --user $USER --passfile $PWDFILE --subject $DASHCHECK --notify $NOTIFY --delta $DELTA --host $IMAP --port $PORT $DEBUG --purge $PURGE  >> $LOGFILE 2>&1
done < "$HBLIST"

#-------------------------------------------------------------------------

rm $PIDFILE
echo "$(date) ----- Stop Email_HB_Check.sh --------"  >> $LOGFILE
