# Add provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

# Create dynamo policy so that Teleport can write to DynamoDB
resource "aws_iam_policy" "dynamo-policy" {
  name = "teleport-dynamodb-iam"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ClusterStateStorage",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:BatchWriteItem",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:DescribeStream",
          "dynamodb:UpdateItem",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:CreateTable",
          "dynamodb:DescribeTable",
          "dynamodb:GetShardIterator",
          "dynamodb:GetItem",
          "dynamodb:UpdateTable",
          "dynamodb:GetRecords",
          "dynamodb:UpdateContinuousBackups"
        ],
        "Resource" : [
          "arn:aws:dynamodb:${var.aws_region}:${var.account_id}:table/teleport-backend",
          "arn:aws:dynamodb:${var.aws_region}:${var.account_id}:table/teleport-backend/stream/*"
        ]
      },
      {
        "Sid" : "ClusterEventsStorage",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:CreateTable",
          "dynamodb:BatchWriteItem",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:PutItem",
          "dynamodb:DescribeTable",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTable",
          "dynamodb:UpdateContinuousBackups"
        ],
        "Resource" : [
          "arn:aws:dynamodb:${var.aws_region}:${var.account_id}:table/teleport-events",
          "arn:aws:dynamodb:${var.aws_region}:${var.account_id}:table/teleport-events/index/*"
        ]
      }
    ]
  })
}

# Create S3 policy so that Teleport can write to S3 bucket
resource "aws_iam_policy" "s3-policy" {
  name = "teleport-s3-iam"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "BucketActions",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketVersioning",
          "s3:ListBucketVersions",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucket",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketVersioning",
          "s3:CreateBucket"
        ],
        "Resource" : "arn:aws:s3:::teleport-bucket"
      },
      {
        "Sid" : "ObjectActions",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObjectVersion",
          "s3:GetObjectRetention",
          "s3:*Object",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ],
        "Resource" : "arn:aws:s3:::teleport-bucket/*"
      }
    ]
  })
}

# Create EC2 Describe policy needed for Teleport-Node connectivity
resource "aws_iam_policy" "ec2-policy" {
  name = "teleport-ec2-iam"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement": [
        {
            "Sid": "DescribeEc2Instances",
            "Effect": "Allow",
            "Action": "ec2:DescribeInstances",
            "Resource": "*"
        }
    ]
  })
}

# Connect policies to role attached to EKS nodes
data "aws_iam_role" "role" {
  name = var.eks_node_group_role
}

resource "aws_iam_role_policy_attachment" "dynamo-att" {
  role     = data.aws_iam_role.role.name
  policy_arn = aws_iam_policy.dynamo-policy.arn
}

resource "aws_iam_role_policy_attachment" "s3-att" {
  role     = data.aws_iam_role.role.name
  policy_arn = aws_iam_policy.s3-policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2-att" {
  role     = data.aws_iam_role.role.name
  policy_arn = aws_iam_policy.ec2-policy.arn
}