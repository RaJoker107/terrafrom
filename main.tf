resource "aws_vpc" "MY_VPC" {
    cidr_block= var.cidr
  
}

resource "aws_subnet" "sub1" {

vpc_id= aws_vpc.MY_VPC.id
cidr_block= "10.0.0.0/24"
availability_zone = "us-east-1a"
map_public_ip_on_launch=true
  
}

resource "aws_subnet" "sub2" {

vpc_id= aws_vpc.MY_VPC.id
cidr_block= "10.0.1.0/24"
availability_zone = "us-east-1b"
map_public_ip_on_launch=true
  
}

resource "aws_internet_gateway" "igw" {

  vpc_id= aws_vpc.MY_VPC.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.MY_VPC.id

  route  {
      cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "WebSsg" {

  name = "websg"
  vpc_id = aws_vpc.MY_VPC.id

    ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
 egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
  tags = {
    name= "websg"
  }
  
}

resource "aws_instance" "WebServer1" {

  ami = "ami-0231039d2b80be3ce"
  instance_type = "t2_micro"
  vpc_security_group_ids = [aws_security_group.WebSsg.id]
  subnet_id = aws_subnet.sub1.id
  user_data = base64decode(file("userdata.sh"))


}
resource "aws_instance" "WebServer2" {

  ami = "ami-0231039d2b80be3ce"
  instance_type = "t2_micro"
  vpc_security_group_ids = [aws_security_group.WebSsg.id]
  subnet_id = aws_subnet.sub2.id
  user_data = base64decode(file("userdata1.sh"))


}

#aws loadbalancer

resource "aws_lb" "lb" {
  internal = "false"
  load_balancer_type = "application"
  security_groups = [aws_security_group.WebSsg.id]
  subnets = [ aws_subnet.sub1.id,aws_subnet.sub2.id]

}

resource "aws_lb_target_group" "tg" {
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.MY_VPC.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
  
}

resource "aws_lb_target_group_attachment" "attac1" {

  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.WebServer1.id
  port = 80
  
}
resource "aws_lb_target_group_attachment" "attac2" {

  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.WebServer2.id
  port = 80
  
}

resource "aws_lb_listener" "listner" {
  load_balancer_arn = aws_lb.lb.arn
  port = 80
  protocol = "http"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
  
}
output "loacbalancerdns" {
  value = aws_lb.lb.dns_name

  
}

resource "aws_vpc_security_group_ingress_rule" "inner" {
  security_group_id = aws_security_group.WebSsg.id
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22

}