# DynamoDB Backup Scheduler

A Python lambda function to back up all the DynamoDB tables and update all IAM users and roles policy to deny deleting backups.

# DynamoDB On-demand Backup
  - Feature built into the DynamoDB service to allows user to take a full backup of a table at a point in time.
  - Backups are Retained until you explicitly delete them.
  - No native functionality that allows you to schedule these backups regularly

# Requirements
  - Allow users to define the schedule
  - Allow users to define the retention
  - Apply following policy to all IAM users and roles except AWS managed roles,

  ```
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Action": "dynamodb:DeleteBackup",
              "Resource": "*",
              "Effect": "Deny",
              "Sid": "DenydynamodbDeleteBackup"
          }
      ]
  }
  ```

# AWS Services
    - Amazon CloudWatch
        * ScheduledEvents

    - AWS Lambda Function
        * dynamodb.create_backup(TableName=table, BackupName=backup_name)
        * dynamodb.delete_backup(BackupArn=old_backup_arn)
            -> available_backups sort by BackupCreationDateTime
            -> num_of_backups(table)) > int(backup_retention)

        * Update IAM user/role Deny dynamodb:DeleteBackup

    - DynamoDB
        * Table(s)
        * Backups


# Backup strategy (Terraform Variables)
By default, backup retention is set to 30,

```
variable "backup_retention" {
  default = "30"
}
```

And scheduled to run daily (24 hours),

```
variable "backup_schedule" {
  default = "rate(24 hours)"
}
```

To overwrite the default backup strategy please follow Amazon CloudWatch schedule expressions,

https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html


# Pros & Cons

Pros
  - No impact on performance
  - Backups taken in very little time
  - No limit on backups
  - Restores are very straight forward

Cons
  - Backups are full snapshots only (no incremental options)
  - You can only restore to a new DynamoDB table
  - No ability to backup to a separate account (Essential for Disaster Recovery in case of security breach)


# Todo

  - Attach deny policy instead of inline
  - Allow user to define table name
