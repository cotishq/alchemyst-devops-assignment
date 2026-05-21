resource "aws_security_group" "gateway" {
  name        = "${var.project}-gateway-sg"
  description = "Gateway - HTTP public, SSH restricted"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-gateway-sg" }
}

resource "aws_security_group" "inference" {
  name        = "${var.project}-inference-sg"
  description = "Inference worker - only reachable from gateway"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 49134
    to_port         = 49134
    protocol        = "tcp"
    security_groups = [aws_security_group.gateway.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.gateway.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-inference-sg" }
}
