data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "gateway" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.gateway.id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/../scripts/gateway-init.sh", {
    inference_private_ip = aws_instance.inference.private_ip
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.project}-gateway" }
}

resource "aws_instance" "inference" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.inference.id]
  key_name               = var.key_name

  user_data = file("${path.module}/../scripts/inference-init.sh")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.project}-inference" }
}
