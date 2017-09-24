#                                                                             
# Script Name:  Docker_HB_Check.sh                                                        
#                                                                             
# Create by:    JCB                                                         
# Date:         2017-09-13                                                   
#                                                                             
# Description:  Check if all grafana & influx from site.json are running/responsives                                                  
#                                                                             
# Output:       display/log                                                       
#                                                                             
# Syntax:       Docker_HB_Check.sh                                                       
# Example:      Docker_HB_Check.sh                                                      
#                                                                             
#                                                                             
# Modifications:                                                              
# Date       By       Description                                             
# 2017-09-13 JCB   Creation                                                 
# 2017-09-19 JCB   Adding RESTART option from cfg file                                                                             
#                                                                             
#-----------------------------------------------------------------------------
LOGFILE=/dash/logs/Docker_HB_Check.log         #-- Email_HB_Check log file
PIDFILE=/tmp/Docker_HB_Check.pid               #-- used to prevent multiple
MAINTFLG=/dash/bin/MAINT.FLG                   #-- Maintenance Flag file
MAINTLOG=/dash/logs/MAINT.LOG                  #-- Maintenance LOG


#---------------------------------------------
# Load Config File
#---------------------------------------------
. /dash/bin/Docker_HB_Check.cfg


echo "$(date) -- Docker_HB_Check START -----------------------------------" >> $LOGFILE

SENDEMAIL=NO


#-----------------------------------------------------------------------------
# Maintenance Check
#----------------------------------------------------------------------------
if [ -f $MAINTFLG ]
   then
       EXP=$(cat $MAINTFLG | sed -r 's/^.{4}/&-/;:a; s/([-:])(..)\B/\1\2:/;ta;s/:/-/;s/:/ /')
       echo "$(date) -- Maintenance FLAG Found - Expiration: $EXP - exiting $(basename $0)"| tee -a $LOGFILE $MAINTLOG > /dev/null
       exit
fi

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
#--------------------------------------------------------------------------
# Prepare Email body
#--------------------------------------------------------------------------
echo " AT: $(date) --- The following Docker instances are having issues: " > /tmp/msg$$ 
echo "=============================================================" >> /tmp/msg$$       

#--------------------------------------------------------------------------
# Extract Sites
#--------------------------------------------------------------------------
echo "$(date) - Creating Docker Site list ----------------------------" >> $LOGFILE
cat $SITES | grep -e siteName -e Active | awk '{ print $2 }' | cut -f2 -d\" > /tmp/Docker_HB_Check.tmp$$
while IFS= read line
do 
  site=$line
  read line
  active=$(echo $line | cut -f1 -d,)
  echo "$site-$active" >> /tmp/Docker_HB_Check.act$$
done < /tmp/Docker_HB_Check.tmp$$

rm /tmp/Docker_HB_Check.tmp$$
cat /tmp/Docker_HB_Check.act$$ | grep -e true | cut -f1 -d- > /tmp/Docker_HB_Check.lst$$
rm /tmp/Docker_HB_Check.act$$
echo "$(date) - Creating Docker Site listi: Completed ----------------" >> $LOGFILE

#---------------------------------------------
#-- Removing Protop from Docker_HB_Check.lst$$
#---------------------------------------------
sed -i -e 's/ProTop//g' /tmp/Docker_HB_Check.lst$$
sed -i '/^$/d' /tmp/Docker_HB_Check.lst$$


echo "$(date) - Checking GRAFANA and INFLUX instances " >> $LOGFILE
while IFS= read DOCKERCHK
do
#--------------------------------------------------------------------
# Checking Grafana
#--------------------------------------------------------------------
  docker ps | grep grafana-$DOCKERCHK >> /dev/null
  if [ $? -eq 0 ]
    then
      echo "$(date) - grafana-$DOCKERCHK running - OK" >> $LOGFILE
    else
      SENDEMAIL=YES
      MSG="$(date) - grafana-$DOCKERCHK *** NOT RUNNING *** "
      echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
      CONTID=$(docker ps -a | grep grafana-$DOCKERCHK | awk '{print $1}')
      if [ "$CONTID" = "" ]
         then
             MSG="$(date)        - WARNING -- Docker grafana-$DOCKERCHK is Invalid"
             echo $MSG | tee -a $LOGFILE /tmp/msg$$ > /dev/null
         else
             if [ "$RESTART" = "NO" ]
               then 
                   MSG="$(date)                  RESTART OPTION set to NO"
                   echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
               else
                   echo "        Restarting grafana-$DOCKERCHK ID: $CONTID " >> /tmp/msg$$
                   docker restart $CONTID 2>&1 >> /dev/null
                   sleep 5
                   docker logs $CONTID --tail 50 > /tmp/GRAF_CONTID_$$.LOG 2>&1
                   echo "grafana-$DOCKERCHK's LOG" | mail -s "[$DASHBOARD] Docker Restart LOG - grafana-$DOCKERCHK on $(date)" -a /tmp/GRAF_CONTID_$$.LOG $NOTIFY
                   rm /tmp/GRAF_CONTID_$$.LOG
                   docker ps | grep grafana-$DOCKERCHK >> /dev/null
                   if [ $? -eq 0 ]
                     then
                         MSG="$(date) - grafana-$DOCKERCHK ==> RESTARTED SUCCESSFULLY ! "
                         echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
                     else
                         SENDEMAIL=YES
                         MSG="$(date) - grafana-$DOCKERCHK ==> FAILED to RESTART ! "
                         echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
                   fi
             fi
      fi
  fi
