output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "ec2_global_ips" {
  value = aws_instance.my_webserver.public_ip
}