#-----tf_module_dynamodb_ondemand_backup/outputs.tf

 output "cloudwatch_event_role_arn" {
   value = "${aws_iam_role.tf_dynamodb_ondemand_backup_cloudwatch_events_role.arn}"
 }
 output "lambda_exec_role_arn" {
   value = "${aws_iam_role.tf_dynamodb_ondemand_backup_lambda_exec_role.arn}"
 }
 output "lambda_function_arn" {
   value = "${aws_lambda_function.tf_dynamodb_ondemand_backup_lambda_function.arn}"
 }
