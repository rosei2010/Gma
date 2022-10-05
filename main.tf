 # Vpc 
resource "aws_vpc" "Star-VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Star-VPC"
  }
}

# Public subnets
resource "aws_subnet" "Maint-public-sub1" {
  vpc_id     = aws_vpc.Star-VPC.id
  cidr_block = "var.public-sub1-cidr"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "Maint-public-sub1"
  }
}

resource "aws_subnet" "Maint-public-sub2" {
  vpc_id     = aws_vpc.Star-VPC.id
  cidr_block = "var.public-sub2-cidr"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "Maint-public-sub2"
  }
}

# Private subnets
resource "aws_subnet" "Maint-priv-sub1" {
  vpc_id     = aws_vpc.Star-VPC.id
  cidr_block = "var.priv-sub1-cidr"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "Maint-priv-sub1"
  }
}

resource "aws_subnet" "Maint-priv-sub2" {
  vpc_id     = aws_vpc.Star-VPC.id
  cidr_block = "var.priv-sub2-cidr"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "Maint-priv-sub2"
  }
}

# Public route table
resource "aws_route_table" "Maint-pub-route-table" {
  vpc_id = aws_vpc.Star-VPC.id

  tags = {
    Name = "Maint-pub-route-table"
  }
}

# Private route table
resource "aws_route_table" "Maint-priv-route-table" {
  vpc_id = aws_vpc.Star-VPC.id

  tags = {
    Name = "Maint-priv-route-table"
  }
}

# Associate subnets public
resource "aws_route_table_association" "Public-route-table-association-1" {
  subnet_id      = aws_subnet.Maint-public-sub1.id
  route_table_id = aws_route_table.Maint-pub-route-table.id
}

resource "aws_route_table_association" "Public-route-table-association-2" {
  subnet_id      = aws_subnet.Maint-public-sub2.id
  route_table_id = aws_route_table.Maint-pub-route-table.id
}

# Association private
resource "aws_route_table_association" "Private-route-table-association-1" {
  subnet_id      = aws_subnet.Maint-priv-sub1.id
  route_table_id = aws_route_table.Maint-priv-route-table.id
}

resource "aws_route_table_association" "Private-route-table-association-2" {
  subnet_id      = aws_subnet.Maint-priv-sub2.id
  route_table_id = aws_route_table.Maint-priv-route-table.id
}

# IGW
resource "aws_internet_gateway" "Maint-igw" {
  vpc_id = aws_vpc.Star-VPC.id

  tags = {
    Name = "Maint-igw"
  }
}

# AWS route
resource "aws_route" "Maint-igw-association" {
  route_table_id            = aws_route_table.Maint-pub-route-table.id
  gateway_id                = aws_internet_gateway.Maint-igw.id
  destination_cidr_block    = "0.0.0.0/0"
}

# EIP
resource "aws_eip" "EIP-for-NG" {
  vpc = true
  associate_with_private_ip = "3.10.220.206"
}

# Nat gateway
  resource "aws_nat_gateway" "Maint-nat-gateway" {
  allocation_id = aws_eip.EIP-for-NG.id
  subnet_id     = aws_subnet.Maint-public-sub1.id
  }
  

  # Association Private route
resource "aws_route" "Maint-nat-gw-association" {
  route_table_id            = aws_route_table.Maint-priv-route-table.id
  nat_gateway_id            = aws_nat_gateway.Maint-nat-gateway.id
  destination_cidr_block    = "0.0.0.0/0"
}

# RDS 
resource "aws_db_instance" "Rock-mysql" {
  engine            = "MySQL"
  identifier        = "mysqldatabase"
  engine_version    = "8.0.28"
  instance_class    = "db.t2.micro"
  allocated_storage = 20
  username          = "rich"
  password          = "letsgohome"
  db_subnet_group_name   = aws_db_subnet_group.Rock-db-group.id
  multi_az = false
  final_snapshot_identifier = false
  vpc_security_group_ids = [aws_security_group.Maint-sec-group.id]
}



# DB subnet group
resource "aws_db_subnet_group" "Rock-db-group" {
  name       = "main"
  subnet_ids = [aws_subnet.Maint-priv-sub1.id, aws_subnet.Maint-priv-sub2.id]

  tags = {
    Name = "Rock-db-group"
  }
}


#Security group
resource "aws_security_group" "Maint-sec-group" {
  name        = "Maint-sec-group"
  description = "security group"
  vpc_id      = aws_vpc.Star-VPC.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Maint-sec-group"
  }
}

# Target Group
resource "aws_lb_target_group" "Rock-target-group" {
  name        = "Rock-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.Star-VPC.id
  stickiness {
    type = "lb_cookie"
  }
  
  health_check {
    path = "/login"
    port = 80
  }
}

# Application load balancer
resource "aws_lb" "Rock-alb" {
  name               = "Rock-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Maint-sec-group.id]
  subnets            = [aws_subnet.Maint-public-sub1.id, aws_subnet.Maint-public-sub2.id]
  
   enable_deletion_protection = true

}

# Listener
resource "aws_lb_listener" "Maint-listener" {
  load_balancer_arn = aws_lb.Rock-alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Rock-target-group.arn
  }
}