import json
import boto3
import os

def lambda_handler(event, context):
    client = boto3.client('rds',region_name=os.environ["DESTINATION_REGION"])
    
    print ("event received")
    for snapshot_arn in event['resources']:
        arn = snapshot_arn.split(':')
        snapshot_name = arn[7]
        print(snapshot_name)
        print (f'starting copy of ',snapshot_name)
        
        copy_snapshot_response = client.copy_db_snapshot(
            SourceDBSnapshotIdentifier=snapshot_arn,
            TargetDBSnapshotIdentifier='copy-'+snapshot_name,
            Tags=[
                {
                    'Key': 'copy',
                    'Value': 'true'
                },
                {
                    'Key': 'source_region',
                    'Value': os.environ["SOURCE_REGION"]
                }
            ],
            CopyTags=True,
            SourceRegion=os.environ["SOURCE_REGION"]
        )
    return {
        'statusCode': 200,
        'body': json.dumps('snapshot copy was created')
    }