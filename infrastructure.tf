provider "aws" {
  region = "us-east-1"
}

resource "atlas_artifact" "vpn" {
  name = "monstrs/mesos-vpn"
  type = "aws.ami"
}

resource "atlas_artifact" "discovery" {
  name = "monstrs/mesos-discovery"
  type = "aws.ami"
}

resource "atlas_artifact" "master" {
  name = "monstrs/mesos-master"
  type = "aws.ami"
}

resource "atlas_artifact" "slave" {
  name = "monstrs/mesos-slave"
  type = "aws.ami"
}

resource "atlas_artifact" "kubernetes" {
  name = "monstrs/mesos-kubernetes"
  type = "aws.ami"
}

resource "atlas_artifact" "load-balancer" {
  name = "monstrs/mesos-load-balancer"
  type = "aws.ami"
}

resource "aws_vpc" "mesos" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true

  tags {
      Name = "mesos"
  }
}

resource "aws_internet_gateway" "mesos" {
  vpc_id = "${aws_vpc.mesos.id}"

  tags {
      Name = "mesos"
  }
}


# NAT instance

resource "aws_security_group" "nat" {
  name = "nat"
  description = "Allow services from the private subnet through NAT"

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["${aws_subnet.private.cidr_block}"]
  }

  vpc_id = "${aws_vpc.mesos.id}"
}

resource "aws_instance" "nat" {
  ami = "ami-2e1bc047"
  availability_zone = "us-east-1b"
  instance_type = "m1.small"
  key_name = "mac"
  security_groups = ["${aws_security_group.nat.id}"]
  subnet_id = "${aws_subnet.public.id}"
  associate_public_ip_address = true
  source_dest_check = false

  tags {
    Name = "NAT"
  }
}

# Public subnets

resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.mesos.id}"

  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1b"
}

# Routing table for public subnets

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.mesos.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.mesos.id}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}


# Private subsets

resource "aws_subnet" "private" {
  vpc_id = "${aws_vpc.mesos.id}"

  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
}

# Routing table for private subnets

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.mesos.id}"

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.nat.id}"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_security_group" "mesos" {
  name = "mesos"
  description = "Allow services from the private subnet"
  vpc_id = "${aws_vpc.mesos.id}"

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# VPN

resource "aws_security_group" "vpn" {
  name = "vpn"
  description = "Allow all inbound traffic"
  vpc_id = "${aws_vpc.mesos.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 9700
    to_port = 9700
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 9750
    to_port = 9750
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 16943
    to_port = 16947
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "vpn" {
  instance_type = "m1.small"
  ami = "${atlas_artifact.vpn.metadata_full.region-us-east-1}"
  availability_zone = "us-east-1b"
  security_groups = ["${aws_security_group.vpn.id}"]
  subnet_id = "${aws_subnet.public.id}"
  key_name = "mac"

  tags {
    Name = "VPN"
  }
}


# Load Balancer

resource "aws_security_group" "load-balancer" {
  name = "load-balancer"
  description = "Allow all inbound traffic"
  vpc_id = "${aws_vpc.mesos.id}"

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
	}
}

resource "aws_instance" "load-balancer" {
  instance_type = "m1.small"
  ami = "${atlas_artifact.load-balancer.metadata_full.region-us-east-1}"
  availability_zone = "us-east-1b"
  security_groups = ["${aws_security_group.load-balancer.id}"]
  subnet_id = "${aws_subnet.public.id}"
  key_name = "mac"

  tags {
    Name = "Load Balancer"
  }
}

# Instances

resource "aws_instance" "discovery" {
  instance_type = "m1.small"
  ami = "${atlas_artifact.discovery.metadata_full.region-us-east-1}"
  availability_zone = "us-east-1b"
  security_groups = ["${aws_security_group.mesos.id}"]
  subnet_id = "${aws_subnet.private.id}"
  key_name = "mac"

  tags {
    Name = "Mesos Discovery"
  }
}

resource "aws_instance" "master" {
  instance_type = "m3.medium"
  ami = "${atlas_artifact.master.metadata_full.region-us-east-1}"
  availability_zone = "us-east-1b"
  security_groups = ["${aws_security_group.mesos.id}"]
  subnet_id = "${aws_subnet.private.id}"
  key_name = "mac"

  tags {
    Name = "Mesos Master"
  }
}

resource "aws_instance" "slave" {
  instance_type = "m3.medium"
  ami = "${atlas_artifact.slave.metadata_full.region-us-east-1}"
  availability_zone = "us-east-1b"
  security_groups = ["${aws_security_group.mesos.id}"]
  subnet_id = "${aws_subnet.private.id}"
  key_name = "mac"

  tags {
    Name = "Mesos Slave"
  }
}

resource "aws_instance" "kubernetes" {
  instance_type = "m3.medium"
  ami = "${atlas_artifact.kubernetes.metadata_full.region-us-east-1}"
  availability_zone = "us-east-1b"
  security_groups = ["${aws_security_group.mesos.id}"]
  subnet_id = "${aws_subnet.private.id}"
  key_name = "mac"

  tags {
    Name = "Mesos Kubernetes"
  }
}


# Elastic IPs

resource "aws_eip" "nat" {
  instance = "${aws_instance.nat.id}"
  depends_on = ["aws_instance.nat"]
  vpc = true
}

resource "aws_eip" "vpn" {
  instance = "${aws_instance.vpn.id}"
  depends_on = ["aws_instance.vpn"]
  vpc = true
}

resource "aws_eip" "load-balancer" {
  instance = "${aws_instance.load-balancer.id}"
  depends_on = ["aws_instance.load-balancer"]
  vpc = true
}
