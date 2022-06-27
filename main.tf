## Create VPC ##
resource "aws_vpc" "prod-vpc" {
  cidr_block           = var.VPC_cidr
  enable_dns_support   = "true" #Internal Domain Name
  enable_dns_hostnames = "true" #Internal Host Name
  enable_classiclink   = "false"
  instance_tenancy     = "default"
}

## Create Public Subnet for EC2 ##
resource "aws_subnet" "prod-subnet-public-1" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = var.subnet1_cidr
  map_public_ip_on_launch = "true" # Public Subnet
  availability_zone       = var.AZ1
}

## Create Private subnet for RDS ##
resource "aws_subnet" "prod-subnet-private-1" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = var.subnet2_cidr
  map_public_ip_on_launch = "false" # Private Subnet
  availability_zone       = var.AZ2
}

## Create second Private subnet for RDS ##
resource "aws_subnet" "prod-subnet-private-2" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = var.subnet3_cidr
  map_public_ip_on_launch = "false" # Private Subnet
  availability_zone       = var.AZ3
}

## Create IGW for Internet Connection ##
resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.prod-vpc.id
}

## Creating Route Table ##
resource "aws_route_table" "prod-public-crt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    ## Associated Subnet to Everywhere ##
    cidr_block = "0.0.0.0/0"
    ## CRT Uses This IGW to Internet
    gateway_id = aws_internet_gateway.prod-igw.id
  }
}

## Associating Route Table to Public Subnet ##
resource "aws_route_table_association" "prod-crta-public-subnet-1" {
  subnet_id      = aws_subnet.prod-subnet-public-1.id
  route_table_id = aws_route_table.prod-public-crt.id
}

## Security Group for EC2 ##
resource "aws_security_group" "ec2_allow_rule" {
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "Allow SSH,HTTP,HTTPS"
  }
}

## Security Group for RDS ##
resource "aws_security_group" "RDS_allow_rule" {
  vpc_id = aws_vpc.prod-vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ec2_allow_rule.id}"]
  }
  # Allow All Outbound Traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow EC2 (Outbound)"
  }
}

## Create RDS Subnet Group ##
resource "aws_db_subnet_group" "RDS_subnet_grp" {
  subnet_ids = ["${aws_subnet.prod-subnet-private-1.id}", "${aws_subnet.prod-subnet-private-2.id}"]
}

## Create RDS Instance ##
resource "aws_db_instance" "wordpressdb" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "8.0.29"
  instance_class         = var.instance_class
  db_subnet_group_name   = aws_db_subnet_group.RDS_subnet_grp.id
  vpc_security_group_ids = ["${aws_security_group.RDS_allow_rule.id}"]
  name                   = var.database_name
  username               = var.database_user
  password               = var.database_password
  skip_final_snapshot    = true
}

## Change USERDATA Varible Value After Getting RDS Endpoint Info ##
data "template_file" "user_data" {
  template = file("./userdata.tpl")
  vars = {
    db_username      = var.database_user
    db_user_password = var.database_password
    db_name          = var.database_name
    db_RDS           = aws_db_instance.wordpressdb.endpoint
  }
}

## Create EC2 (Only After RDS is Provisioned)
resource "aws_instance" "wordpressec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.prod-subnet-public-1.id
  vpc_security_group_ids = ["${aws_security_group.ec2_allow_rule.id}"]
  user_data              = data.template_file.user_data.rendered
  key_name               = aws_key_pair.mykey-pair.id
  tags = {
    Name = "Wordpress.web"
  }

  root_block_device {
    volume_size = var.root_volume_size #GB 
  }

  ## This Will Stop Creating EC2 Before RDS is Provisioned ##
  depends_on = [aws_db_instance.wordpressdb]
}

## Sends Your Public Key to the Instance ##
resource "aws_key_pair" "mykey-pair" {
  key_name   = "mykey-pair"
  public_key = file(var.PUBLIC_KEY_PATH)
}

## Create Elastic IP for EC2 ##
resource "aws_eip" "eip" {
  instance = aws_instance.wordpressec2.id

}

output "IP" {
  value = aws_eip.eip.public_ip
}
output "RDS-Endpoint" {
  value = aws_db_instance.wordpressdb.endpoint
}

output "INFO" {
  value = "AWS Resources and Wordpress has been provisioned. Go to http://${aws_eip.eip.public_ip}"
}