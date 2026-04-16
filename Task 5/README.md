此任務須先學習 terraform 用法後才能做，用 Terraform 以及 VPC Module，快速完成此任務。

## 【問答題】

嘗試了解 Client VPN 跟 Site to Site VPN 差別及分別的使用情境。

### ✅ Client VPN（人 → AWS）

- 給「個人電腦」連進 AWS
- 你 laptop → AWS
- 用 OpenVPN client 連
- 類似公司 VPN

- 使用情境：
  - 工程師連公司內網
  - debug internal service
  - 連 private EC2

### ✅ Site-to-Site VPN (網路 → 網路)

- 兩個「網路」互連
- 公司機房 ↔ AWS VPC
- 整個網段互通

- 使用情境：
  - 混合雲（on-prem + AWS）
  - IDC ↔ cloud


根據此文件 [https://docs.aws.amazon.com/zh_tw/vpn/latest/clientvpn-admin/cvpn-getting-started.html]，完成 Client VPN 的網路架構。

基於第一題，今天公司內部有兩個 VPC（network-vpc & business-vpc），分別部署內部系統及業務相關服務。

嘗試創建這兩個 vpc，並且嘗試使用 transit gateway（或 peering），透過 client VPN（從 laptop 上的 VPN client），連到 network-vpc。

為了驗證網路架構正確，您需要在 business-vpc 創建一個 nginx instance，並透過私有 IP 從自己的電腦上呼叫該 nginx 服務（ex. curl <business-instance ipv4 ip>:80），並取得 html 結果。

**Transit Gateway 費用稍高，做完練習切記刪除資源**

**首先建立憑證(用 Windows bash 會有問題，在 AWS Cloudshell執行)**

```bash
git clone https://github.com/OpenVPN/easy-rsa.git
cd easy-rsa/easyrsa3

./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass # 可能需要修改
./easyrsa build-client-full client1 nopass # 可能需要修改
```

會得到：(實際檔名不一定長這樣)

```
ca.crt
server.crt
server.key
client1.crt
client1.key
```

以上五個檔案下載到本地同一個資料夾

到 AWS 的 ACM → Import certificate

- certificate body → server.crt
- private key → server.key
- chain → ca.crt

記下 ARN，把 ARN 填進 tfvars 的 server_certificate_arn 和 root_certificate_chain_arn，然後 terraform apply

**下載 VPN config**

去 AWS → VPC → Client VPN Endpoint → 點進剛剛建立的 endpoint → Download client configuration

會得到一個 .ovpn 檔，記得跟剛剛憑證產生的檔案放在同一個資料夾，用記事本編輯 .ovpn 檔，最後面加這段：

```
<cert>
-----BEGIN CERTIFICATE-----
（用記事本查看並複製貼上 client1.crt 的 BEGIN CERTIFICATE 和 END CERTIFICATE 中間的文字）
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
（用記事本查看並複製貼上 client1.key 的 BEGIN CERTIFICATE 和 END CERTIFICATE 中間的文字）
-----END PRIVATE KEY-----
</key>
```

接著安裝 OpenVPN GUI → 匯入剛剛的 .ovpn 檔 → 按 connect

最後用 EC2 的 private ip 成功連到 Nginx

```
PS D:\Henry\桌面\og-aws\Task 5> curl.exe http://10.20.1.244:80
<html>
  <head><title>business-vpc nginx</title></head>
  <body>
    <h1>Hello from business-vpc private nginx</h1>
    <p>If you can see this from Client VPN, the lab works.</p>
  </body>
</html>
```
