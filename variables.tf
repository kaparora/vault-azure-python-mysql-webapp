variable "prefix" {
  default = "kapil"
}

variable "location" {
  default = "westeurope"
}

variable "owner" {
  default = "kapil"
}

variable "client_secret" {
  default = ""
}
variable "client_id" {
  default = ""
}

variable "object_id" {
  default = ""
}
variable "subscription_id" {
  default = ""
}

variable "tenant_id" {
  default = ""
}

variable "vault_download_url" {
  default = "https://releases.hashicorp.com/vault/1.4.3+ent/vault_1.4.3+ent_linux_amd64.zip"
}
variable "public_key" {
  default = ""
}
variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "mysql_username" {
  default = "vault"
}
variable "mysql_password" {
  default = ""
}
variable "license" {
  default=""
}
variable "vault_namespace" {
  default="root"
}
