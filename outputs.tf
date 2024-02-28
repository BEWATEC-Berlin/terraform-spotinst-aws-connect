output "spot_account_id" {
    description = "spot account_id"
    value = spotinst_account_aws.spot_acct.id
}

output "test" {
  value = data.external.externalid
}