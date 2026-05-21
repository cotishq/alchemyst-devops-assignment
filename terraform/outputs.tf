output "gateway_public_ip" {
  value = aws_instance.gateway.public_ip
}

output "gateway_private_ip" {
  value = aws_instance.gateway.private_ip
}

output "inference_private_ip" {
  value = aws_instance.inference.private_ip
}

output "api_endpoint" {
  value = "http://${aws_instance.gateway.public_ip}/inference/get-response"
}

output "ssh_gateway" {
  value = "ssh -i ~/.ssh/alchemyst-key.pem ec2-user@${aws_instance.gateway.public_ip}"
}

output "ssh_inference_via_gateway" {
  value = "ssh -i ~/.ssh/alchemyst-key.pem -J ec2-user@${aws_instance.gateway.public_ip} ec2-user@${aws_instance.inference.private_ip}"
}
