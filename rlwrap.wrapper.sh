#! /bin/bash

# start of the code block, force loading whole script into memory, prevents runtime changes to alter flow
{

# -----------------------------------------------------------------------------
# Documentation
# -----------------------------------------------------------------------------

# ${LINDE_ORA_SITE}/bin/rlwrap.wrapper.sh

#    script: $LINDE_ORA_SITE/bin/rlwrap.wrapper.sh
#    
#    run as: oracle, interactive via symlink
#            
#     usage: $0 <command args> 
#
#     files:
#           $LINDE_ORA_SITE/bin/
#           rlwrap.wrapper.sh
#           sqlplus+    --> rlwrap.wrapper.sh
#           rman+       --> rlwrap.wrapper.sh
#           dgmgrl+     --> rlwrap.wrapper.sh
#
#           $LINDE_ORA_SITE/etc/rlwrap/
#           rman-reserved.completionlist
#           sql-commands.completionlist
#           sqlplus-commands.completionlist
#           sqlplus-reserved.completionlist
#
#           $LINDE_ORA_SITE/etc/rlwrap/
#               <command>.completionlist                    # optional
#
#           $HOME/.rlwrap/
#               <command>-<hostname>.history
#
#           $HOME/tmp/rlwrap/
#               databaseobjects.<oracle_sid>.completion     # created dynamical

# procedure: 
#            required command should be prefixed to symlink = sqlplus / rman / dgmgrl
#            appropriate completion lists for each command in $ADM_HOME/etc/rlwrap/ and $ADM_SITE/etc/rlwrap/
#            dynamic completion list for sqlplus will b e create if $ORACLE_SID is set
#            exec rlwrap -b "" -f <completion> -f <completion> -H <history> <command> $*

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------

typeset RLWRAP_BIN="/usr/bin/rlwrap"
typeset RLWRAP_ETC="${LINDE_ORA_SITE}/etc/rlwrap"
typeset RLWRAP_ETC_HOME="${HOME}/etc/rlwrap"
typeset RLWRAP_TMP="${HOME}/tmp/rlwrap"
typeset RLWRAP_LOG="${HOME}/.rlwrap"

typeset -i errors=0
typeset script_name=$(basename $0)

typeset UNAME=$(uname -s)
UNAME=$(echo $UNAME | tr '[:upper:]' '[:lower:]')

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

function select_databaseobjects
{
    sqlplus -S /nolog <<\EofHERE

whenever sqlerror exit
whenever oserror exit

set trimspool on
set verify on
set pages 0
set feedback off
set heading off

connect / as sysdba

select lower(object_name) 
  from all_objects 
 where object_type in ('TABLE','VIEW','SYNONYM') and 
       object_name not like '%/%' and 
       object_name not like '%$%' and 
       object_name not like '%=%' 
union 
select distinct lower(object_name) 
  from all_objects 
 where object_type in ('SYNONYM') and 
       object_name not like '%/%' and 
       object_name like 'V$%' 
union 
select lower(COLUMN_NAME) 
  from all_tab_columns 
 where owner not in ('SYS','SYSTEM','SYSMAN','MGMT_VIEW','PERFSTAT' ,'OUTLN','DBSNMP','CTXSYS','XDB');
EofHERE

return $?
}

# -----------------------------------------------------------------------------
# Main 
# -----------------------------------------------------------------------------

# check prereqs
[[ ! -d $RLWRAP_TMP ]] && { mkdir -p $RLWRAP_TMP ; }
[[ ! -d $RLWRAP_LOG ]] && { mkdir -p $RLWRAP_LOG ; }

[[ ! -x $RLWRAP_BIN ]] && { echo "error> executable $RLWRAP_BIN missing"; (( errors++ )); }
for d in $RLWRAP_ETC $RLWRAP_TMP  $RLWRAP_LOG
do
    [[ ! -d $d ]] && { echo "error> directory $d missing"; (( errors++ )); }
done
[[ $errors -gt 0 ]] && exit $errors
    
# setup rlwrap command and args based on prefix of script_name
case $script_name in
sqlplus*)
    RLWRAP_CMD="sqlplus"
    RLRWAP_CPL=""
    for f in sql-commands.completionlist sqlplus-commands.completionlist sqlplus-reserved.completionlist
    do
        [[ -r $RLWRAP_ETC/$f ]] && RLRWAP_CPL="$RLRWAP_CPL -f $RLWRAP_ETC/$f"
    done
    if [[ -n $ORACLE_SID ]]
    then
        if [[ ! -s $RLWRAP_TMP/databaseobjects.$ORACLE_SID.completion ]]
        then
            select_databaseobjects >$RLWRAP_TMP/databaseobjects.$ORACLE_SID.completion
            [[ $? -ne 0 ]] && rm $RLWRAP_TMP/databaseobjects.$ORACLE_SID.completion
        fi
    fi
    [[ -r $RLWRAP_TMP/databaseobjects.$ORACLE_SID.completion ]] && RLRWAP_CPL="$RLRWAP_CPL -f $RLWRAP_TMP/databaseobjects.$ORACLE_SID.completion"
    ;;
