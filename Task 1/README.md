【問答題】
1. root user 跟 iam user 的差別？
   - **Root user（根使用者）**：
     - 建立 AWS 帳戶時自動建立，無法刪除
     - 擁有帳戶的完全控制權，可以執行所有操作
     - 可以關閉帳戶、變更帳單資訊、取消服務等
     - 不應在日常操作中使用，僅用於帳戶管理任務
     - 預設沒有 MFA，建議啟用
   
   - **IAM user（IAM 使用者）**：
     - 由 root user 或具有權限的 IAM user 建立
     - 權限由附加的 policy 決定（預設無權限）
     - 可以建立多個，用於不同用途
     - 可以刪除
     - 適合日常操作使用
     - 可以設定 MFA、access key、密碼等

2. user, group, role, policy 彼此間的關係為何？policy 的格式為何？
   - **關係**：
     - **Policy（政策）**：定義權限的文件，包含允許或拒絕的操作
     - **User（使用者）**：可以附加 policy（managed policy 或 inline policy），也可以加入 group
     - **Group（群組）**：可以附加 policy，user 加入 group 後會繼承 group 的 policy
     - **Role（角色）**：可以附加 policy，可以被 user、service、其他 role 擔任（assume）
     - User 和 Role 都可以直接附加 policy，Group 是管理多個 user 權限的便利方式
   
   - **Policy 格式（JSON）**：
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "s3:GetObject",
             "s3:ListBucket"
           ],
           "Resource": [
             "arn:aws:s3:::bucket-name/*",
             "arn:aws:s3:::bucket-name"
           ]
         }
       ]
     }
     ```
     - Version: policy 語言版本
     - Statement: 權限聲明陣列
     - Effect: Allow 或 Deny
     - Action: 允許或拒絕的操作
     - Resource: 適用的資源 ARN

【實作題】
1. 為 root account 創建 MFA 登入。
   - 步驟：在 AWS Console 右上角點擊帳戶名稱（或帳戶 ID）→ Security credentials → Multi-factor authentication (MFA) → Assign MFA device
   - 選擇虛擬 MFA device（如 Google Authenticator）或硬體 MFA device
   - 掃描 QR code 並輸入兩組驗證碼完成設定

2. 創建 aws credential（access key & secret），並且使用 aws cli 嘗試存取 ec2 列表（可以手動創建一台機器）及 s3 列表。
   - **建議做法（最佳實踐）**：先創建一個 IAM user（可給予 AdministratorAccess 權限），然後為該 user 建立 access key
     - 建立 IAM user：IAM Console → Users → Add users → 設定使用者名稱和權限
     - 建立 access key：選擇該 user → Security credentials → Create access key
   - **替代做法（不建議，僅供練習）**：為 root account 建立 access key
     - 在 AWS Console 右上角點擊帳戶名稱 → Security credentials → Access keys → Create access key
     - ⚠️ 注意：為 root account 建立 access key 違反 AWS 安全最佳實踐，因為 root account 有完全權限，access key 洩露風險極高
   - 設定 AWS CLI：`aws configure` 或 `aws configure --profile <profile-name>`
   - 測試命令：
     ```bash
     PS D:\Henry> aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table
        ------------------------------------
        |         DescribeInstances        |
        +----------------------+-----------+
        |  i-0e56365f80cc78a5e |  running  |
        +----------------------+-----------+
     PS D:\Henry> aws s3 ls
     2026-01-16 06:45:55 my-s3-20260116
     ```

3. 創建一個 user，名為 `s3_readonly`，並且僅給予其 s3 readonly 的權限，為此 user 創建 credential 並且設定在 aws 內，使用不同的 profile 可以指定用哪個 credential 跟 aws 溝通，驗證方式為嘗試取得 ec2 及 s3 的列表，其中一個會失敗。
   - 建立 user：IAM Console → Users → Add users → 使用者名稱 `s3_readonly`
   - 附加 policy：`AmazonS3ReadOnlyAccess`（AWS managed policy）
   - 建立 access key 並設定到新 profile：`aws configure --profile s3_readonly`
   - 測試：
      ```bash
      PS D:\Henry> aws s3 ls --profile s3_readonly
      2026-01-16 06:45:55 my-s3-20260116
      PS D:\Henry> aws ec2 describe-instances --profile s3_readonly
      
      An error occurred (UnauthorizedOperation) when calling the DescribeInstances operation: You are not authorized to perform this operation. User: arn:aws:iam::128265486056:user/s3_readonly is not authorized to perform: ec2:DescribeInstances because no identity-based policy allows the ec2:DescribeInstances action
      ```

4. 嘗試創建 inline policy，使 s3_readonly 這個使用者在某個時間後就無法存取 s3，並且回答 inline policy 可以用在哪些地方。
   - 建立 inline policy：Users → s3_readonly → Permissions → Add inline policy → JSON
   - Policy 範例（使用 Condition 限制時間）：
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Deny",
           "Action": "s3:*",
           "Resource": "*",
           "Condition": {
             "DateGreaterThan": {
               "aws:CurrentTime": "2026-01-16T03:42:00Z"
             }
           }
         }
       ]
     }
     ```
   - 執行結果：
      ```
      PS D:\Henry> aws s3 ls --profile s3_readonly
      2026-01-16 06:45:55 my-s3-20260116
      PS D:\Henry> aws s3 ls --profile s3_readonly

      An error occurred (AccessDenied) when calling the ListBuckets operation: User: arn:aws:iam::128265486056:user/s3_readonly is not authorized to perform: s3:ListAllMyBuckets with an explicit deny in an identity-based policy
      ```
   - **Inline policy 可以用在**：
     - User（使用者）
     - Group（群組）
     - Role（角色）
   - 與 Managed policy 的差別：Inline policy 直接附加在單一實體上，無法重用；Managed policy 可以附加到多個實體並重用

