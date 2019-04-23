import boto3

# Usage:
#     launch_snapshot.launch_snapshot(
#         'pw15yb22o9ndju5', 
#         'prod-datawarehouse-db-dbsubnetgroup-1t9z88xhk4qlh',
#         'test',
#         'kimyen.ladia@sagebase.org',
#         'WW-70'
#     )
#


def launch_snapshot(db_id, subnet_group, instance_name, owner_email, project):

    rds = boto3.client('rds')
    # for local testing
    # rds = boto3.Session(profile_name='kimdw').client('rds')

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


def get_latest_snapshot(rds_client, db_id):

    response = rds_client.describe_db_snapshots(
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

    
