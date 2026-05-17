locals {
  vault_yml_path = "${path.module}/../../../../ansible/group_vars/k3s_cluster/vault.yml"
}

# ansible-vault 暗号化済みの vault.yml をそのまま SecureString として置く。
# vault.yml を手動で更新したあと `terraform apply` で差分を反映する。
# tier = "Advanced" は vault.yml が Standard 上限 4KB を超えた場合に備える (Advanced は最大 8KB)。
resource "aws_ssm_parameter" "ansible_vault_yml" {
  name        = "/ansible/k3s_cluster/vault_yml"
  description = "ansible-vault encrypted vault.yml for k3s_cluster group_vars"
  type        = "SecureString"
  tier        = "Advanced"
  value       = file(local.vault_yml_path)
}

# vault パスワードは Terraform 管理外。初回 apply 後に AWS コンソール / CLI で実値を入れる。
resource "aws_ssm_parameter" "ansible_vault_password" {
  name        = "/ansible/k3s_cluster/vault_password"
  description = "ansible-vault password (value is managed manually)"
  type        = "SecureString"
  value       = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}
