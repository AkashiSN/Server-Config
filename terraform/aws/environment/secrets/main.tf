locals {
  vault_files = toset([
    "common",
    "argocd",
    "juicefs",
    "postgres_backup",
    "immich",
    "nextcloud",
  ])
}

# ansible-vault 暗号化済みの vault_<group>.yml をそれぞれ SecureString として置く。
# 各ファイルは Standard 上限 (4KB) 未満になるようグループ分割済み。
resource "aws_ssm_parameter" "ansible_vault_files" {
  for_each    = local.vault_files
  name        = "/ansible/k3s_cluster/vault/${each.key}"
  description = "ansible-vault encrypted vault_${each.key}.yml for k3s_cluster group_vars"
  type        = "SecureString"
  value       = file("${path.module}/../../../../ansible/group_vars/k3s_cluster/vault_${each.key}.yml")
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
