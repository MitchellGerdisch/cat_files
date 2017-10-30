name 'Networking Creation Example'
rs_ca_ver 20161221
short_description "Creates a VPC and related items (e.g. subnet, security groups, etc)."

import "pft/err_utilities", as: "debug"

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "datacenter" => "us-east-1e"
  },
  "Google" => {
    "cloud" => "Google",
    "datacenter" => "us-central1-b"
  },
  "AzureRM" => {   
    "cloud" => "AzureRM East US",
    "datacenter" => null
  }
} end

parameter "cloud" do
  type "string"
  label "Cloud"
  category "Application"
  description "Target cloud for this cluster."
  allowed_values "AWS", "Google", "AzureRM"
  default "AWS"
end


### Network Definitions ###
resource "vpc_network", type: "network" do
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $cloud, "cloud")
  cidr_block "10.1.0.0/16"
end

resource "vpc_subnet", type: "subnet" do
  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $cloud, "cloud")
  datacenter map($map_cloud, $cloud, "datacenter")
  network_href @vpc_network
  cidr_block "10.1.1.0/24"
end

resource "vpc_igw", type: "network_gateway" do
  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $cloud, "cloud")
  type "internet"
  network_href @vpc_network
end

resource "vpc_route_table", type: "route_table" do
  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $cloud, "cloud")
  network_href @vpc_network
end

# Outbound traffic
resource "vpc_route", type: "route" do
  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
  destination_cidr_block "0.0.0.0/0" 
  next_hop_network_gateway @vpc_igw
  route_table @vpc_route_table
end

resource 'cluster_sg', type: 'security_group' do
  name join(['ClusterSG-', last(split(@@deployment.href, '/'))])
  description "Cluster security group."
  cloud map($map_cloud, $cloud, "cloud")
  network_href @vpc_network
end

resource 'cluster_sg_rule_int_tcp', type: 'security_group_rule' do
  name "ClusterSG TCP Rule"
  description "TCP rule for Cluster SG"
  source_type "cidr_ips"
  security_group @cluster_sg
  protocol 'tcp'
  direction 'ingress'
  cidr_ips "10.1.1.0/24"
  protocol_details do {
    'start_port' => '1',
    'end_port' => '65535'
  } end
end

resource 'cluster_sg_rule_int_udp', type: 'security_group_rule' do
  name "ClusterSG UDP Rule"
  description "UDP rule for Cluster SG"
  source_type "cidr_ips"
  security_group @cluster_sg
  protocol 'udp'
  direction 'ingress'
  cidr_ips "10.1.1.0/24"
  protocol_details do {
    'start_port' => '1',
    'end_port' => '65535'
  } end
end

operation 'launch' do
  description 'Launch the application'
  definition 'launch'
end

operation 'terminate' do
  description 'Terminate the application'
  definition 'terminate'
end

define launch(@vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @cluster_sg, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp, $cloud, $map_cloud) return @vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @cluster_sg, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp do
  
  call debug.log("before provision: subnet hash", to_s(to_object(@vpc_subnet)))
  
  # provision networking
  provision(@vpc_network)

  concurrent return @vpc_subnet, @vpc_igw, @vpc_route_table  do
    provision(@vpc_subnet)
    provision(@vpc_igw)
    provision(@vpc_route_table)    
  end
  
  call debug.log("after provision: subnet hash", to_s(to_object(@vpc_subnet)))
  
  provision(@vpc_route)
  
  # cluster_sg gets created automatically by provisioning the rules
  call debug.log("before provision: cluster_sg hash", to_s(to_object(@cluster_sg)))

  provision(@cluster_sg_rule_int_tcp)
  provision(@cluster_sg_rule_int_udp)
  
  call debug.log("after provision: cluster_sg hash", to_s(to_object(@cluster_sg)))
  
  # configure the network to use the route table
  @vpc_network.update(network: {route_table_href: to_s(@vpc_route_table.href)})
  
end

define terminate(@vpc_network, @vpc_route_table) do
  
  # switch back in the default route table so that auto-terminate doesn't hit a dependency issue when cleaning up.
  # Another approach would have been to not create and associate a new route table but instead find the default route table
  # and add the outbound 0.0.0.0/0 route to it.
  @other_route_table = @vpc_route_table #  initializing the variable
  # Find the route tables associated with our network. 
  # There should be two: the one we created above and the default one that is created for new networks.
  @route_tables=rs_cm.route_tables.get(filter: [join(["network_href==",to_s(@vpc_network.href)])])
  foreach @route_table in @route_tables do
    if @route_table.href != @vpc_route_table.href
      # We found the default route table
      @other_route_table = @route_table
    end
  end
  # Update the network to use the default route table 
  @vpc_network.update(network: {route_table_href: to_s(@other_route_table.href)})
   
end


