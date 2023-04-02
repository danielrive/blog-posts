locals {
  lambda_name = "lambda-${var.environemnt}-${var.region}-${random_string.random_suffix.result}"
}

resource "random_string" "random_suffix" {
  length      = 5
  special     = false
  min_numeric = 3
  upper       = false
}

resource "aws_cloudwatch_log_group" "log_group_lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 14
  tags = {
    ExportToS3 = "false"
  }
}

resource "aws_iam_policy" "lambda_Policy" {
  name        = "policy-lambda-${local.lambda_name}"
  path        = "/"
  description = "IAM Policy for lambda to use KMS and RDS"
  policy = templatefile("${path.module}/iamPolicies/lambda_policy.json", {
    LOGS_GROUP_ARN = aws_cloudwatch_log_group.log_group_lambda.arn
    ACCOUNT_ID     = var.account_id
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "role-${local.lambda_name}"
  assume_role_policy = templatefile("${path.module}/iamPolicies/lambda_trusted_role_policy.json",{})
  managed_policy_arns = [aws_iam_policy.lambda_Policy.arn]
}


### Define lambda function ###
data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "${path.module}/python_code/copy-snapshots.py"
  output_path = "copy-snapshots.zip"
}

resource "aws_lambda_function" "copy_rds_snapts" {
  function_name    = local.lambda_name
  description      = "copy rds snapshots"
  filename         = "copy-snapshots.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.9"
  handler          = "copy-snapshots.lambda_handler"
  timeout          = 60
  environment {
    variables = {
      SOURCE_REGION      = var.region
      DESTINATION_REGION = var.destination_region
    }
  }
}

####### Event bridge rule
resource "aws_cloudwatch_event_rule" "event" {
  name          = "event-${var.name}-${var.environment}-${var.region}"
  event_pattern = <<EOF
{
  "source": ["aws.rds"],
  "detail-type": ["RDS DB Snapshot Event"],
  "account": ["${var.account_id}"],
  "region": ["${var.region}"],
  "detail": {
     "SourceType": ["SNAPSHOT"],
      "EventID": ["RDS-EVENT-0091"]
     
    }
}
EOF
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.event.name
  target_id = "target-${var.name}-${var.environment}-${var.region}"
  arn       = aws_lambda_function.copy_rds_snapts.arn

}


resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_rds_snapts.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event.arn
}