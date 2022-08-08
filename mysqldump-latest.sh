#!/bin/bash

##----Declaring variables.----##
AWS=$(which aws)
TXT=$(cat .aws/credentials)
MYSQL=$(which mysql)
BKPDISK=$( du -sc /var/lib/mysql | awk 'FNR==1{ print $1 }' )


##Before executing the script make sure you enable which kind of service you need by selecting from below.

S3SYNC=0            #set this equals to 1 if you need to move your DB backups to AMAZON S3 BUCKET otherwise keep it as 0.
RSYNC=0             #set this equals to 1 if you need to move your DB backups to any other server otherwise keep it as 0.

##----#Declaring the functions#----##



#Function-1 To check lifecycle policy file exists or not.
retentionfors3 () {
#setting up a retention policy. If you need retention policy to be 5 days put the value 5 at the value field of Days in the json file.
if [ -f lcp.json ]
then
       aws s3api put-bucket-lifecycle --bucket bkpbc --lifecycle-configuration file://lcp.json
else
        echo "Please create an external lifecycle policy JSON file inorder to maintain retenion in S3 bucket" && exit
fi
}



#Function-2 To Move backup To S3
S3 () {
#aws s3 mb s3://s3_bucket_name

if [ -z $TXT ]
then
        if [ -z $AWS ]
        then
                echo "Please install AWS CLI using apt-get install awscli"
        else
                echo "Please configure aws cli first using aws configure"
        fi
else
BKP_NAME= #enter the bucket name here if already own a bucket or else create one and put the name here in order to move the backup to the same bucket always.
        if [ -z $BKP_NAME ]
        then
                        read -p "You dint specified a bucket name in the script. Input one : " BUKP_NAME
                        CHK=$(aws s3api head-bucket --bucket $BUKP_NAME && echo "exist")
                        if [[ ! -z $CHK ]]
                        then
                                echo "Bucket Exist's"
                                aws s3 sync /root/tar/ s3://$BUKP_NAME/
                                retentionfors3
                        else
                                read -p "No such bucket exist's here. Do you want to create one? " yn
                                case $yn in
                                        [Yy]* ) aws s3 mb s3://$BUKP_NAME && aws s3 sync /root/tar/ s3://$BUKP_NAME/ && retentionfors3;;
                                        [Nn]* ) exit;;
                                        * ) echo "Please enter Y/N." && exit;;
                                esac
                        fi
        else
                aws s3 sync /root/tar/ s3://$BKP_NAME/
                retentionfors3
        fi
fi
}



#Function-3 To move backup to another server
#neccessary function for sync.
function diskcheck {
        ssh USER@IP df /home | awk 'FNR==2{print $4}'
}

DISK=$(diskcheck)

sync () {
if (( "$DISK" > "$BKPDISK" ));
then
        rsync -avzh /root/tar/ root@IP:/home/backups/

        #Retention period as default is 7(ie files older than 7 days of the script execution will be deleted) use the preferred value instead of 7.

        ssh USER@IP 'find /home/backups/mysql-dump* -mtime +7 | xargs rm'
else
        echo "The server doesn't have enough disk space. Please clear some disk first"
        exit
fi
}



#Function-4 To check if the directory exists or not
checkdir () {
if [ -d /root/dump/ ]
then
        return 1
else
        mkdir /root/dump
fi
}



#Function-5 To check MySql installation and remaining MySql processes.
mysqlproc () {
if [ -z $MYSQL ]
then
        echo "Please install MySql service first"
else
        mysql -N -e 'show databases' |
        while read dbname;
                do
                        mysqldump --complete-insert --routines --triggers --single-transaction "$dbname" > /root/dump/"$dbname".sql;
                done
        mkdir /root/tar/
        tar -zcvf /root/tar/mysql-dump$(date +%Y-%m-%d).tar.gz /root/dump/
fi
}


##----#function declaration until here#----##



if [ $S3SYNC == 0 ] && [ $RSYNC == 0 ]
then
        echo "Please select where to move your backups first by editing the script"
elif [ $S3SYNC == 1 ] && [ $RSYNC == 0 ]
then
        checkdir
        mysqlproc
        S3
elif [ $S3SYNC == 0 ] && [ $RSYNC == 1 ]
then
        checkdir
        mysqlproc
        sync
else
        checkdir
        mysqlproc
        S3
        sync
fi

#To remove the files from the system inorder to save disk
find /root/tar/mysql-dump* -mtime +1 | xargs rm
