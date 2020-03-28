/* --- VPCs --- */
resource "aws_vpc" "vpc-main" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = "${
    map(
      "Name", "${var.clname}",
      "kubernetes.io/cluster/${var.clname}", "shared",
    )
  }"
}

/* ENDPOINTS */
#resource "aws_vpc_endpoint" "endp-s3" {
#  vpc_id       = "${aws_vpc.vpc-lb-web.id}"
#  service_name = "com.amazonaws.${var.region}.s3"
#}

#resource "aws_vpc_endpoint" "endp-dydb" {
#  vpc_id       = "${aws_vpc.vpc-lb-web.id}"
#  service_name = "com.amazonaws.${var.region}.dynamodb"
#}

#resource "aws_vpc_endpoint_route_table_association" "vpcea-s3-pub1" {
#  vpc_endpoint_id = "${aws_vpc_endpoint.endp-s3.id}"
#  route_table_id  = "${aws_route_table.rt-pub.id}"
#}

#resource "aws_vpc_endpoint_route_table_association" "vpcea-s3-pub2" {
#  vpc_endpoint_id = "${aws_vpc_endpoint.endp-s3.id}"
#  route_table_id  = "${aws_route_table.rt-pub.id}"
#}

#resource "aws_vpc_endpoint_route_table_association" "vpcea-s3-priv1" {
#  vpc_endpoint_id = "${aws_vpc_endpoint.endp-s3.id}"
#  route_table_id  = "${aws_route_table.rt-priv1.id}"
#}

#resource "aws_vpc_endpoint_route_table_association" "vpcea-s3-priv2" {
#  vpc_endpoint_id = "${aws_vpc_endpoint.endp-s3.id}"
#  route_table_id  = "${aws_route_table.rt-priv2.id}"
#}

#resource "aws_vpc_endpoint_route_table_association" "vpcea-dydb-priv1" {
#  vpc_endpoint_id = "${aws_vpc_endpoint.endp-dydb.id}"
#  route_table_id  = "${aws_route_table.rt-priv1.id}"
#}

#resource "aws_vpc_endpoint_route_table_association" "vpcea-dydb-priv2" {
#  vpc_endpoint_id = "${aws_vpc_endpoint.endp-dydb.id}"
#  route_table_id  = "${aws_route_table.rt-priv2.id}"
#}

/* NETWORKS */
resource "aws_subnet" "sn-pub" {
  count = "${var.zone_number}"

  vpc_id            = "${aws_vpc.vpc-main.id}"
  cidr_block        = "${cidrsubnet(var.vpc_cidr, 8, count.index)}"
  availability_zone = "${var.az[count.index]}"

  tags = "${
    map(
      "Name", "${var.clname}",
      "kubernetes.io/cluster/${var.clname}", "shared",
    )
  }"
}

resource "aws_subnet" "sn-priv" {
  count = "${var.zone_number}"

  vpc_id            = "${aws_vpc.vpc-main.id}"
  cidr_block        = "${cidrsubnet(var.vpc_cidr, 8, count.index + 5)}"
  availability_zone = "${var.az[count.index]}"

  tags = "${
    map(
      "Name", "${var.clname}",
      "kubernetes.io/cluster/${var.clname}", "shared",
    )
  }"
}

/* GATEWAYs */
resource "aws_internet_gateway" "igw-main" {
  vpc_id = "${aws_vpc.vpc-main.id}"

  tags {
    Name = "igw-main"
  }
}

resource "aws_vpn_gateway" "vpngw-main" {
  vpc_id = "${aws_vpc.vpc-main.id}"

  tags {
    Name = "vpngw-main"
  }
}

resource "aws_eip" "eip-ngw" {
  count = "${var.zone_number}"
  vpc = true
  depends_on = ["aws_internet_gateway.igw-main"]
}

resource "aws_nat_gateway" "ngw-priv" {
  count = "${var.zone_number}"
  allocation_id = "${aws_eip.eip-ngw.*.id[count.index]}"
  subnet_id     = "${aws_subnet.sn-priv.*.id[count.index]}"

  tags {
    Name = "NATgw"
  }
}

/* ROUTE TABLEs */
resource "aws_route_table" "rt-pub" {
  count = "${var.zone_number}"
  vpc_id = "${aws_vpc.vpc-main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw-main.id}"
  }
}

resource "aws_route_table" "rt-priv" {
  count = "${var.zone_number}"
  vpc_id = "${aws_vpc.vpc-main.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw-priv.*.id[count.index]}"
  }
}

/* ROUTE TABLE ASSOCIATION */
resource "aws_route_table_association" "rta-pub" {
  count = "${var.zone_number}"
  subnet_id      = "${aws_subnet.sn-pub.*.id[count.index]}"
  route_table_id = "${aws_route_table.rt-pub.*.id[count.index]}"
}

resource "aws_route_table_association" "rta-priv" {
  count = "${var.zone_number}"
  subnet_id      = "${aws_subnet.sn-priv.*.id[count.index]}"
  route_table_id = "${aws_route_table.rt-priv.*.id[count.index]}"
}
