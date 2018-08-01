#-----tf_module_dynamodb_ondemand_backup/variables.tf

variable "aws_region" {
  default     = "ap-southeast-2"
}
variable "dynamodb_ondemand_backup_path" {
  default = "dynamodb_ondemand_backup.zip"
}
variable "lambda_ondemand_backup_function_name" {
  default = "DynamoOnDemandBackup"
}
variable "backup_retention" {
  default = "30"
}
variable "backup_schedule" {
  default = "rate(24 hours)"
}