#--------------------------------------------------------------------
# Checking Influx
#--------------------------------------------------------------------
  docker ps | grep influx-$DOCKERCHK 1>> /dev/null
  if [ $? -eq 0 ]
    then
      echo "$(date) - influx-$DOCKERCHK running - OK" >> $LOGFILE
    else
       SENDEMAIL=YES
       MSG="$(date) - influx-$DOCKERCHK  *** NOT RUNNING *** "
       echo "$MSG" | tee -a $LOGFILE /tmp/msg$$  > /dev/null
       CONTID=$(docker ps -a  | grep influx-$DOCKERCHK | awk '{print $1}')
       if [ "$CONTID" = "" ]
          then
              MSG="$(date)        - WARNING -- Docker influx-$DOCKERCHK is Invalid" 
          else
             if [ "$RESTART" = "NO" ]
               then 
                   MSG="$(date)                  RESTART OPTION set to NO"
                   echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
               else
                   echo "       Restarting influx-$DOCKERCHK ID: $CONTID " >> /tmp/msg$$
                   docker restart $CONTID 2>&1 > /dev/null
                   sleep 5
                   docker logs $CONTID --tail 50 > /tmp/INF_CONTID_$$.LOG 2>&1
                   echo "influx-$DOCKERCHK's LOG" | mail -s "[$DASHBOARD] Docker Restart - influx-$DOCKERCHK on $(date)" -a /tmp/INF_CONTID_$$.LOG $NOTIFY
                   rm /tmp/INF_CONTID_$$.LOG
                   docker ps | grep influx-$DOCKERCHK >> /dev/null
                   if [ $? -eq 0 ]
                     then
                         MSG="$(date) - influx-$DOCKERCHK ==> RESTARTED SUCCESSFULLY ! "
                         echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
                     else
                         SENDEMAIL=YES
                         MSG="$(date) - influx-$DOCKERCHK ==> FAILED to RESTART ! "
                         echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
                  fi
             fi
       fi
  fi

#--------------------------------------------------------------------
# End Checking site.json
#--------------------------------------------------------------------
done < /tmp/Docker_HB_Check.lst$$

#---------------------------------------------
# Checking Influx for Dashboard
#---------------------------------------------
  docker ps | grep dashboard >> /dev/null
  if [ $? -eq 0 ]
    then
      echo "$(date) - dashboard running - OK" >> $LOGFILE
    else
      SENDEMAIL=YES
      MSG="$(date) - dashboard  *** NOT RUNNING *** -- Tryig to RESTART"
      echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null 
       CONTID=$(docker ps -a  | grep dashboard | awk '{print $1}')
       if [ "$CONTID" = "" ]
          then 
              echo "       - WARNING -- Docker dashboard is Invalid" >> /tmp/msg$$
          else
              echo "       Restarting dashboard ID: $CONTID " >> /tmp/msg$$
              docker restart $CONTID 2>&1 >> /dev/null
              sleep 5
              docker logs $CONTID --tail 50 > /tmp/DASH_CONTID_$$.LOG 2>&1 
              echo "RESTARTING - LOG for dashboard" | mail -s "[$DASHBOARD] Docker Restart - influx-$DOCKERCHK on $(date)" -a /tmp/DASH_CONTID_$$.LOG $NOTIFY
              rm /tmp/DASH_CONTID_$$.LOG
             docker ps | grep dashboard >> /dev/null
             if [ $? -eq 0 ]
                then
                    echo "$(date) - dashboard running - OK" >> $LOGFILE
                else
                    SENDEMAIL=YES
                    MSG="$(date) - dashboard ==> FAILED to RESTART ! "
                    echo "$MSG" | tee -a $LOGFILE /tmp/msg$$ > /dev/null
             fi
       fi
  fi


if [ "$SENDEMAIL" == "YES" ]
   then
    cat /tmp/msg$$ | mail -s "[$DASHBOARD] Protop Docker ALERT on $(date)" $NOTIFY
fi 

rm /tmp/Docker_HB_Check.lst$$
rm $PIDFILE
rm /tmp/msg$$

echo "$(date) -- Docker_HB_Check STOP   -----------------------------------" >> $LOGFILE