rman*)  
    RLWRAP_CMD="rman"
    RLRWAP_CPL=""
    for f in rman-reserved.completionlist sql-commands.completionlist sqlplus-commands.completionlist 
    do
        [[ -r $RLWRAP_ETC/$f ]] && RLRWAP_CPL="$RLRWAP_CPL -f $RLWRAP_ETC/$f"
    done
    ;;
dgmgrl*)
    RLWRAP_CMD="dgmgrl"
    RLRWAP_CPL=""
    for f in dgmgrl-commands.completionlist dgmgrl-reserved.completionlist sql-commands.completionlist 
    do
        [[ -r $RLWRAP_ETC/$f ]] && RLRWAP_CPL="$RLRWAP_CPL -f $RLWRAP_ETC/$f"
    done
    ;;
adrci*)
    RLWRAP_CMD="adrci"
    RLRWAP_CPL=""
    for f in adrci-commands.completionlist adrci-reserved.completionlist adrci-sqlcommands.completionlist
    do
        [[ -r $RLWRAP_ETC/$f ]] && RLRWAP_CPL="$RLRWAP_CPL -f $RLWRAP_ETC/$f"
    done
    if [[ -n $ORACLE_BASE ]]
    then
        oracle_base=$(echo $ORACLE_BASE | tr '/' ',')
        if [[ ! -s $RLWRAP_TMP/adrcihomes.$oracle_base.completion ]]
        then
            adrci exec="SHOW HOMES" | grep -v "^ADR Homes" >$RLWRAP_TMP/adrcihomes.$oracle_base.completion
            [[ $? -ne 0 ]] && rm $RLWRAP_TMP/adrcihomes.$oracle_base.completion
        fi
    fi
    [[ -r $RLWRAP_TMP/adrcihomes.$oracle_base.completion ]] && RLRWAP_CPL="$RLRWAP_CPL -f $RLWRAP_TMP/adrcihomes.$oracle_base.completion"
    
    ;;
*)
    echo "error> unknown command $script_name. exit."
    exit 1
    ;;
esac        

# check for local completionlist
[[ -f $RLWRAP_ETC_SITE/$RLWRAP_CMD.completionlist ]] && RLRWAP_CPL="-f $RLWRAP_ETC_SITE/$RLWRAP_CMD.completionlist $RLRWAP_CPL"

# execute rlwrap command
if [[ "$script_name" == "sqlplus"* && "${UNAME}" == 'linux' ]]
then
    exec $RLWRAP_BIN -g "(connect|identified|CONNECT|IDENTIFIED)" -b "" -H $RLWRAP_LOG/$RLWRAP_CMD-$(hostname).history $RLRWAP_CPL $RLWRAP_CMD $*
else
    exec $RLWRAP_BIN -b "" -H $RLWRAP_LOG/$RLWRAP_CMD-$(hostname).history $RLRWAP_CPL $RLWRAP_CMD $*
fi

exit $?

# end of the code block
}
