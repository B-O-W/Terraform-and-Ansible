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
