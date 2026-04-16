#!/bin/bash
set -eux

dnf update -y
dnf install -y nginx

cat >/usr/share/nginx/html/index.html <<'EOF'
<html>
  <head><title>business-vpc nginx</title></head>
  <body>
    <h1>Hello from business-vpc private nginx</h1>
    <p>If you can see this from Client VPN, the lab works.</p>
  </body>
</html>
EOF

systemctl enable nginx
systemctl restart nginx