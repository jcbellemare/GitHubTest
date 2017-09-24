#                                                                             
# Script Name:  CheckMaint.sh                                                        
#                                                                             
# Create by:    JCB                                                         
# Date:         2017-09-14                                                   
#                                                                             
# Description:  Check for maintenance flag and content                                                  
#                                                                             
# Output:       n/a                                                       
#                                                                             
# Syntax:       CheckMaint.sh                                                       
# Example:      CheckMaint.sh                                                      
#                                                                             
#                                                                             
# Modifications:                                                              
# Date       By       Description                                             
# 2017-09-14 JCB   Creation                                                 
#                                                                             
#                                                                             
#-----------------------------------------------------------------------------

#----------------------------- VAR Section----------------------------------
WAIT=900                                 #-- time in sec to wait for sending next email
LOGFILE=/dash/logs/CheckMaint.log        #-- Email_HB_Check log file             
PIDFILE=/tmp/CheckMaint.pid              #-- used to prevent multiple            
MAINTFLG=/dash/bin/MAINT.FLG             #-- Maintenance Flag
NOTIFY=jcb@wss.com
DASH="demo.wss.com"
MSG=/tmp/msg$$
#--------------------------END VAR Section---------------------------------
#--------------------------------------------------------------------------
# Create a PID file to prevent multiple execution of the script
#--------------------------------------------------------------------------

if [ -f $PIDFILE ]
then
  PID=$(cat $PIDFILE)
  ps -p $PID > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    echo "Process already running"
    exit 1
  else
    ## Process not found assume not running
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      echo "Could not create PID file"
      exit 1
    fi
  fi
else
  echo $$ > $PIDFILE
  if [ $? -ne 0 ]
  then
    echo "Could not create PID file"
    exit 1
  fi
fi
#---------------------------------------------------------------------------
NOW=$(date '+%Y%m%d%H%M%S')
if [ -f $MAINTFLG ]
then
   TFLAG=$(cat $MAINTFLG)
   if [ "$NOW" -gt "$TFLAG" ]
      then
         EXP=$(cat $MAINTFLG | sed -r 's/^.{4}/&-/;:a; s/([-:])(..)\B/\1\2:/;ta;s/:/-/;s/:/ /')
         echo " EXPIRED  - Maintenance Flag found for $DASH at $(date) " >> $MSG
         echo " Maintenance Flag Expiration: $EXP " >> $MSG
         echo " " >> $MSG
         echo " Please take action: " >> $MSG
         echo "   Remove FLAG:         rm $MAINTFLG ">> $MSG
         echo "   Extent Maintenance   /dash/bin/SetMaint.sh " >> $MSG
         cat $MSG | mailx -s " TEST - [$DASH] - Protop MAINTENANCE Alert" $NOTIFY
         rm $MSG
         sleep $WAIT
   fi
else
  exit 0 
fi

rm $PIDFILE
