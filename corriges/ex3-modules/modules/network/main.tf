resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

# for_each indexé par clé : supprimer "a" ne touche jamais à "b".
# Avec count, supprimer l'élément 0 décalerait tous les index et forcerait des
# destructions / recréations en cascade.
resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = { Name = "${var.name}-subnet-${each.key}" }
}

resource "aws_security_group" "web" {
  name        = "${var.name}-web"
  description = "Lab Terraform - HTTPS entrant"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS public"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.https_ingress_cidrs
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-web" }
}
