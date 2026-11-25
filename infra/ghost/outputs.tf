output "region" {
  value = var.region
}

output "instance_id" {
  value = aws_instance.blog.id
}

output "public_ip" {
  value = aws_eip.blog.public_ip
}

output "blog_url" {
  value = "https://${var.domain}"
}
