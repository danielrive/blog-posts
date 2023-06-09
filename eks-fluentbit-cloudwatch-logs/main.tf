data "aws_caller_identity" "current" {} 



module "networking" {
  source             = "./modules/networking"
  project_name       = var.project_name
  region             = var.region
  environment        = var.environment
  cidr               = "10.100.0.0/16"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  private_subnets    = ["10.100.0.0/22", "10.100.64.0/22", "10.100.128.0/22"]
  db_subnets         = ["10.100.4.0/22", "10.100.68.0/22", "10.100.132.0/22"]
  public_subnets     = ["10.100.32.0/22", "10.100.96.0/22", "10.100.160.0/22"]
}

### KMS Key to encrypt kubernetes resources
module "kms_key_eks" {
  source              = "./modules/kms"
  region              = var.region
  environment         = var.environment
  project_name        = var.project_name
  name                = "eks"
  key_policy          = data.aws_iam_policy_document.kms_key_policy_encrypt_logs.json
  enable_key_rotation = true
}

module "eks_cluster" {
  source                       = "./modules/eks"
  environment                  = var.environment
  region                       = var.region
  project_name                 = var.project_name
  cluster_version              = "1.26"
  subnet_ids                   = module.networking.main.private_subnets
  desired_nodes                = 1
  min_nodes                    = 1
  max_nodes                    = 1
  retention_control_plane_logs = 7
  instance_type_worker_nodes   = var.environment == "develop" ? ["t3.small"] : ["t3.medium"]
  AMI_for_worker_nodes         = "AL2_x86_64"
  max_instances_node_group     = 1
  min_instances_node_group     = 1
  private_endpoint_api         = true
  public_endpoint_api          = true
  kms_arn                      = module.kms_key_eks.kms_arn
}