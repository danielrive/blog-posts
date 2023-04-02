data "aws_caller_identity" "current" {} 

module "lambda_copy_rds_snaps" {
    source              = "../modules/copy_rds_snapshots"
  region               = "us-west-2"
  environment          = "developer"
  name                 = "copy-rds-snapshots"
  account_id           = data.aws_caller_identity.current.id
  destination_region   = "us-east-1"
}