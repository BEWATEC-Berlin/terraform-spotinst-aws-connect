output "spot_account_id" {
    description = "spot account_id"
    value = spotinst_account_aws.spot_acct.id
}

output "response_body" {
  value = data.http.externalid.response_body
}
output "status_code" {
  value = data.http.externalid.status_code
}

output "externalid" {
  value = local.externalids[0]
}

output "externalid" {
  value = local.externalids[0]
}

output "test" {
  value = null_resource.externalid
}