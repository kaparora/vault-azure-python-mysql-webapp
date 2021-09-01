#!/bin/bash

# sudo apt-get install -y unzip jq
set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sudo apt update && sudo apt install -y unzip jq

VAULT_ZIP="vault.zip"
VAULT_URL="${vault_download_url}"
curl --silent --output /tmp/$${VAULT_ZIP} $${VAULT_URL}
unzip -o /tmp/$${VAULT_ZIP} -d /usr/local/bin/
chmod 0755 /usr/local/bin/vault
chown azureuser:azureuser /usr/local/bin/vault
mkdir -pm 0755 /etc/vault.d
mkdir -pm 0755 /opt/vault
chown azureuser:azureuser /opt/vault

export VAULT_ADDR=http://127.0.0.1:8200

cat << EOF > /lib/systemd/system/vault.service
[Unit]
Description=Vault Agent
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/local/bin/vault
ExecStart=/usr/local/bin/vault server -config /etc/vault.d/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=azureuser
Group=azureuser
[Install]
WantedBy=multi-user.target
EOF


cat << EOF > /etc/vault.d/config.hcl
storage "file" {
  path = "/opt/vault"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
seal "azurekeyvault" {
  client_id      = "${client_id}"
  client_secret  = "${client_secret}"
  tenant_id      = "${tenant_id}"
  vault_name     = "${vault_name}"
  key_name       = "${key_name}"
}
ui=true
disable_mlock = true
EOF


sudo chmod 0664 /lib/systemd/system/vault.service
systemctl daemon-reload
sudo chown -R azureuser:azureuser /etc/vault.d
sudo chmod -R 0644 /etc/vault.d/*

cat << EOF > /etc/profile.d/vault.sh
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
EOF

systemctl enable vault
systemctl start vault

sudo cat << 'EOF' > /tmp/webapppolicy.hcl
path "data_protection/database/creds/vault-demo-app" {
    capabilities = ["read"]
}

path "data_protection/database/creds/vault-demo-app-long" {
    capabilities = ["read"]
}

path "data_protection/transit/encrypt/customer-key" {
    capabilities = ["create", "read", "update"]
}

path "data_protection/transit/decrypt/customer-key" {
    capabilities = ["create", "read", "update"]
}

path "data_protection/transform/encode/ssn" {
    capabilities = ["create", "read", "update"]
}

path "data_protection/transform/decode/ssn" {
    capabilities = ["create", "read", "update"]
}

path "data_protection/masking/transform/encode/ccn" {
    capabilities = ["create", "read", "update"]
}

EOF

sudo cat << 'EOF' > /tmp/azure_auth.sh
set -v
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator init -format=json > vault.txt
cat vault.txt | jq -r .root_token > vaulttoken
pwd
export VAULT_TOKEN=$(cat vaulttoken)
vault write sys/license text="${license}"

vault namespace create ${vault_namespace}
export VAULT_NAMESPACE=${vault_namespace}
vault policy write webapp /tmp/webapppolicy.hcl

vault auth enable azure

vault write auth/azure/config tenant_id="${tenant_id}" resource="https://management.azure.com/" client_id="${client_id}" client_secret="${client_secret}"

vault write auth/azure/role/dev-role policies="webapp" bound_subscription_ids="${subscription_id}" bound_resource_groups="${resource_group_name}"

vault secrets enable -path=data_protection/database database

# Configure the database secrets engine to talk to MySQL
vault write data_protection/database/config/wsmysqldatabase \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(${mysql_endpoint})/" \
    allowed_roles="vault-demo-app","vault-demo-app-long" \
    username="${mysql_username}" \
    password="${mysql_password}"

# Rotate root password
#vault write  -force data_protection/database/rotate-root/wsmysqldatabase

# Create a role with a longer TTL
vault write data_protection/database/roles/vault-demo-app-long \
    db_name=wsmysqldatabase \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON my_app.* TO '{{name}}'@'%';" \
    default_ttl="3h" \
    max_ttl="24h"

# Create a role with a shorter TTL
vault write data_protection/database/roles/vault-demo-app \
    db_name=wsmysqldatabase \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON my_app.* TO '{{name}}'@'%';" \
    default_ttl="3m" \
    max_ttl="6m"

#test and generate dynamic username password
vault read data_protection/database/creds/vault-demo-app

echo "Database secret engine with muysql plugin configured "

echo "Enabling the vault transit secrets engine..."

# Enable the transit secret engine
vault secrets enable  -path=data_protection/transit transit

# Create our customer key
vault write  -f data_protection/transit/keys/customer-key

# Create our archive key to demonstrate multiple keys
vault write -f data_protection/transit/keys/archive-key

#test and see if encryption works
vault write data_protection/transit/encrypt/customer-key plaintext=$(base64 <<< "my secret data")

vault write data_protection/transit/encrypt/archive-key plaintext=$(base64 <<< "my secret data")

echo "Transit secret engine is setup"
#enable the transform secret engine
vault secrets enable  -path=data_protection/transform transform

#Define a rol ssn with transformation ssn
vault write data_protection/transform/role/ssn transformations=ssn

#create a transformation of type fpe using built in template for social security number and assign role ssn to it that we created earlier
vault write data_protection/transform/transformation/ssn type=fpe template=builtin/socialsecuritynumber tweak_source=internal allowed_roles=ssn
#test if the transformation was created successfully
vault list data_protection/transform/transformation
vault read  data_protection/transform/transformation/ssn
#test if you are able to transform a SSN
vault write data_protection/transform/encode/ssn value=111-22-3333

#enable the transform secret engine for masking
vault secrets enable  -path=data_protection/masking/transform transform

#Define a role ccn with transformation ccn
vault write data_protection/masking/transform/role/ccn transformations=ccn

#create a transformation of type masking using a template defined in next step and assign role ccn to it that we created earlier
vault write data_protection/masking/transform/transformation/ccn \
        type=masking \
        template="card-mask" \
        masking_character="#" \
        allowed_roles=ccn
#create the template for masking
vault write data_protection/masking/transform/template/card-mask type=regex \
        pattern="(\d{4})-(\d{4})-(\d{4})-\d{4}" \
        alphabet="builtin/numeric"
#test if the masking transformation was created successfully
vault list data_protection/masking/transform/transformation
vault read  data_protection/masking/transform/transformation/ccn
#test if you are able to mask a Credit Card number
vault write data_protection/masking/transform/encode/ccn value=1111-2211-3333-1111


vault write auth/azure/login role="dev-role" \
  jwt="$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F'  -H Metadata:true -s | jq -r .access_token)" \
  subscription_id="${subscription_id}" \
  resource_group_name="${resource_group_name}" \
  vm_name="${vault_vm_name}"

EOF


sleep 60

sudo chmod +x /tmp/azure_auth.sh

/tmp/azure_auth.sh