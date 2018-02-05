#!/usr/bin/env bash
instanceId=$1

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
