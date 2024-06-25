provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "jpeg_bucket" {
  bucket = "my-jpeg-bucket"
}

resource "aws_s3_bucket" "bmp_bucket" {
  bucket = "my-bmp-bucket"
}

resource "aws_s3_bucket" "gif_bucket" {
  bucket = "my-gif-bucket"
}

resource "aws_s3_bucket" "png_bucket" {
  bucket = "my-png-bucket"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for S3 access"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.jpeg_bucket.arn}/*",
          "${aws_s3_bucket.bmp_bucket.arn}/*",
          "${aws_s3_bucket.gif_bucket.arn}/*",
          "${aws_s3_bucket.png_bucket.arn}/*"
        ]
      },
      {
        Action = "logs:*"
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "image_converter" {
  filename         = "LambdaImageConverter/function.zip"
  function_name    = "image_converter"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "LambdaImageConverter::LambdaImageConverter.Function::FunctionHandler"
  runtime          = "dotnet8"
  source_code_hash = filebase64sha256("LambdaImageConverter/function.zip")
  timeout          = 30

  environment {
    variables = {
      BMP_BUCKET = aws_s3_bucket.bmp_bucket.bucket
      GIF_BUCKET = aws_s3_bucket.gif_bucket.bucket
      PNG_BUCKET = aws_s3_bucket.png_bucket.bucket
    }
  }
}

resource "aws_s3_bucket_notification" "jpeg_notification" {
  bucket = aws_s3_bucket.jpeg_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_converter.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_to_call_lambda
  ]
}

resource "aws_lambda_permission" "allow_s3_to_call_lambda" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_converter.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.jpeg_bucket.arn
}

