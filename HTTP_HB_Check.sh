#                                                                             
# Script Name:  HTTP_HB_Check.sh                                                        
#                                                                             
# Create by:    JCB                                                         
# Date:         2017-09-12                                                   
#                                                                             
# Description:  HTTP monitoring script & alert                                                  
#                                                                             
# Output:       display/log                                                       
#                                                                             
# Syntax:       HTTP_HB_Check.sh                                                       
# Example:      HTTP_HB_Check.sh                                                      
#                                                                             
#                                                                             
# Modifications:                                                              
# Date       By       Description                                             
# 2017-09-12 JCB   Creation                                                 
#                                                                             
#                                                                             
#-----------------------------------------------------------------------------
PIDFILE=/tmp/HTTP_HB_Check.pid           #-- used to prevent multiple instances
HBLIST=/dash/bin/Dashboard_Check.lst     #-- lis of HB Dash to check
LOGFILE=/dash/logs/HTTP_HB_Check.log     #-- Log file
NOTIFY=schlits@gmail.com
MAINTFLG=/dash/bin/MAINT.FLG             #-- Maintenance Flag file
MAINTLOG=/dash/logs/MAINT.LOG            #-- Maintenance LOG

echo "$(date) --- Start HTTP_HB_Check ---------------------------------------" >> $LOGFILE

#----------------------------------------------------------------------------
# Create a PID file to prevent multiple execution of the script
#----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------
# Maintenance Check
#----------------------------------------------------------------------------
if [ -f $MAINTFLG ]
   then
       EXP=$(cat $MAINTFLG | sed -r 's/^.{4}/&-/;:a; s/([-:])(..)\B/\1\2:/;ta;s/:/-/;s/:/ /')
       echo "$(date) -- Maintenance FLAG Found - Expiration: $EXP - exiting $(basename $0)"| tee -a $LOGFILE $MAINTLOG > /dev/null
       exit
fi


#----------------------------------------------------------------------------
#
#----------------------------------------------------------------------------
while IFS= read DASHCHECK
do
  echo "$(date) -- Checking HTTP - [$DASHCHECK] " >> $LOGFILE
  curl -o /tmp/proxy.test_$DASHCHECK http://$DASHCHECK/proxy.test 
  FCONTENT=$(cat /tmp/proxy.test_$DASHCHECK)
  if [ "$FCONTENT" == "test passed" ]
     then 
         echo "$(date) -- File download oK - removing /tmp/proxy.test_$DASHCHECK " >> $LOGFILE 
     else 
         echo "$(date) -- File download NOT OK - pressing panic button " >> $LOGFILE
         echo " HTTP proxy file download FAILED for $DASHCHECK " | mailx -s "[$DASHCHECK] Protop HTTP Alert" $NOTIFY
  fi
rm /tmp/proxy.test_$DASHCHECK
done < $HBLIST

rm $PIDFILE

echo "$(date) --- STOP HTTP_HB_Check ---------------------------------------" >> $LOGFILE

