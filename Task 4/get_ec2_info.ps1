param (
    [Parameter(Mandatory=$true)]
    [string]$Target
)

# 判斷是 ID 還是 Name（--instance-ids 與 ID 需分開傳，否則 aws 會當成一個選項）
if ($Target -like "i-*") {
    $FilterArgs = @("--instance-ids", $Target)
} else {
    $FilterArgs = @("--filters", "Name=tag:Name,Values=$Target")
}

# 執行 AWS CLI 並獲取 JSON 格式（PowerShell 處理 JSON 非常強大）
$data = aws ec2 describe-instances @FilterArgs --query "Reservations[*].Instances[*]" --output json | ConvertFrom-Json

# 輸出為巢狀陣列 Reservations[].Instances[]，需雙層迴圈逐台印出
foreach ($reservation in $data) {
    foreach ($instance in $reservation) {
    Write-Host "=== EC2 Information ===" -ForegroundColor Cyan
    Write-Host "Instance ID   : $($instance.InstanceId)"
    Write-Host "Instance Type : $($instance.InstanceType)"
    Write-Host "State         : $($instance.State.Name)"
    Write-Host "Launch Time   : $($instance.LaunchTime)"
    Write-Host "VPC ID        : $($instance.VpcId)"
    Write-Host "Subnet ID     : $($instance.SubnetId)"
    Write-Host "Private IP    : $($instance.PrivateIpAddress)"
    
    $pubIp = if ($instance.PublicIpAddress) { $instance.PublicIpAddress } else { "N/A" }
    Write-Host "Public IP     : $pubIp"
    Write-Host "------------------------"
    }
}