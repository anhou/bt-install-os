#!/bin/bash
if [ $# -lt 2 ]
then
    echo "Calculate listed files total size in specific directory"
    echo "Two arguments, first is the directory to search, second is a file include files list"
    exit 1
fi

SUM=0
cat $2 | while read line
do
    echo $line
    VALUE=`find $1 -name $line | xargs  wc -c | awk 'BEGIN{FS=" "}{print $1}'`
    SUM=`expr $SUM + $VALUE`
    echo $SUM
done
