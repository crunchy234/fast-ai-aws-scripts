#! /bin/bash
instanceId=$1
vpcId=$2
internetGatewayId=$3
subnetId=$4
securityGroupId=$5
routeTableId=$6
allocAddr=$7

echo Terminating Instance
aws ec2 terminate-instances --instance-ids $instanceId
aws ec2 wait instance-terminated --instance-ids $instanceId

echo Removing VPC
aws ec2 detach-internet-gateway --vpc-id $vpcId --internet-gateway-id $internetGatewayId
aws ec2 delete-internet-gateway --internet-gateway-id $internetGatewayId
aws ec2 delete-subnet --subnet-id $subnetId
aws ec2 delete-route-table --route-table-id $routeTableId
aws ec2 delete-security-group --group-id $securityGroupId
aws ec2 delete-vpc --vpc-id $vpcId

# remove allocated IP if specified
if [ -z "$allocAddr" ]
then
    aws ec2 release-address --allocation-id $allocAddr
fi
