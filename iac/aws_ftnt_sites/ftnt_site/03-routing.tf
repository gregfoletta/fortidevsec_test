locals {
    //First FGT's first interface = implicit external interface
    first_fgt_ext_int = local.fgt[ keys(local.fgt)[0] ].interfaces[0].subnet

    external_route_table = [for subnet in local.flattened_rt_subnets : subnet.route_table if subnet.subnet_name == local.first_fgt_ext_int][0]

    first_fgt_int_int = local.fgt[ keys(local.fgt)[0] ].interfaces[1].subnet

    internal_route_table = [for subnet in local.flattened_rt_subnets : subnet.route_table if subnet.subnet_name == local.first_fgt_int_int][0]

    first_fgt = module.fortigate[ keys(local.fgt)[0] ]
}

// The first interface assigned to the firewall is our 'external' interface.
// We receive this back from the module and need to find which route table its
// associated with to determine is the 'external' route table
#data "aws_network_interface" "external" { id = local.first_fgt.external_interface.id }
#data "aws_route_table" "external" { subnet_id = aws_subnet.subnets[ local.first_fgt_ext_int ].id }
#data "aws_route_table" "internal" { subnet_id = aws_subnet.subnets[ local.first_fgt_int_int ].id }

resource "aws_route" "external_route" {
  route_table_id         = aws_route_table.route_tables[ local.external_route_table ].id
  #route_table_id         = data.aws_route_table.external.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

// The second interface is the 'internal' interface, so we do a similar thing
#data "aws_network_interface" "internal" { id = local.first_fgt.internal_interface.id }
#data "aws_route_table" "internal" { subnet_id = data.aws_network_interface.internal.subnet_id }

resource "aws_route" "internal_route" {
  route_table_id         = aws_route_table.route_tables[ local.internal_route_table ].id
  #route_table_id         = data.aws_route_table.internal.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = local.first_fgt.internal_interface.id
}


// Now we need to route all of the subnets in through the external interface
// EXCEPT the subnet of the external subnet. We find this by matching the
// checking the subnet IDs with the ID from the external interface (found above)

resource "aws_route" "igw_internal_routes" {
  depends_on             = [module.fortigate]
  for_each = {
        for subnet in local.flattened_rt_subnets : subnet.subnet_name => subnet if subnet.subnet_name != local.first_fgt_ext_int
    }

  route_table_id         = aws_route_table.igw.id
 //destination_cidr_block = cidrsubnet( var.site_vars.cidr, each.value.subnet[0], each.value.subnet[1] )
  destination_cidr_block = each.value.ipv4_subnet
  network_interface_id   = local.first_fgt.external_interface.id
}
