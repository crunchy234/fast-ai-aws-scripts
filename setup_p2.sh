#! /bin/bash
# Note: The AMI ID assumes you are in the Sydney region to find your image ID search for fastai on aws or see: https://github.com/reshamas/fastai_deeplearn_part1/blob/master/tools/aws_ami_gpu_setup.md
imageId="ami-39ec055b"

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

# The following function will get a unique id of the system based on the MAC addresses of the system network components.
get_unique_id () {
    UNIQUE_ID=$(ip a | sed '\|^ *link[^ ]* |!d;s|||;s| .*||' | sha256sum | awk '{ print $1 }')
    echo "$UNIQUE_ID"
}

export vpcId=`aws ec2 create-vpc --cidr-block 10.0.0.0/28 --query 'Vpc.VpcId' --output text`
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames "{\"Value\":true}"
export internetGatewayId=`aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text`
aws ec2 attach-internet-gateway --internet-gateway-id $internetGatewayId --vpc-id $vpcId
export subnetId=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.0.0/28 --query 'Subnet.SubnetId' --output text`
export routeTableId=`aws ec2 create-route-table --vpc-id $vpcId --query 'RouteTable.RouteTableId' --output text`
aws ec2 associate-route-table --route-table-id $routeTableId --subnet-id $subnetId
aws ec2 create-route --route-table-id $routeTableId --destination-cidr-block 0.0.0.0/0 --gateway-id $internetGatewayId
export securityGroupId=`aws ec2 create-security-group --group-name my-security-group --description "Generated by setup_vpn.sh" --vpc-id $vpcId --query 'GroupId' --output text`
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8888-8898 --cidr 0.0.0.0/0
aws ec2 create-key-pair --key-name "aws-key-$(get_unique_id)" --query 'KeyMaterial' --output text > ~/.ssh/aws-key.pem
chmod 400 ~/.ssh/aws-key.pem

export instanceId=`aws ec2 run-instances --image-id $imageId --count 1 --instance-type p2.xlarge --key-name "aws-key-$(get_unique_id)" --security-group-ids $securityGroupId --subnet-id $subnetId --associate-public-ip-address --block-device-mapping "[ { \"DeviceName\": \"/dev/sda1\", \"Ebs\": { \"VolumeSize\": 128, \"VolumeType\": \"gp2\" } } ]" --query 'Instances[0].InstanceId' --output text`
#export allocAddr=`aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text`

#export assocId=`aws ec2 associate-address --instance-id $instanceId --allocation-id $allocAddr --query 'AssociationId' --output text`
export instanceUrl=`aws ec2 describe-instances --instance-ids $instanceId --query 'Reservations[0].Instances[0].PublicDnsName' --output text`
echo securityGroupId=$securityGroupId
echo subnetId=$subnetId
echo instanceId=$instanceId
echo instanceUrl=$instanceUrl
echo vpcId=$vpcId
echo internetGatewayId=$internetGatewayId

echo Waiting for instance start...
aws ec2 wait instance-running --instance-ids $instanceId
aws ec2 wait instance-status-ok --instance-ids $instanceId

sleep 10 # wait for ssh service to start running too

echo Update git repo and Anaconda env
# Don't worry about the host identification key
ssh -oStrictHostKeyChecking=no -i ~/.ssh/aws-key.pem ubuntu@$instanceUrl "export PATH=~/src/anaconda3/bin:\$PATH ; source activate fastai; cd /home/ubuntu/fastai ; git pull; conda env update"


connectCurrentFileName="$(get_script_dir)/connectCurrent.sh"
sshConnectStr="ssh -i ~/.ssh/aws-key.pem ubuntu@$instanceUrl -L 8888:localhost:8888"
echo Connect: $sshConnectStr
echo "#! /bin/bash" > $connectCurrentFileName
echo $sshConnectStr >> $connectCurrentFileName
chmod +x $connectCurrentFileName

resumeCurrentFileName="$(get_script_dir)/resumeCurrent.sh"
echo "#! /bin/bash" > $resumeCurrentFileName
echo "$(get_script_dir)/resume_p2.sh $instanceId" >> $resumeCurrentFileName
chmod +x $resumeCurrentFileName

# Create termination script
terminateCurrentFileName="$(get_script_dir)/terminateCurrent.sh"
terminateStr="$(get_script_dir)/terminate_p2.sh $instanceId $vpcId $internetGatewayId $subnetId $securityGroupId $routeTableId $allocAddr"
echo "#! /bin/bash" > $terminateCurrentFileName
echo $terminateStr >> $terminateCurrentFileName
echo "rm -- $connectCurrentFileName" >> $terminateCurrentFileName
echo "rm -- $terminateCurrentFileName" >> $terminateCurrentFileName
chmod +x $terminateCurrentFileName

echo To terminate: $terminateCurrentFileName
