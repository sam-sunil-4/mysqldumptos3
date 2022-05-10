#!/bin/bash

AWS=$(which aws)

mysql -N -e 'show databases' |
        while read dbname; 
        do
                mysqldump --complete-insert --routines --triggers --single-transaction "$dbname" > /path/to/directory/"$dbname".sql;
        done

tar -zcvf /location/of/file/mysql-dump-$(date +%Y-%m-%d-%H).tar.gz /path/to/directory/

if [ -z $AWS ]
then
        echo "Please configure aws cli first using aws configure"
else
        aws s3 mv /location/of/file/mysql-dump-$(date +%Y-%m-%d-%H).tar.gz s3://name_of_s3_bucket/
fi

