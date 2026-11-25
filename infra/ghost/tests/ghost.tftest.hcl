mock_provider "aws" {
  override_during = plan

  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_route53_zone" {
    defaults = {
      name         = "example.com."
      private_zone = false
    }
  }
}

variables {
  domain         = "blog.example.com"
  hosted_zone_id = "Z00000000000000000000"
}

run "public_web_and_no_ssh" {
  command = plan

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.web)) == toset(["80", "443"])
    error_message = "Public ingress must be limited to HTTP and HTTPS."
  }

  assert {
    condition = alltrue([
      for port, rule in aws_vpc_security_group_ingress_rule.web :
      rule.ip_protocol == "tcp" && rule.from_port == tonumber(port) && rule.to_port == tonumber(port)
    ])
    error_message = "Each web rule must allow only its designated TCP port."
  }

  assert {
    condition = (
      strcontains(file("${path.module}/user-data.sh.tftpl"), "systemctl mask --now ssh.service ssh.socket") &&
      aws_instance.blog.metadata_options[0].http_tokens == "required" &&
      aws_instance.blog.root_block_device[0].encrypted
    )
    error_message = "The host must disable SSH, require IMDSv2, and encrypt its disk."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The deployment must attach the Systems Manager managed-instance policy."
  }

  assert {
    condition     = aws_route53_record.blog.type == "A" && output.blog_url == "https://blog.example.com"
    error_message = "The deployment must publish the configured HTTPS blog URL."
  }
}

run "reject_unrelated_zone" {
  command = plan

  variables {
    domain = "blog.example.org"
  }

  expect_failures = [aws_route53_record.blog]
}
