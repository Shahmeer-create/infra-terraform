const { S3Client } = require("@aws-sdk/client-s3");

// No access keys needed — ECS Task Role provides credentials automatically
const s3Client = new S3Client({
  region: process.env.AWS_REGION || "us-east-1"
});

const bucketName = process.env.S3_PHOTOS_BUCKET || null;

module.exports = { s3Client, bucketName };
