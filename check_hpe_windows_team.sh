#!/bin/bash
# FILE: "check_hpe_windows_team"
# DESCRIPTION: check status of network team devices on Hewlett Packard Devices using SNMP.
# AUTHOR: Toni Comerma
# DATE: june-2017

#
# Notes:
#  This works by scanning the snmp table of ".1.3.6.1.4.1.232.18.2.2.1" under CPQNIC.mib for devices. Reads whole table but monitors
#  just de entries that "look real", skipping loopback and some weird result I've got from some devices. 
#  The idea is to make monitoring easy, avoiding the need to identify the device either by name or index.

# Examples
#  check_hpe_windows_team.sh -H IP 
 

 # snmptable -c public -v 2c -M +DIR -m CPQNIC-MIB:CPQSTDEQ-MIB:CPQSINFO-MIB -Cf "," -CH SERVER .1.3.6.1.4.1.232.18.2.2.1

# cpqNicIfLogMapIndex,cpqNicIfLogMapIfNumber,cpqNicIfLogMapDescription,cpqNicIfLogMapGroupType,cpqNicIfLogMapAdapterCount,cpqNicIfLogMapAdapterOKCount,cpqNicIfLogMapPhysicalAdapters,cpqNicIfLogMapMACAddress,cpqNicIfLogMapSwitchoverMode,cpqNicIfLogMapCondition,cpqNicIfLogMapStatus,cpqNicIfLogMapNumSwitchovers,cpqNicIfLogMapHwLocation,cpqNicIfLogMapSpeed,cpqNicIfLogMapVlanCount,cpqNicIfLogMapVlans,cpqNicIfLogMapLastChange,cpqNicIfLogMapAdvancedTeaming,cpqNicIfLogMapSpeedMbps,cpqNicIfLogMapIPV6Address,cpqNicIfLogMapLACNumber

 
PROGNAME=`basename $0`
PROGPATH=`echo $PROGNAME | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1.0 $' `
 
SNMP_OPTS='-Cf "," -CH' 
MIB_PATH="-M +./ -m CPQNIC-MIB:CPQSTDEQ-MIB:CPQSINFO-MIB " 
OID=".1.3.6.1.4.1.232.18.2.2.1"
 
print_help() {
  echo "Usage:"
  echo "  $PROGNAME -H <host> -t <timeout> "
  echo "  $PROGNAME -h "
        echo ""
        echo "Opcions:"
        echo "  -H Host to check"
        echo "  -t timeout"
        echo ""
  exit $STATE_UNKNOWN
}

function remove_quotes {
   arg="$1"
   arg=${arg:1:${#arg}-2}
  echo "$arg"
}

function set_warning {
  if [ $STATE -lt $STATE_WARNING ]
  then
    STATE=$STATE_WARNING
  fi
}

function set_critical {
  if [ $STATE -lt $STATE_CRITICAL ]
  then
    STATE=$STATE_CRITICAL
  fi
}

function write_status {
  case $STATE in
     0) echo "OK: $1"; exit 0 ;;
     1) echo "WARNING: $1"; exit 1 ;;
     2) echo "CRITICAL: $1"; exit 2 ;;
  esac
}

function exit_timeout {
  echo "CRITICAL: Timeout connecting to $HOST"
  echo $STATE_CRITICAL
}
 
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
 
TIMEOUT=40
HOST=""
COMMUNITY="public"
STATE=$STATE_OK
STATE_MESSAGE=""



# Parameters processing
while getopts ":H:t:hc:" Option
do
        case $Option in
                H ) HOST=$OPTARG;;
                c ) COMMUNITY=$OPTARG;;
                t ) TIMEOUT=$OPTARG;;
                h ) print_help;;
                * ) echo "unimplemented option";;
                esac
done
 
if [ ! "$HOST" ] ; then
        echo " Error - No host to monitor "
        echo ""
        print_help
        echo ""
fi
 
timeout ${TIMEOUT}s exit_timeout
  
 
# Read table into temporary file
TMP=`mktemp`
# TMP="sample.txt"

OUT=`snmptable -c $COMMUNITY -v 2c $SNMP_OPTS $MIB_PATH $HOST $OID > $TMP 2>/dev/null`
SNMP_STATUS=$?
#SNMP_STATUS=0
# return status
if [ $SNMP_STATUS -eq 0 ]
then
   # Loop around entries
   while IFS="," read  -r cpqNicIfLogMapIndex cpqNicIfLogMapIfNumber cpqNicIfLogMapDescription cpqNicIfLogMapGroupType cpqNicIfLogMapAdapterCount cpqNicIfLogMapAdapterOKCount cpqNicIfLogMapPhysicalAdapters cpqNicIfLogMapMACAddress cpqNicIfLogMapSwitchoverMode cpqNicIfLogMapCondition cpqNicIfLogMapStatus cpqNicIfLogMapNumSwitchovers cpqNicIfLogMapHwLocation cpqNicIfLogMapSpeed cpqNicIfLogMapVlanCount cpqNicIfLogMapVlans cpqNicIfLogMapLastChange cpqNicIfLogMapAdvancedTeaming cpqNicIfLogMapSpeedMbps cpqNicIfLogMapIPV6Address cpqNicIfLogMapLACNumber others
   do
     #Look real?
     cpqNicIfLogMapAdapterCount=`remove_quotes $cpqNicIfLogMapAdapterCount`
     cpqNicIfLogMapAdapterOKCount=`remove_quotes $cpqNicIfLogMapAdapterOKCount`
     cpqNicIfLogMapLACNumber=`remove_quotes "$cpqNicIfLogMapLACNumber"`
     if [ -z "$cpqNicIfLogMapAdapterCount" ]
     then
       continue
     fi     
     if [ "$cpqNicIfLogMapAdapterCount" == "?" ]
     then
       continue
     fi
     if [ "$cpqNicIfLogMapAdapterCount" == "0" ]
     then
       continue
     fi
    # Check the real ones
    if [ $cpqNicIfLogMapAdapterOKCount -eq 0 ]
    then
      set_critical
      STATE_MESSAGE="${STATE_MESSAGE}$cpqNicIfLogMapLACNumber has 0 active links, "
    else
       if [ $cpqNicIfLogMapAdapterCount -ne $cpqNicIfLogMapAdapterOKCount ]
       then
          set_warning
          STATE_MESSAGE="${STATE_MESSAGE}$cpqNicIfLogMapLACNumber has only $cpqNicIfLogMapAdapterOKCount active links, "
       else
          STATE_MESSAGE="${STATE_MESSAGE}$cpqNicIfLogMapLACNumber is OK" 
       fi
    fi
   done < $TMP

else
   STATE_MESSAGE="ERROR: Unable to contact $HOST"
   set_critical
fi


rm -f $TMP
write_status "$STATE_MESSAGE"
exit $STATE
 
# bye