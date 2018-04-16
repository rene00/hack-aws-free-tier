data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name                  = "lambda"
  assume_role_policy    = "${data.aws_iam_policy_document.lambda_assume.json}"
  force_detach_policies = true
}

data "aws_iam_policy_document" "apigateway_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigateway" {
  name                  = "apigateway"
  assume_role_policy    = "${data.aws_iam_policy_document.apigateway_assume.json}"
  force_detach_policies = true
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda" {
  name   = "lambda"
  policy = "${data.aws_iam_policy_document.lambda.json}"
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = "${aws_iam_role.lambda.name}"
  policy_arn = "${aws_iam_policy.lambda.arn}"
}

data "aws_iam_policy_document" "apigateway" {
  statement {
    actions = [
      "lambda:InvokeFunction",
    ]

    resources = [
      "${aws_lambda_function.main.arn}",
    ]
  }
}

resource "aws_iam_policy" "apigateway" {
  name   = "apigateway"
  policy = "${data.aws_iam_policy_document.apigateway.json}"
}

resource "aws_iam_role_policy_attachment" "apigateway" {
  role       = "${aws_iam_role.apigateway.name}"
  policy_arn = "${aws_iam_policy.apigateway.arn}"
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/source"
  output_path = "${path.module}/source.zip"
}

resource "aws_lambda_function" "main" {
  filename         = "source.zip"
  source_code_hash = "${data.archive_file.source.output_base64sha256}"
  function_name    = "Main"
  handler          = "test.main_handler"
  role             = "${aws_iam_role.lambda.arn}"
  runtime          = "python3.6"
  timeout          = 2
  memory_size      = 128

  environment {
    variables = {
      HASH = "${base64sha256(file("source/test.py"))}"
    }
  }
}

resource "aws_api_gateway_rest_api" "main" {
  name        = "main"
}

resource "aws_api_gateway_resource" "main" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  parent_id   = "${aws_api_gateway_rest_api.main.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "main" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.main.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "main" {
  rest_api_id             = "${aws_api_gateway_rest_api.main.id}"
  resource_id             = "${aws_api_gateway_method.main.resource_id}"
  http_method             = "${aws_api_gateway_method.main.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.main.invoke_arn}"
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_rest_api.main.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_root" {
  rest_api_id             = "${aws_api_gateway_rest_api.main.id}"
  resource_id             = "${aws_api_gateway_method.proxy_root.resource_id}"
  http_method             = "${aws_api_gateway_method.proxy_root.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.main.invoke_arn}"
}

resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    "aws_api_gateway_integration.main",
    "aws_api_gateway_integration.proxy_root",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  stage_name  = "main"
}

resource "aws_lambda_permission" "apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.main.arn}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_deployment.main.execution_arn}/*"
}

output "base_url" {
  value = "${aws_api_gateway_deployment.main.invoke_url}"
}
