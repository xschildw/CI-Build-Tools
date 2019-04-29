import boto3
import time

# Usage:
#
#     rds = dw_snapshot.get_rds_client()
#
# To launch a snapshot:
#
#     dw_snapshot.launch_snapshot(
#         rds,
#         'pw15yb22o9ndju5', 
#         'prod-datawarehouse-db-dbsubnetgroup-1t9z88xhk4qlh',
#         'test',
#         'kimyen.ladia@sagebase.org',
#         'WW-70'
#     )
#
# To get the snapshot endpoint:
#
#     endpoint = dw_snapshot.get_endpoint(
#         rds,
#         'test'
#     )
#
# To grant access to the snapshot:
#
#     dw_snapshot.grant_access(
#         rds,
#         endpoint,
#         'master_username',
#         'master_password',
#         'username',
#         'password'
#     )
#
# To shutdown a snapshot:
#
#     dw_snapshot.shutdown_snapshot(
#         rds,
#         'test'
#     )
#
#

def get_rds_client():
    return boto3.client('rds')


def grant_access(endpoint, master_username, master_password, username, password):
    return None


def get_endpoint(rds, db_id):
    while True:
        instances = rds.describe_db_instances(DBInstanceIdentifier=db_id)
        try:
            return instances['DBInstances'][0]['Endpoint']['Address']
        except KeyError:
            time.sleep(30)


def shutdown_snapshot(rds, db_id):
    
    rds.delete_db_instance(
        DBInstanceIdentifier=db_id,
        SkipFinalSnapshot=True
        )


def launch_snapshot(rds, db_id, subnet_group, instance_name, owner_email, project):

    latest = get_latest_snapshot(rds, db_id)
    
    return rds.restore_db_instance_from_db_snapshot(
        DBInstanceIdentifier=instance_name,
        DBSnapshotIdentifier=latest['DBSnapshotIdentifier'],
        DBSubnetGroupName=subnet_group,
        PubliclyAccessible=False,
        AutoMinorVersionUpgrade=False,
        Tags=[
            {'Key':'OwnerEmail', 'Value':owner_email},
            {'Key':'Project', 'Value':project}
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

    
