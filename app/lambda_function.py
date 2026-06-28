import boto3
import os
from PIL import Image
import io
import json

s3 = boto3.client('s3')
DEST_BUCKET = os.environ['DEST_BUCKET']
SIZES = {
    'thumb': (300, 300),
    'medium': (800, 800),
    'large': (1200, 1200)
}

def lambda_handler(event, context):
    for record in event['Records']:
        src_bucket = record['s3']['bucket']['name']
        src_key = record['s3']['object']['key']
        
        # Skip if already processed
        if src_key.startswith('resized/'):
            continue
            
        try:
            response = s3.get_object(Bucket=src_bucket, Key=src_key)
            img = Image.open(response['Body'])
            
            # Preserve format, convert RGBA to RGB for JPEG
            img_format = img.format
            if img.mode in ("RGBA", "P"): 
                img = img.convert("RGB")
            
            for size_name, dimensions in SIZES.items():
                img_copy = img.copy()
                img_copy.thumbnail(dimensions, Image.LANCZOS)
                
                buffer = io.BytesIO()
                img_copy.save(buffer, img_format, quality=85, optimize=True)
                buffer.seek(0)
                
                dest_key = f"resized/{size_name}/{os.path.basename(src_key)}"
                s3.put_object(
                    Bucket=DEST_BUCKET, 
                    Key=dest_key, 
                    Body=buffer, 
                    ContentType=f'image/{img_format.lower()}'
                )
                
            print(f"Successfully resized {src_key} into {len(SIZES)} versions")
            
        except Exception as e:
            print(f"Error processing {src_key}: {str(e)}")
            raise e
            
    return {'statusCode': 200, 'body': json.dumps('Processing complete')}