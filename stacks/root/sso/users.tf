#############################################
# SSO Users - 기존 IAM Users 기반
#############################################
#
# 봇 계정 (bot-argocd, bot-kubeadm 등)은 IAM 유지
# 사람 계정만 SSO로 전환
#
#############################################

resource "aws_identitystore_user" "users" {
  for_each = var.sso_users

  identity_store_id = local.identity_store_id

  user_name    = each.key
  display_name = each.value.display_name

  name {
    given_name  = split(" ", each.value.display_name)[0]
    family_name = length(split(" ", each.value.display_name)) > 1 ? split(" ", each.value.display_name)[1] : each.key
  }

  emails {
    value   = each.value.email
    primary = true
  }
}

#############################################
# Group Memberships
#############################################

locals {
  # 사용자별 그룹 멤버십을 flat list로 변환
  user_group_memberships = flatten([
    for user_name, user in var.sso_users : [
      for group in user.groups : {
        user_name  = user_name
        group_name = group
      }
    ]
  ])
}

resource "aws_identitystore_group_membership" "memberships" {
  for_each = {
    for membership in local.user_group_memberships :
    "${membership.user_name}-${membership.group_name}" => membership
  }

  identity_store_id = local.identity_store_id
  group_id          = local.group_ids[each.value.group_name]
  member_id         = aws_identitystore_user.users[each.value.user_name].user_id
}
