data "aws_ami" "ubuntu" { #Default 20.04 Ubuntu Image
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "my_webserver" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.my_webserver.id]
  key_name = aws_key_pair.generated_key.key_name
    

  tags = {
    Name = "Web Server Build by Terraform"
    Owner = "Elbrus Mammadov"
  }

}

resource "null_resource" "ansible-playbook" {
  provisioner "local-exec" {
    command = "export ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -u ubuntu -i hosts --private-key ${aws_key_pair.generated_key.key_name}.pem apache-install.yml"
  }
  depends_on = [ local_file.hosts ]
}


