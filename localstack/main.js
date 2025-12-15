const express = require('express');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

const app = express();
app.use(express.json({ limit: '50mb' }));

const s3 = new S3Client({
  endpoint: 'http://localhost:4566',
  region: 'us-east-1',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' },
  forcePathStyle: true
});

const dynamodb = new DynamoDBClient({
  endpoint: 'http://localhost:4566',
  region: 'us-east-1',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' }
});

const sqs = new SQSClient({
  endpoint: 'http://localhost:4566',
  region: 'us-east-1',
  credentials: { accessKeyId: 'test', secretAccessKey: 'test' }
});

app.post('/upload-task', async (req, res) => {
  try {
    const { image, taskName, taskDescription } = req.body;
    const taskId = Date.now().toString();
    const imageKey = `${taskId}.jpg`;
    
    // 1. Upload S3
    const imageBuffer = Buffer.from(image, 'base64');
    await s3.send(new PutObjectCommand({
      Bucket: 'shopping-images',
      Key: imageKey,
      Body: imageBuffer,
      ContentType: 'image/jpeg'
    }));
    
    // 2. Salvar DynamoDB
    await dynamodb.send(new PutItemCommand({
      TableName: 'Tasks',
      Item: {
        id: { S: taskId },
        name: { S: taskName },
        description: { S: taskDescription },
        imageUrl: { S: imageKey },
        createdAt: { S: new Date().toISOString() }
      }
    }));
    
    // 3. Enviar mensagem SQS
    await sqs.send(new SendMessageCommand({
      QueueUrl: 'http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/tasks-queue',
      MessageBody: JSON.stringify({ taskId, taskName, action: 'created' })
    }));
    
    res.json({ success: true, taskId, imageUrl: imageKey });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, '0.0.0.0', () => console.log('Backend rodando na porta 3000'));