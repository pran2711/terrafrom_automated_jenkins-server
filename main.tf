resource "aws_key_pair" "jenkinskey" {
  key_name   = "jenkinskey"
  public_key = file("${path.module}/jenkinskey.pub")
}
resource "aws_vpc" "jenkins_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "jenkins_vpc"
  }
}

resource "aws_subnet" "jenkins_subnet" {
  vpc_id            = aws_vpc.jenkins_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "jenkins_subnet"
  }
}

resource "aws_security_group" "jenkins-sg" {
  name        = "jenkins-sg"
  description = "allow jenkins server onn port 8080"
  vpc_id      = aws_vpc.jenkins_vpc.id
  
  dynamic "ingress" {
    for_each = [22,8080]
    iterator = port
    content {
      description    = "jenkins connection"
    from_port        = port.value
    to_port          = port.value
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] 
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}


resource "aws_route_table" "jrt" {
  vpc_id      = aws_vpc.jenkins_vpc.id
  tags = {
    "Name" = "jrt"
  }
}

resource "aws_route_table_association" "rtas" {
  subnet_id = aws_subnet.jenkins_subnet.id
  route_table_id = aws_route_table.jrt.id
}

resource "aws_internet_gateway" "jigw" {
  vpc_id      = aws_vpc.jenkins_vpc.id
   tags = {
    "Name" = "jigw"
  }
}

resource "aws_route" "irt" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id = aws_route_table.jrt.id
  gateway_id = aws_internet_gateway.jigw.id
}

resource "aws_instance" "jenkins" {
  ami           = "ami-01a4f99c4ac11b03c"
  instance_type = "t2.micro"
  key_name = aws_key_pair.jenkinskey.key_name  
  vpc_security_group_ids = [ aws_security_group.jenkins-sg.id ]
subnet_id = aws_subnet.jenkins_subnet.id
  associate_public_ip_address = true
  tags = {
    Name = "jenkins"
  }
}


resource "null_resource" "provis" {
  connection {
  type = "ssh"
  user = "ec2-user"
  private_key = file("./jenkinskey")
  host = aws_instance.jenkins.public_ip
}

provisioner "file" {
  source = "jenkins.sh"
  destination = "/tmp/jenkins.sh"
}

provisioner "remote-exec" {
   inline = [
    "sudo chmod +x /tmp/jenkins.sh",
    "sh /tmp/jenkins.sh"
   ]
}

depends_on = [
  aws_instance.jenkins
]
}

output "url" {
  value = join ("",["http://",aws_instance.jenkins.public_ip,":8080"])
}