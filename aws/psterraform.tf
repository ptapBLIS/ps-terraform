resource "aws_instance" "vagabond" {
    ami = "${lookup(var.ami, "${var.region}-${var.platform}")}"
    instance_type = "${var.instance_type}"
    key_name = "${var.key_name}"
    security_groups = ["${aws_security_group.ps-terraform.name}"]

    user_data =  <<HEREDOC
#!/bin/bash
dd if=/dev/zero of=/swapfile bs=1024 count=4096000
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile
HEREDOC

    root_block_device {
        volume_size = "200"
    }

    connection {
        user = "${lookup(var.user, var.platform)}"
        private_key = "${file("${var.key_path}")}"
    }

    #Instance tags
    tags {
        Name = "${var.tagName}"
    }

    provisioner "file" {
        source = "${path.module}/../config/psft_customizations.yaml"
        destination = "/tmp/psft_customizations.yaml"
    }

    provisioner "file" {
        source = "${path.module}/../shared/scripts/vagabond.json"
        destination = "/tmp/vagabond.json"
    }

    provisioner "remote-exec" {
        scripts = [
            "${path.module}/../shared/scripts/ip_tables.sh"
        ]
    }

    provisioner "file" {
        source = "${path.module}/../shared/scripts/provision.sh"
        destination = "/tmp/provision.sh"
    }

    provisioner "remote-exec" {
      inline = [
        "chmod +x /tmp/provision.sh",
        "/tmp/provision.sh ${var.mos_username} ${var.mos_password} ${var.patch_id} ${var.dpk_install}",
      ]
    }
}

resource "aws_security_group" "ps-terraform" {
    name = "ps-terraform_${var.platform}"
    description = "ps-terraform internal traffic + maintenance."

    // These are for internal traffic
    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        self = true
    }

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "udp"
        self = true
    }

    // These are for maintenance
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8000
        to_port = 8000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 1522
        to_port = 1522
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // This is for outbound internet access
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}