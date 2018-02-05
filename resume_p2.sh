#!/usr/bin/env bash
instanceId=$1

# Get this files directory
get_script_dir () {
     SOURCE="${BASH_SOURCE[0]}"
     # While $SOURCE is a symlink, resolve it
     while [ -h "$SOURCE" ]; do
          DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
          SOURCE="$( readlink "$SOURCE" )"
          # If $SOURCE was a relative symlink (so no "/" as prefix, need to resolve it relative to the symlink base directory
          [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
     done
     DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
     echo "$DIR"
}

aws ec2 start-instances --instance-ids ${instanceId}
export instanceUrl=`aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[0].Instances[0].PublicDnsName' --output text`

# update connect current file
connectCurrentFileName="$(get_script_dir)/connectCurrent.sh"
sshConnectStr="ssh -i ~/.ssh/aws-key.pem ubuntu@$instanceUrl -L 8888:localhost:8888"
echo Connect: $sshConnectStr
echo "#! /bin/bash" > $connectCurrentFileName
echo $sshConnectStr >> $connectCurrentFileName
chmod +x $connectCurrentFileName

echo Waiting for instance start...
aws ec2 wait instance-running --instance-ids $instanceId
aws ec2 wait instance-status-ok --instance-ids $instanceId
