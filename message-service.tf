resource "aws_sqs_queue" "terraform_catalog_queue" {
  name                      = "terraform-catalog-queue"
  max_message_size          = 262144 ## 256 KiB
  message_retention_seconds = 300    ## 5 Minutes.

  tags = {
    Environment = "Catalog-api-code"
  }
}


resource "aws_sns_topic" "topic_catalog_emit" {
  name = "terrafrom-catalog-emit"
}




resource "aws_sns_topic_subscription" "listen_catalog_emit" {
  topic_arn = aws_sns_topic.topic_catalog_emit.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.terraform_catalog_queue.arn
  
  depends_on = [ aws_sns_topic.topic_catalog_emit, 
  aws_sqs_queue.terraform_catalog_queue ]
}





resource "aws_sqs_queue_policy" "allow_consume_sns_topic" {
  queue_url = aws_sqs_queue.terraform_catalog_queue.id
  policy = jsonencode({
    Version : "2012-10-17",
    Id : "__default_policy_ID",
    Statement : [
      {
        "Sid" : "__owner_statement",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : var.iam_user_aws
        },
        "Action" : "SQS:*",
        "Resource" : aws_sqs_queue.terraform_catalog_queue.arn
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "sns.amazonaws.com"
        },
        "Action" : "sqs:SendMessage",
        "Resource" : aws_sqs_queue.terraform_catalog_queue.arn,
        "Condition" : {
          "ArnEquals" : {
            "aws:SourceArn" : aws_sns_topic.topic_catalog_emit.arn
          }
        }
      }
    ]
  })
}



###
## S3 Bucket: ##
###

resource "aws_s3_bucket" "catalog_items_bucket" {
  bucket = "terraformer-s3bucket-catalog-item"
  ## values will be decide automatically[...] region = "us-east-1"

  tags = {
    Name        = "terraformer-s3bucket-catalog-item"
    Environment = "Catalog-api-code"
  }
}


###
## Lambda config ##
###


resource "aws_lambda_function" "lambda_consumer_api_catalog" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "node_src.zip"
  function_name = "lambdaConsumerApiCatalog"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"


  runtime = "nodejs18.x"
}




data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}



resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [aws_iam_policy.FullS3.arn, aws_iam_policy.ExecuteSQSQueue.arn]
}


resource "aws_iam_policy" "FullS3" {
  name = "S3FullAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:*", "s3-object-lambda:*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}





resource "aws_iam_policy" "ExecuteSQSQueue" {
  name = "ExecuteSQSQueue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
              "sqs:ReceiveMessage",
              "sqs:DeleteMessage",
              "sqs:GetQueueAttributes",
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
          ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}





resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.terraform_catalog_queue.arn
  function_name    = aws_lambda_function.lambda_consumer_api_catalog.arn
}