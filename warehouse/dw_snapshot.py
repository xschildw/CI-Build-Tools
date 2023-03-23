import boto3
import time
import base64
import json
import os
import datetime
import pymysql.cursors
from botocore.exceptions import ClientError

# Usage:
#
#
# To launch and grant access to the snapshot:
#
#     dw_snapshot.launch_and_grant_access_to_snapshot(
#         'pw15yb22o9ndju5',
#         'prod-datawarehouse-db-dbsubnetgroup-1t9z88xhk4qlh',
#         'warehouse',
#         'test',
#         'kimyen.ladia@sagebase.org',
#         'WW-70',
#         'dw-master-user-creds',
#         'kimyen_db_user',
#         'kimyen_db_password'
#     )
#
# To shutdown a snapshot:
#
#     dw_snapshot.shutdown_snapshot('test')
#
#

REGION_NAME = "us-east-1"
DEFAULT_DW_TTL_DAYS = 21


def launch_and_grant_access_to_snapshot(warehouse_instance, subnet_group, db_name, new_instance_name,
                                        user_email, project, secret_name, username, password):
    expiration_date_iso = get_expiration_date_iso(datetime.date.today())
    rds = get_rds_client(REGION_NAME)
    snapshot = launch_snapshot(
        rds,
        warehouse_instance,
        subnet_group,
        new_instance_name,
        user_email,
        project,
        expiration_date_iso
    )
    endpoint = get_endpoint(
        rds,
        new_instance_name
    )
    print("A snapshot is launched and available at {}.".format(endpoint))

    master_username, master_password = get_secret(secret_name, REGION_NAME)
    grant_access(
        endpoint,
        master_username,
        master_password,
        db_name,
        username,
        password
    )
    print("A user is created and granted access to {}.".format(db_name))


def get_secret(secret_name, region_name):
    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    # In this sample we only handle the specific exceptions for the 'GetSecretValue' API.
    # See https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
    # We rethrow the exception by default.

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            # An error occurred on the server side.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            # You provided an invalid value for a parameter.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            # You provided a parameter value that is not valid for the current state of the resource.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            # We can't find the resource that you asked for.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
    else:
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if 'SecretString' in get_secret_value_response:
            creds = json.loads(get_secret_value_response['SecretString'])
            return creds['username'], creds['password']
        else:
            print(base64.b64decode(get_secret_value_response['SecretBinary']))


def get_rds_client(region_name):
    return boto3.client(
        service_name='rds',
        region_name=region_name
    )


def grant_access(endpoint, master_username, master_password, db_name, username, password):
    # Connect to the database
    connection = pymysql.connect(host=endpoint,
                                 user=master_username,
                                 password=master_password,
                                 charset='utf8mb4',
                                 cursorclass=pymysql.cursors.DictCursor)

    try:
        with connection.cursor() as cursor:
            sql_create = "CREATE USER '{}'@'%' IDENTIFIED BY '{}'".format(username, password)
            cursor.execute(sql_create)
        connection.commit()
        with connection.cursor() as cursor:
            sql_grant = "GRANT ALL ON {}.* TO '{}'@'%' WITH GRANT OPTION".format(db_name, username)
            cursor.execute(sql_grant)
        connection.commit()
    finally:
        connection.close()


def get_endpoint(rds, db_id):
    while True:
        instances = rds.describe_db_instances(DBInstanceIdentifier=db_id)
        try:
            return instances['DBInstances'][0]['Endpoint']['Address']
        except KeyError:
            time.sleep(30)


def shutdown_snapshot(db_id):
    rds = get_rds_client(REGION_NAME)
    rds.delete_db_instance(
        DBInstanceIdentifier=db_id,
        SkipFinalSnapshot=True
    )


def launch_snapshot(rds, db_id, subnet_group, instance_name, owner_email, project, expiration_date_iso):
    latest = get_latest_snapshot(rds, db_id)

    return rds.restore_db_instance_from_db_snapshot(
        DBInstanceIdentifier=instance_name,
        DBSnapshotIdentifier=latest['DBSnapshotIdentifier'],
        DBSubnetGroupName=subnet_group,
        PubliclyAccessible=False,
        AutoMinorVersionUpgrade=True,
        Tags=[
            {'Key': 'OwnerEmail', 'Value': owner_email},
            {'Key': 'Project', 'Value': project},
            {'Key': 'ExpirationDate', 'Value': expiration_date_iso}
        ]
    )


def get_latest_snapshot(rds, db_id):
    response = rds.describe_db_snapshots(
        DBInstanceIdentifier=db_id
    )

    try:
        latest = response['DBSnapshots'][0]
    except (KeyError, IndexError) as e:
        print("No snapshots found. Please check that the provided DBInstanceIdentifier has snapshots.")
        raise e

    for snapshot in response['DBSnapshots']:
        if latest['SnapshotCreateTime'] < snapshot['SnapshotCreateTime']:
            latest = snapshot

    return latest


def get_rds_instances():
    rds = get_rds_client(REGION_NAME)
    resp = rds.describe_db_instances()
    instances = resp['DBInstances']
    return instances


# Get RDS instances that are tagged with ExpirationDate and where that date is passed
def get_expired_instances_ids(instances):
    cur_date = datetime.date.today()
    exp_instance_ids = []
    for instance in instances:
        instance_id = instance['DBInstanceIdentifier']
        tag_list = instance['TagList']
        # is there an ExpirationDate tag
        for tag in tag_list:
            if 'ExpirationDate' == tag['Key']:
                exp_date_iso = tag['Value']
                if 'none' == exp_date_iso:
                    break
                else:
                    exp_date = datetime.date.fromisoformat(exp_date_iso)
                    if cur_date > exp_date:
                        exp_instance_ids.append(instance_id)
                    break
    return exp_instance_ids


# Return a string
#   'None' if no expiration time
#   'ActualExpirationDate' == now() + DW_TTL_DAYS if defined
def get_expiration_date_iso(d):
    ttl = os.environ.get('DW_TTL_DAYS')
    if ttl is None:
        ttl_days = DEFAULT_DW_TTL_DAYS
    else:
        ttl_days = int(ttl)
    if ttl_days == 0:
        exp_date = 'none'
    else:
        exp_date = (d + datetime.timedelta(days=ttl_days)).isoformat()
    return exp_date


def shutdown_expired_instances():
    instances = get_rds_instances()
    expired_ids = get_expired_instances_ids(instances)
    for expired_id in expired_ids:
        print(f'Deleting RDS instance {expired_id}')

