嘗試寫一個 shell script 腳本，用來印出 EC2 相關資訊。
提供您的腳本（github repo）。

使用方式及輸出格式如下：

$ sh ./ec2_info.sh i-0123456789abcdef0

=== EC2 Information ===
Instance ID : i-0123456789abcdef0
Instance Type : t3.micro
State : running
Launch Time : 2025-01-01T10:00:00Z
VPC ID : vpc-12345678
Subnet ID : subnet-98765432
Private IP : 10.0.1.25
Public IP : 3.115.22.53


# Shell Script 取得 AWS 資訊

本目錄提供兩個腳本，可依 **Instance ID** 或 **Instance Name（tag:Name）** 查詢 EC2 基本資訊。

## 前置需求

- 已安裝 [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- 已設定 AWS 認證（`aws configure` 或環境變數）

## 腳本一：ec2_info.sh（Bash）

適用於 **Git Bash** 或 Linux/macOS 終端。

### 用法

```bash
./ec2_info.sh <Instance-ID 或 Instance-Name>
```

### 範例

- 依 Instance ID 查詢：
  ```bash
  ./ec2_info.sh i-06aa2a031a66c9418
  ```

- 依 Instance Name（tag:Name）查詢：
  ```bash
  ./ec2_info.sh my-web-server
  ```

### 執行環境

- **建議**：在 **Git Bash** 中執行（路徑與 `aws` 較穩定）。
- 若在 PowerShell 中執行，需先 `cd` 到本目錄，再在 **Git Bash** 視窗執行上述指令。

---

## 腳本二：get_ec2_info.ps1（PowerShell）

適用於 **Windows PowerShell**。

### 用法

```powershell
.\get_ec2_info.ps1 <Instance-ID 或 Instance-Name>
```

### 範例

- 依 Instance ID 查詢：
  ```powershell
  .\get_ec2_info.ps1 i-06aa2a031a66c9418
  ```

- 依 Instance Name 查詢：
  ```powershell
  .\get_ec2_info.ps1 my-web-server
  ```

### 執行環境

- 在 **PowerShell** 中執行，且需已安裝 AWS CLI 並在 PATH 中（PowerShell 通常會繼承 Windows 的 PATH）。

---

## 輸出欄位

兩個腳本皆會輸出下列欄位：

| 欄位       | 說明           |
|------------|----------------|
| Instance ID | EC2 執行個體 ID |
| Instance Type | 執行個體類型（如 t3.micro） |
| State | 狀態（如 running、stopped） |
| Launch Time | 啟動時間 |
| VPC ID | 所屬 VPC ID |
| Subnet ID | 所屬 Subnet ID |
| Private IP | 私有 IP |
| Public IP | 公有 IP（無則顯示 N/A） |

---

## 查詢邏輯

- 參數以 **`i-` 開頭**：視為 **Instance ID**，使用 `--instance-ids` 查詢。
- 其餘：視為 **Instance Name**，使用 `--filters Name=tag:Name,Values=<參數>` 查詢。
- 若有多台同名（相同 tag:Name）的 EC2，會全部列出。
