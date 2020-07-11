#!/bin/bash

# sudo apt-get install -y unzip jq
set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
git clone https://github.com/kaparora/vault-k8s-demo-python-mysql-webapp.git /usr/src/webapp
sudo chown -R azureuser:azureuser /usr/src/webapp
export LC_ALL=C
sudo apt update && sudo apt install -y python3-pip unzip jq
pip3 install mysql-connector-python hvac flask

VAULT_ZIP="vault.zip"
VAULT_URL="${vault_download_url}"
curl --silent --output /tmp/$${VAULT_ZIP} $${VAULT_URL}
unzip -o /tmp/$${VAULT_ZIP} -d /usr/local/bin/
chmod 0755 /usr/local/bin/vault
chown azureuser:azureuser /usr/local/bin/vault
mkdir -pm 0755 /etc/vault.d
mkdir -pm 0755 /opt/vault
chown azureuser:azureuser /opt/vault



cat << EOF > /lib/systemd/system/vault.service
[Unit]
Description=Vault Agent
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/local/bin/vault
ExecStart=/usr/local/bin/vault agent -config /etc/vault.d/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=azureuser
Group=azureuser
[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /usr/src/webapp/app/config/config.ini.tpl
[DEFAULT]
LogLevel = DEBUG

[DATABASE]
Address=${mysql_addr}
Port=3306
{{ with secret "data_protection/database/creds/vault-demo-app" -}}
User={{ .Data.username }}@${mysql_name}
Password={{ .Data.password }}
{{- end }}
Database=my_app

[VAULT]
Enabled = True
InjectToken = True
DynamicDBCreds = False
ProtectRecords = False
Address = ${vault_addr}
Namespace = dev
KeyPath = data_protection/transit
KeyName = customer-key
Transform = True
TransformPath = data_protection/transform
SSNRole = ssn
TransformMaskingPath = data_protection/masking/transform
CCNRole = ccn
EOF


cat << EOF > /etc/vault.d/config.hcl
vault {
  address = "${vault_addr}"
}

auto_auth {
        method "azure" {
                mount_path = "auth/azure"
                namespace = "${vault_namespace}"
                config = {
                        resource = "https://management.azure.com/"
                        role = "dev-role"
                }
        }
        sink "file" {
                config = {
                path = "/usr/src/webapp/app/config/token"
       }
   }
}
cache {
        use_auto_auth_token = true
}


listener "tcp" {
         address = "127.0.0.1:8100"
         tls_disable = true
}

template {
  source      = "/usr/src/webapp/app/config/config.ini.tpl"
  destination = "/usr/src/webapp/app/config/config.ini"
}
EOF


sudo chmod 0664 /lib/systemd/system/vault.service
systemctl daemon-reload
sudo chown -R azureuser:azureuser /etc/vault.d
sudo chmod -R 0644 /etc/vault.d/*


systemctl enable vault
systemctl start vault

sleep 120

cd /usr/src/webapp/app
python3 app.py
