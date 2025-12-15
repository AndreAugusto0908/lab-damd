#!/bin/bash
aws --endpoint-url=http://localhost:4566 s3 mb s3://shopping-images
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name tasks-queue
aws --endpoint-url=http://localhost:4566 sns create-topic --name tasks-topic
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name Tasks \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST