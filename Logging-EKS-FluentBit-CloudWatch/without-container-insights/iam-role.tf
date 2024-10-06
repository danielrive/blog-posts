##########################
### CloudWatch Add-on ###
#########################

resource "aws_iam_role" "cloudwatch_role" {
  name               = "cloudwatch-addon-role-${local.eks_cluster_name}-${var.region}"
  path               = "/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${var.account_number}:oidc-provider/${replace(aws_eks_cluster.kube_cluster.identity[0].oidc[0].issuer, "https://", "")}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${replace(aws_eks_cluster.kube_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud": "sts.amazonaws.com",
                    "${replace(aws_eks_cluster.kube_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
                }
            }
        }
    ]
}
EOF
}

## Attach policy 
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_role.name
}
