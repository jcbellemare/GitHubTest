#                                                                             
# Script Name:  SetMaint.sh                                                        
#                                                                             
# Create by:    JCB                                                         
# Date:         2017-09-21                                                   
#                                                                             
# Description:  Creates a maintenance flag to prevent script from running normally                                                  
#                                                                             
# Output:       MAINT.FLG                                                       
#                                                                             
# Syntax:       SetMaint.sh <delay>                                                       
# Example:      SetMaint.sh 1 hour                                                      
#                                                                             
#                                                                             
# Modifications:                                                              
# Date       By       Description                                             
# 2017-09-21 JCB   Creation                                                 
#                                                                             
#                                                                             
#-----------------------------------------------------------------------------

#----------------------------- VAR Section----------------------------------
PIDFILE=/tmp/SetMaint.pid                    #-- used to prevent multiple            
#----------------------------END VAR Section---------------------------------

if [ -z "$1"  ]
   then
       echo "usage: SetMaint.sh <delay> <unit>"
       echo "1h would be: SetMtaint.sh 1 hour "
       echo "Valid unit: min hour day"
       exit 0
fi
MAINT="$1 $2"
echo "Maintenance mode set to: $(date --date="$MAINT") "
echo "$(date --date="$MAINT" '+%Y%m%d%H%M%S')" > /dash/bin/MAINT.FLG
