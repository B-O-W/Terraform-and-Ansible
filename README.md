# How to deploy an application to AWS EC2 Instance using Terraform and Ansible.

![Untitled](How%20to%20deploy%20an%20application%20to%20AWS%20EC2%20Instance%20u%20d8abb740929a470ea3e4fdba2725054f/Untitled.png)

## Prerequisites

This script is written to synchronize Ansible and Terraform and raise ec2 web-server

For this tutorial, you will need:

- an [AWS account](https://portal.aws.amazon.com/billing/signup?nc2=h_ct&src=default&redirect_url=https%3A%2F%2Faws.amazon.com%2Fregistration-confirmation#/start)
- the AWS CLI, [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

## Step 1 — Configure AWS CLI

In the script, you can use your data by writing it in `variable.tf`

- variable.tf

```jsx
variable "aws_access_key" {
  type = string
  description = "AWS access key"
  #default = "Change me"
}
variable "aws_secret_key" {
  type = string
  description = "AWS secret key"
  #default = "Change me"
}
variable "aws_region" {
  type = string
  description = "AWS region"
  #default = "Change me"
}

variable "generated_key_name" { ##This variable set for ssh-key name
  type        = string
  default     = "terraform-key-pair"
  description = "Key-pair generated by Terraform"
}
```

## Step 2 — After you change your `variable.tf` file in `main.tf` set your AWS credentials

- main.tf

```jsx
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}
```

## Step 3 — I used a Dynamic Security Group

- `dynamic-sg.tf`

```jsx
resource "aws_security_group" "my_webserver" {
  name        = "WebServer Security Group"
  description = "My First SecurityGroup"

  dynamic "ingress" {
  for_each = ["80", "443", "8080", "22", "9092", "9093"]
  content {
    from_port   = ingress.value
    to_port     = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "Web Server SecurityGroup" ###Change Tags to your idea!
    Owner = "Elbrus Mammadov"
  }
}
```

## Step 4 — In order to run Ansible we **should have ssh-key and hosts file with public IP**

- `ssh-key.tf`

```jsx
###Keypair Create Step

resource "tls_private_key" "dev_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.generated_key_name
  public_key = tls_private_key.dev_key.public_key_openssh

}

resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.generated_key.key_name}.pem"
  content = tls_private_key.dev_key.private_key_pem
  provisioner "local-exec" {
    working_dir = "${path.module}" # assuming its this directory
    command = "chmod 400 ./${aws_key_pair.generated_key.key_name}.pem"
  }
}
###Create hosts file with ec2 public ip
resource "local_file" "hosts" {
  filename = "hosts"
  content = aws_instance.my_webserver.public_ip
}
```

## Step 5 — I wrote a simple playbook that installs a web server on ubuntu

- `apache-install.yml`

```yaml
- become: yes
  hosts: all
  name: apache-install
  tasks:    
    - name: Wait for apt to unlock
      become: yes
      shell:  while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 5; done;
      
    - name: Install apache2
      apt:
        name: apache2
        update_cache: yes
        state: latest

      
    - name: Enable mod_rewrite
      apache2_module:
        name: rewrite 
        state: present

    - name: Recursively copy web-server directory
      copy:
        src: files/dist/
        dest: /var/www/html
        directory_mode: 0755
        owner: ubuntu
        group: ubuntu
        mode: 0644
    
    - name: Recursively copy web-server directory
      copy:
        src: files/src
        dest: /var/www/html/src
        directory_mode: 0755
        owner: ubuntu
        group: ubuntu
        mode: 0644

  handlers:
    - name: Restart apache2
      service:
        name: apache2
        state: restarted
```

## Step 5 — Deploy

- `ec2.tf`

```jsx
data "aws_ami" "ubuntu" { #Default 20.04 Ubuntu Image in all region
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
    command = "ansible-playbook -u ubuntu -i hosts --private-key ${aws_key_pair.generated_key.key_name}.pem apache-install.yml"
  }
  depends_on = [ local_file.hosts ]
}
```

## After you Deploy your code to AWS you see output

```bash
Plan: 1 to add, 0 to change, 1 to destroy.
null_resource.ansible-playbook1234: Destroying... [id=4705059883564653631]
null_resource.ansible-playbook1234: Destruction complete after 0s
null_resource.ansible-playbook12345: Creating...
null_resource.ansible-playbook12345: Provisioning with 'local-exec'...
null_resource.ansible-playbook12345 (local-exec): Executing: ["/bin/sh" "-c" "ansible-playbook -u ubuntu -i hosts --private-key terraform-key-pair.pem apache-install.yml"]

null_resource.ansible-playbook12345 (local-exec): PLAY [apache-install] **********************************************************

null_resource.ansible-playbook12345 (local-exec): TASK [Gathering Facts] *********************************************************
null_resource.ansible-playbook12345: Still creating... [10s elapsed]
null_resource.ansible-playbook12345 (local-exec): ok: [18.144.23.220]

null_resource.ansible-playbook12345 (local-exec): TASK [Wait for apt to unlock] **************************************************
null_resource.ansible-playbook12345 (local-exec): changed: [18.144.23.220]

null_resource.ansible-playbook12345 (local-exec): TASK [Install apache2] *********************************************************
null_resource.ansible-playbook12345: Still creating... [20s elapsed]
null_resource.ansible-playbook12345 (local-exec): ok: [18.144.23.220]

null_resource.ansible-playbook12345 (local-exec): TASK [Enable mod_rewrite] ******************************************************
null_resource.ansible-playbook12345: Still creating... [30s elapsed]
null_resource.ansible-playbook12345 (local-exec): ok: [18.144.23.220]

null_resource.ansible-playbook12345 (local-exec): TASK [Recursively copy testing directory] **************************************
null_resource.ansible-playbook12345: Still creating... [40s elapsed]
null_resource.ansible-playbook12345: Still creating... [50s elapsed]
null_resource.ansible-playbook12345 (local-exec): changed: [18.144.23.220]

null_resource.ansible-playbook12345 (local-exec): TASK [Recursively copy testing directory] **************************************
null_resource.ansible-playbook12345: Still creating... [1m0s elapsed]
null_resource.ansible-playbook12345: Still creating... [1m10s elapsed]
null_resource.ansible-playbook12345: Still creating... [1m20s elapsed]
null_resource.ansible-playbook12345 (local-exec): changed: [18.144.23.220]

null_resource.ansible-playbook12345 (local-exec): PLAY RECAP *********************************************************************
null_resource.ansible-playbook12345 (local-exec): 18.144.23.220              : ok=6    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

null_resource.ansible-playbook12345: Creation complete after 1m22s [id=4724713341599540870]

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

Outputs:

ec2_global_ips = "18.144.23.220" ##This is ec2 public ip 
ubuntu_ami_id = "ami-08241a3d2574c62ed" ##Because we used data-aws-image he set latest ubuntu image in all origion and you run this script and drink coffe)
root@DESKTOP-IIE6537:~/Terrafom-Ansible-WebServer# terraform apply --auto-approve
null_resource.ansible-playbook12345: Refreshing state... [id=4724713341599540870]
tls_private_key.dev_key: Refreshing state... [id=ae4aad384986dcdf0cd47fb388490a2d45fbf241]
aws_key_pair.generated_key: Refreshing state... [id=terraform-key-pair]
data.aws_ami.ubuntu: Reading...
aws_security_group.my_webserver: Refreshing state... [id=sg-04b61309259d1a1fe]
local_file.ssh_key: Refreshing state... [id=4d9faa580c6a88e410079660e40ebadcb6e53a00]
data.aws_ami.ubuntu: Read complete after 1s [id=ami-08241a3d2574c62ed]
aws_instance.my_webserver: Refreshing state... [id=i-0ff89ddcdc0737373]
local_file.hosts: Refreshing state... [id=661bf9834a4b7b5db6fcd4ec20b22bcabb63b4bc]
```

# If you go to your public ip you will see ;)

![Untitled](How%20to%20deploy%20an%20application%20to%20AWS%20EC2%20Instance%20u%20d8abb740929a470ea3e4fdba2725054f/Untitled%201.png)

****Useful Documentation:****

[Data Sources - Configuration Language | Terraform by HashiCorp](https://www.terraform.io/language/data-sources)

[Manage AWS Auto Scaling Groups | Terraform - HashiCorp Learn](https://learn.hashicorp.com/tutorials/terraform/aws-asg)

[Terraform Dynamic Blocks with Examples](https://www.cloudbolt.io/terraform-best-practices/terraform-dynamic-blocks/)

[Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami)

[403 Forbidden HTML Templates](https://freefrontend.com/403-forbidden-html-templates/)

[How To Use Ansible with Terraform for Configuration Management | DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-use-ansible-with-terraform-for-configuration-management)