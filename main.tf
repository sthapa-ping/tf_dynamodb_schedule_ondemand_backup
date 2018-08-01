#-----tf_module_dynamodb_ondemand_backup/main.tf

# Lambda Exec Role
resource "aws_iam_role" "tf_dynamodb_ondemand_backup_lambda_exec_role" {
  name = "tf_dynamodb_ondemand_backup_lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "tf_dynamodb_ondemand_backup_lambda_exec_role_policy" {
  name = "tf_dynamodb_ondemand_backup_lambda_exec_role_policy"
  role = "${aws_iam_role.tf_dynamodb_ondemand_backup_lambda_exec_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1444729759000",
            "Effect": "Allow",
            "Action": [
                "dynamodb:CreateBackup",
                "dynamodb:ListTables",
                "dynamodb:ListBackups",
                "dynamodb:DeleteBackup",
                "iam:AttachRolePolicy",
                "iam:AttachUserPolicy",
                "iam:PutUserPolicy",
                "iam:PutRolePolicy",
                "iam:ListRoles",
                "iam:ListUsers",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "lambda:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# Cloudwatch Events Role
resource "aws_iam_role" "tf_dynamodb_ondemand_backup_cloudwatch_events_role" {
  name = "tf_dynamodb_ondemand_backup_cloudwatch_events_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "tf_dynamodb_ondemand_backup_cloudwatch_events_role_policy" {
  name = "tf_dynamodb_ondemand_backup_cloudwatch_events_role_policy"
  role = "${aws_iam_role.tf_dynamodb_ondemand_backup_cloudwatch_events_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchEventsInvocationAccess",
            "Effect": "Allow",
            "Action": [
                "lambda:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

# Cloudwatch event rule that listens for table create & table delete
resource "aws_cloudwatch_event_rule" "tf_dynamodb_ondemand_backup_cw_event_listener" {
  name        = "tf_dynamodb_ondemand_backup_cw_event_listener"
  description = "CloudWatch Events Rule to React to DynamoDB Create and DeleteTable events"
  role_arn    = "${aws_iam_role.tf_dynamodb_ondemand_backup_cloudwatch_events_role.arn}"
  schedule_expression = "${var.backup_schedule}"
}

# Cloudwatch table listener target
resource "aws_cloudwatch_event_target" "tf_dynamodb_ondemand_backup_cw_event_target" {
  target_id = "tf_dynamodb_ondemand_backup_cw_event_target"
  rule      = "${aws_cloudwatch_event_rule.tf_dynamodb_ondemand_backup_cw_event_listener.name}"
  arn       = "${aws_lambda_function.tf_dynamodb_ondemand_backup_lambda_function.arn}"
}

# Give Cloudwatch events permission to call the backup function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.tf_dynamodb_ondemand_backup_lambda_function.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.tf_dynamodb_ondemand_backup_cw_event_listener.arn}"
}

# Compress source dir
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "source"
    output_path = "${var.dynamodb_ondemand_backup_path}"
}

# The ensure backup lambda function
resource "aws_lambda_function" "tf_dynamodb_ondemand_backup_lambda_function" {
  description      = "Lambda to listen to CloudWatch Event for periodic and automated DynamoDB on-demand backups."
  filename         = "${var.dynamodb_ondemand_backup_path}"
  function_name    = "${var.lambda_ondemand_backup_function_name}"
  role             = "${aws_iam_role.tf_dynamodb_ondemand_backup_lambda_exec_role.arn}"
  handler          = "index.lambda_handler"
  #source_code_hash = "${base64sha256(file("${var.dynamodb_ondemand_backup_path}"))}"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime          = "python2.7"
  timeout          = 300

  environment {
    variables = {
      region                          = "${var.aws_region}"
      backup_retention                = "${var.backup_retention}"
      backup_schedule                 = "${var.backup_schedule}"
      lambda_exec_role_name           = "${aws_iam_role.tf_dynamodb_ondemand_backup_lambda_exec_role.name}"
    }
  }
}
