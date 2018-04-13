terraform {
  required_version = ">= 0.11.6"
}

variable "ssh_public_key" {}
variable "myip" {}

variable "db_username" {
  default = "adminuser"
}

variable "db_password" {
  default = "passw0rd"
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_key_pair" "deploy" {
  key_name   = "deploy"
  public_key = "${var.ssh_public_key}"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.3.0.0/16"
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
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.3.0.0/24"
  availability_zone = "ap-southeast-2a"
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_subnet" "db" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.3.1.0/24"
  availability_zone = "ap-southeast-2a"
}

resource "aws_subnet" "db2" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "10.3.2.0/24"
  availability_zone = "ap-southeast-2b"
}

resource "aws_security_group" "public" {
  name        = "public"
  description = "public"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.myip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "db"
  description = "db"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = ["${aws_subnet.db.id}", "${aws_subnet.db2.id}"]
}

resource "aws_network_interface" "public" {
  subnet_id       = "${aws_subnet.public.id}"
  security_groups = ["${aws_security_group.public.id}"]
}

resource "aws_network_interface" "db" {
  subnet_id       = "${aws_subnet.db.id}"
  security_groups = ["${aws_security_group.db.id}"]
}

resource "aws_eip" "host" {
  vpc               = true
  network_interface = "${aws_network_interface.public.id}"
}

resource "aws_instance" "host" {
  instance_type           = "t2.micro"
  key_name                = "${aws_key_pair.deploy.key_name}"
  monitoring              = true
  disable_api_termination = false
  ami                     = "ami-d38a4ab1"
  availability_zone       = "ap-southeast-2a"

  network_interface {
    network_interface_id = "${aws_network_interface.public.id}"
    device_index         = 0
  }

  network_interface {
    network_interface_id = "${aws_network_interface.db.id}"
    device_index         = 1
  }

  root_block_device {
    volume_size = 20
  }

  provisioner "file" {
    source      = "playbook.yml"
    destination = "/tmp/playbook.yml"

    connection {
      user = "ubuntu"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y software-properties-common",
      "sudo apt-add-repository -y -u ppa:ansible/ansible",
      "sudo apt-get install -y ansible",
      "PYTHONUNBUFFERED=1 ansible-playbook /tmp/playbook.yml --become --connection=local --inventory=localhost, --extra-vars='hosts=all'",
      "rm -f /tmp/playbook.yml",
    ]

    connection {
      user = "ubuntu"
    }
  }
}

output "public_dns" {
  value = "${aws_instance.host.public_dns}"
}

resource "aws_db_instance" "mydb" {
  allocated_storage                   = 20
  availability_zone                   = "ap-southeast-2a"
  auto_minor_version_upgrade          = true
  backup_retention_period             = 7
  backup_window                       = "17:20-17:50"
  copy_tags_to_snapshot               = false
  engine                              = "postgres"
  engine_version                      = "9.6.6"
  iam_database_authentication_enabled = false
  identifier                          = "mydb"
  instance_class                      = "db.t2.micro"
  iops                                = 0
  license_model                       = "postgresql-license"
  maintenance_window                  = "sat:14:15-sat:14:45"
  monitoring_interval                 = 0
  multi_az                            = false
  name                                = "mydb"
  option_group_name                   = "default:postgres-9-6"
  parameter_group_name                = "default.postgres9.6"
  port                                = 5432
  publicly_accessible                 = false
  skip_final_snapshot                 = true
  storage_encrypted                   = false
  storage_type                        = "gp2"
  username                            = "${var.db_username}"
  password                            = "${var.db_password}"
  db_subnet_group_name                = "${aws_db_subnet_group.default.name}"
  vpc_security_group_ids              = ["${aws_security_group.db.id}"]
}

output "address" {
  value = "${aws_db_instance.mydb.address}"
}
