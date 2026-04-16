研究 AWS IAM Identity Center（舊稱 AWS SSO）[https://aws.amazon.com/tw/iam/identity-center/] 的架構。

請說明 Identity Center user 與一般 iam user 差別在哪？他解決了什麼問題？
嘗試描述若你打算導入 identity center，並且你想使用 Terraform 管理 identity center 的權限，你會怎麼設計 Group 以及 Policy？
若可能，請完成 terraform 實作。

1. terraform 需能管理 group policy 的 binding。
2. 需能管理在不同 aws account 下的權限差異。