#!/bin/bash

BUCKET_NAME="discogs-wordpress-fm-20250715"
LOCAL_WEBSITE_PATH="/Users/fannymayer/Desktop/IT/Fortbildung Neue Fische/Terraform2/website"
AWS_REGION="eu-central-1"


echo "Syncing website files to S3..."
aws s3 sync "$LOCAL_WEBSITE_PATH" "s3://$BUCKET_NAME" --acl public-read

echo "Website available at:"
echo "http://${BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com"