5. 嘗試創建 EC2，並且為其創建一個 S3ReadOnlyRole 的 role，使 ec2 上可以使用 aws cli（或是 sdk） 存取 s3 資源，並且不需要設定 access key。（這題可以用 aws linux，因為他有內建 aws cli）
   - 建立 Role：IAM Console → Roles → Create role → AWS service → EC2
   - 附加 policy：`AmazonS3ReadOnlyAccess`
   - 建立 EC2 instance：選擇 AMI（如 Amazon Linux 2），在 Configure Instance 步驟的 IAM role 選擇剛建立的 role
   - 連線到 EC2 後測試：
      ```bash
      PS D:\Henry\桌面\AWS\og-aws-camp> ssh -i "$env:USERPROFILE\.aws\keys\henry-ec2-key.pem" ec2-user@43.212.145.91
      The authenticity of host '43.212.145.91 (43.212.145.91)' can't be established.
      ED25519 key fingerprint is SHA256:LUSQUqAvyqfvtWplWAseYxj7n4XItKPbJe4o7Z3pE3o.
      This key is not known by any other names.
      Are you sure you want to continue connecting (yes/no/[fingerprint])? y
      Please type 'yes', 'no' or the fingerprint: yes
      Warning: Permanently added '43.212.145.91' (ED25519) to the list of known hosts.
        ,     #_
        ~\_  ####_        Amazon Linux 2023
        ~~  \_#####\
        ~~     \###|
        ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
        ~~       V~' '->
          ~~~         /
            ~~._.   _/
              _/ _/
            _/m/'
      [ec2-user@ip-172-31-22-208 ~]$ aws s3 ls
      2026-01-15 22:45:55 my-s3-20260116
      ```
   - 原理：
     - EC2 instance 透過 instance profile 自動取得臨時 credentials，無需手動設定 access key
     - Instance Profile 是 IAM Role 的「容器」，讓 EC2 instance 可以擔任（assume）IAM Role
      ```
      Instance Profile (容器)
        └── IAM Role (實際的權限)
            └── Policies (具體的權限)
      ```
     - 建立 IAM Role 時，AWS 會自動建立對應的 Instance Profile（名稱通常與 Role 相同）
     - EC2 透過 Instance Metadata Service (IMDS) 從 Instance Profile 取得臨時 credentials
     - 這些臨時 credentials 有 Role 附加的 policy 權限（如 AmazonS3ReadOnlyAccess）
     - Instance Profile 是 IAM Role 與 EC2 之間的橋樑，確保只有 EC2 服務可以使用這個 Role
     - 臨時 credentials 會定期自動更新，比長期 access key 更安全