 provider "aws" {
     region      = "<AWS REGION>"
     profile     = "<AWS PROFILE>"
 }

# terraform {
#     backend "s3" {
#         bucket  = "<BUCKET NAME>"
#         key     = "terraform/tf_dynamodb_schedule_ondemand_backup/tfstate"
#         region  = "<REGION>"
#     }
#}
