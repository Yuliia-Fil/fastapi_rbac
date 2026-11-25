data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

data "aws_route53_zone" "blog" {
  zone_id = var.hosted_zone_id
}

resource "aws_vpc" "blog" {
  cidr_block           = "10.77.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "blog" {
  vpc_id = aws_vpc.blog.id
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.blog.id
  cidr_block = "10.77.0.0/26"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.blog.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blog.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name_prefix = "${var.name}-web-"
  description = "Public HTTP and HTTPS for Ghost"
  vpc_id      = aws_vpc.blog.id
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "host" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Outbound SSM, DNS, updates, registries and certificate issuance"
}

resource "aws_iam_role" "ssm" {
  name_prefix = "${var.name}-ssm-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name_prefix = "${var.name}-ssm-"
  role        = aws_iam_role.ssm.name
}

resource "aws_instance" "blog" {
  ami                         = nonsensitive(data.aws_ssm_parameter.ubuntu.value)
  instance_type               = "t4g.medium"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  user_data                   = file("${path.module}/user-data.sh.tftpl")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  tags = { Name = var.name }

  lifecycle {
    # Host updates are applied in place. A newly published AMI must not replace blog data.
    ignore_changes = [ami]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.host,
  ]
}

resource "aws_eip" "blog" {
  domain   = "vpc"
  instance = aws_instance.blog.id

  depends_on = [aws_internet_gateway.blog]
}

resource "aws_route53_record" "blog" {
  zone_id         = data.aws_route53_zone.blog.zone_id
  name            = var.domain
  type            = "A"
  ttl             = 300
  records         = [aws_eip.blog.public_ip]
  allow_overwrite = false

  lifecycle {
    precondition {
      condition = !data.aws_route53_zone.blog.private_zone && (
        var.domain == trimsuffix(data.aws_route53_zone.blog.name, ".") ||
        endswith(var.domain, ".${trimsuffix(data.aws_route53_zone.blog.name, ".")}")
      )
      error_message = "The hostname must belong to the selected public Route 53 zone."
    }
  }
}
