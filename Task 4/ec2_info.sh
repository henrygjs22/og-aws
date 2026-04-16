#!/bin/bash

QUERY_TARGET=$1

if [ -z "$QUERY_TARGET" ]; then
    echo "Usage: sh ./ec2_info.sh <Instance-Name-or-ID>"
    exit 1
fi

# 判斷輸入的是 ID (i-開頭) 還是名稱
if [[ $QUERY_TARGET == i-* ]]; then
    FILTER="--instance-ids $QUERY_TARGET"
else
    FILTER="--filters Name=tag:Name,Values=$QUERY_TARGET"
fi

# 執行查詢
aws ec2 describe-instances $FILTER \
    --query 'Reservations[*].Instances[*].{
        ID: InstanceId,
        Type: InstanceType,
        State: State.Name,
        Launch: LaunchTime,
        Vpc: VpcId,
        Subnet: SubnetId,
        PriIP: PrivateIpAddress,
        PubIP: PublicIpAddress
    }' \
    --output text | while read -r ID Launch PriIP PubIP State Subnet Type Vpc; do
    
    # 這裡改成 while read 確保即便查到多台同名的機器也能全部印出
    echo "=== EC2 Information ==="
    echo "Instance ID   : $ID"
    echo "Instance Type : $Type"
    echo "State         : $State"
    echo "Launch Time   : $Launch"
    echo "VPC ID        : $Vpc"
    echo "Subnet ID     : $Subnet"
    echo "Private IP    : $PriIP"
    echo "Public IP     : ${PubIP:-N/A}"
    echo "------------------------"
done