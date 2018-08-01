##-----tf_module_dynamodb_ondemand_backup/source/index.py

from __future__ import print_function # Python 2/3 compatibility
import os
import json
import operator
import boto3
print('Loading function')

## global vars
dynamodb = boto3.client('dynamodb')
iam = boto3.client('iam')
table = " "

def num_of_backups(table_name):
    """Return the number of available backups."""
    table_backups = dynamodb.list_backups(TableName=table_name)['BackupSummaries']
    backup_count = len(table_backups)
    return backup_count

def current_backups(table_name):
    """Return the current backup."""
    return dynamodb.list_backups(TableName=table_name)

def get_policy_body():
    """Return the iam policy in json format."""
    policy = {'Version':'2012-10-17'}
    policy['Statement'] = [{'Sid' : 'DenydynamodbDeleteBackup',
                            'Effect': 'Deny',
                            'Action': 'dynamodb:DeleteBackup',
                            'Resource': '*'}]
    policy_json = json.dumps(policy, indent=2)
    return policy_json

def update_role(role_name, iam, iam_policy_name, policy_document):
    """Attach deny dynamodb delete backup policy to iam role"""
    try:
        response = iam.put_role_policy(
            RoleName=role_name,
            PolicyName=iam_policy_name,
            PolicyDocument=policy_document
        )
    except Exception as e:
        print("Failed: " + str(e))
    #print response

def update_iam_user(iam_user_NAME, iam, iam_policy_name, policy_document):
    """Attach deny dynamodb delete backup policy to iam user"""
    try:
        response = iam.put_user_policy(
            UserName=iam_user_NAME,
            PolicyName=iam_policy_name,
            PolicyDocument=policy_document
        )
    except Exception as e:
        print("Failed: " + str(e))
    #print response

def get_iam_users(iam):
    """Return the list of iam users."""
    response = None
    user_names = []
    marker = None

    # By default, only 100 roles are returned at a time.
    # 'Marker' is used for pagination.
    while (response is None or response['IsTruncated']):
        if marker is None:
            response = iam.list_users()
        else:
            response = iam.list_users(Marker=marker)
        users = response['Users']
        for user in users:
            user_names.append(user['UserName'])
        if response['IsTruncated']:
            marker = response['Marker']
    return user_names

def get_iam_roles(iam):
    """Return the list of iam roles."""
    response = None
    role_names = []
    marker = None
    # By default, only 100 roles are returned at a time.
    # 'Marker' is used for pagination.
    while (response is None or response['IsTruncated']):
        if marker is None:
            response = iam.list_roles()
        else:
            response = iam.list_roles(Marker=marker)
        roles = response['Roles']
        for role in roles:
            role_names.append(role['RoleName'])
        if response['IsTruncated']:
            marker = response['Marker']
    return role_names


def lambda_handler(event, context):
    all_tables = (dynamodb.list_tables()['TableNames'])

    # Get backup retention
    backup_retention = os.environ['backup_retention']

    # Get Lambda AllowExecutionRole name
    lambda_exec_role_name = os.environ['lambda_exec_role_name']

    for table in all_tables:
        backup_name = table + "_" + "backuped_by_" + context.function_name
        print ("Taking Backup for {}".format(table))

        dynamodb.create_backup(TableName=table, BackupName=backup_name)
        print ("table {} has {} backups available".format(table, num_of_backups(table)))

        if int(num_of_backups(table)) > int(backup_retention):
            print ("More than {} backup available".format(backup_retention))
            while (int(num_of_backups(table)) > int(backup_retention)):
                available_backups = current_backups(table)
                available_backups['BackupSummaries'].sort(key=operator.itemgetter('BackupCreationDateTime'), reverse=True)

                old_backup = available_backups['BackupSummaries'][-1]
                old_backup_arn = old_backup['BackupArn']

                print ("Deleting Old Backup, ARN: {}".format(old_backup_arn))
                dynamodb.delete_backup(BackupArn=old_backup_arn)
            print ("Cleanup complete")

    print ("Updating iam Users policy to DenydynamodbDeleteBackup")
    # Get iam policy document to Deny dynamodb:DeleteBackup in json format
    policy_document = get_policy_body()

    # Get all the iam users list
    iam_users = get_iam_users(iam)
    for iam_user in iam_users:
        # Attach policy to each iam user
        update_iam_user(iam_user, iam, "DenydynamodbDeleteBackup", policy_document)
        print ("Attached deny policy to '{}' IAM user' ".format(iam_user))

    print ("Updating iam Roles policy to DenydynamodbDeleteBackup")
    # Get all the iam roles list
    iam_roles = get_iam_roles(iam)
    for iam_role in iam_roles:
        # Skip attaching deny policy to lambda role
        if iam_role == lambda_exec_role_name:
            continue
        # Attach policy to each iam role
        update_role(iam_role, iam, "DenydynamodbDeleteBackup", policy_document)
        print ("Attached deny policy to '{}' IAM role' ".format(iam_role))

    print("Done")
    print ("=====================================================") #Format
