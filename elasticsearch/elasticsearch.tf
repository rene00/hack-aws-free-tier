terraform {
  required_version = ">= 0.11.6"
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "main" {
  route_table_id         = "${aws_route_table.main.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.2.0.0/24"
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_security_group" "public" {
  name        = "public"
  description = "public"
  vpc_id      = "${aws_vpc.main.id}"
}

resource "aws_elasticsearch_domain" "test" {
  domain_name           = "tf-test"
  elasticsearch_version = "6.2"

  cluster_config {
    instance_type  = "t2.small.elasticsearch"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp2"
    volume_size = 10
  }

  access_policies = <<CONFIG
  {
    "Version": "2012-10-17",
    "Statement": [
        {
          "Action": "es:*",
          "Principal": "*",
          "Effect": "Allow",
          "Condition": {
            "IpAddress": {"aws:SourceIp": ["0.0.0.0/0"]}
          }
        }
    ]
  }
CONFIG
}
