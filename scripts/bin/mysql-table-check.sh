#!/bin/bash
#
# #automysqlcheck.sh
#
# This is a small bash script that checks all mysql databases for errors
# and mails a log file to a specified email address. All variables are
# hardcoded for ease of use with cron. Any databases you wish not to check
# should be added to the DBEXCLUDE list, with a space in between each name.
#
# original version by sbray@csc.uvic.ca, UVic Fine Arts 2004
#
# modified by eyechart AT gmail.com and Mickael Sundberg at mickael@pischows.se and Jake Carr jake-+AT+-websitesource-+DOT+-com
# (see Change Log for details)
#
#=====================================================================
# Change Log
#=====================================================================
#
# VER 1.4 - (2010-10-18)
# Added I/O redirection to $LOGFILE
# added flush & lock tables before check
# modified the database exclusion so that it works also with Darwin/Mac OS X
# Modified by Fabrizio La Rosa
# VER 1.3 - (2006-12-02)
# Added --host=$DBHOST in mysql commands, so it's useful for non-localhost situations
# Jake Carr
# VER 1.2 - (2006-10-29)
# Added "\`" arround the tables in $DBTABLES, otherwise it'll create
# errors if tablenames containt characters like -.
# Modified by Mickael Sundberg
# VER 1.1 - (2005-02-22)
# Named script automysqlcheck.sh
# Added PATH variable to make this script more CRON friendly
# Removed the $DBTABLES loop and replaced it with single command
# that executes the CHECK TABLE command on all tables in a given DB
# Changed code to only check MyISAM and InnoDB tables
# Cleaned up output to make the email prettier
# Modified script to skip databases that have no tables
# Modified by eyechart
# VER 1 - (2004-09-24)
# Initial release by sbray@csc.uvic.ca

# system variables (change these according to your system)
PATH=/usr/local/bin:/usr/bin:/bin:$PATH
USER=root
PASSWORD=`cat ~/.mysql`
DBHOST=`hostname`
LOGFILE=/var/log/automysqlcheck.log
MAILTO=root@localhost
TYPE1= # extra params to CHECK_TABLE e.g. FAST
TYPE2=
CORRUPT=no # start by assuming no corruption
DBNAMES="all" # either "all" or a list delimited by space
DBEXCLUDE="" # either "" or a list delimited by space

# I/O redirection...
touch $LOGFILE
exec 6>&1
exec > $LOGFILE # stdout redirected to $LOGFILE
echo -n "AutoMySQLCheck: "
date
echo "---------------------------------------------------------"; echo; echo

# Get our list of databases to check...
if [ "$DBNAMES" = "all" ] ; then
DBNAMES=""
ALLDB="`mysql --host=$DBHOST --user=$USER --password=$PASSWORD --batch -N -e "show databases"`"
for i in $ALLDB ; do
INCLUDEDB=1
for j in $DBEXCLUDE ; do
if [ "$i" = "$j" ] ; then
INCLUDEDB=0
fi
done
if [ $INCLUDEDB -eq 1 ] ; then
DBNAMES=$DBNAMES" "$i
fi
done
fi

# Lock tables
mysql --host=$DBHOST --user=$USER --password=$PASSWORD --batch -N -e "flush tables with read lock; flush logs"
# Run through each database and execute our CHECK TABLE command for all tables
# in a single pass - eyechart
for i in $DBNAMES ; do
# echo the database we are working on
echo "Database being checked:"
echo -n "SHOW DATABASES LIKE '$i'" | mysql -t --host=$DBHOST -u$USER -p$PASSWORD $i; echo

# Check all tables in one pass, instead of a loop
# Use AWK to put in comma separators, use SED to remove trailing comma
# Modified to only check MyISAM or InnoDB tables - eyechart
DBTABLES="`mysql --host=$DBHOST --user=$USER --password=$PASSWORD $i --batch -N -e "show table status;" | awk 'BEGIN {ORS=", " } $2 == "MyISAM" || $2 == "InnoDB"{print "\`" $1 "\`"}' | sed 's/, $//'`"

# Output in table form using -t option
if [ ! "$DBTABLES" ] ; then
echo "NOTE: There are no tables to check in the $i database - skipping..."; echo; echo
else
echo "CHECK TABLE $DBTABLES $TYPE1 $TYPE2" | mysql --host=$DBHOST -t -u$USER -p$PASSWORD $i; echo; echo
fi
done
# Unlock tables
mysql --host=$DBHOST --user=$USER --password=$PASSWORD --batch -N -e "unlock tables"

exec 1>&6 6>&- # Restore stdout and close file descriptor #6

# test our logfile for corruption in the database...
for i in `cat $LOGFILE` ; do
if test $i = "warning" ; then
CORRUPT=no
elif test $i = "error" ; then
CORRUPT=yes
fi
done

# Send off our results...
if test $CORRUPT = "yes" ; then
cat $LOGFILE | mail -s "MySQL CHECK Log ERROR FOUND for $DBHOST-`date`" $MAILTO
#else
#cat $LOGFILE | mail -s "MySQL CHECK Log [PASSED OK] for $DBHOST-`date`" $MAILTO
fi
