resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "calibre-vpc" }
}

data "aws_ec2_instance_type_offerings" "t3_micro" {
  location_type = "availability-zone"
  filter {
    name   = "instance-type"
    values = ["t3.micro"]
  }
}

resource "terraform_data" "t3_micro_az" {
  input = sort(data.aws_ec2_instance_type_offerings.t3_micro.locations)[0]  # first AZ that supports t3.micro
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = terraform_data.t3_micro_az.output
  map_public_ip_on_launch = true
  tags = { Name = "calibre-public-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "calibre-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "calibre-public-rt" }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "pub_assoc" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}