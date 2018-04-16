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

data "aws_iam_policy_document" "states_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "states" {
  name                  = "states"
  assume_role_policy    = "${data.aws_iam_policy_document.states_assume.json}"
  force_detach_policies = true
}

data "aws_iam_policy_document" "states" {
  statement {
    actions = [
      "lambda:InvokeFunction",
    ]

    resources = [
      "${aws_lambda_function.main.arn}",
      "${aws_lambda_function.error.arn}",
    ]
  }
}

resource "aws_iam_policy" "states" {
  name   = "states"
  policy = "${data.aws_iam_policy_document.states.json}"
}

resource "aws_iam_role_policy_attachment" "states" {
  role       = "${aws_iam_role.states.name}"
  policy_arn = "${aws_iam_policy.states.arn}"
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

resource "aws_lambda_function" "error" {
  filename         = "source.zip"
  source_code_hash = "${data.archive_file.source.output_base64sha256}"
  function_name    = "Error"
  handler          = "test.error_handler"
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

data "template_file" "states" {
  template = "${file("states.json")}"

  vars {
    function_main_arn = "${aws_lambda_function.main.arn}"
    function_error_arn = "${aws_lambda_function.error.arn}"
  }
}

resource "aws_sfn_state_machine" "states" {
  name       = "state"
  role_arn   = "${aws_iam_role.states.arn}"
  definition = "${data.template_file.states.rendered}"
}
