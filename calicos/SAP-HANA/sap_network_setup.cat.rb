#NOT WORKING - PROBLEM WITH THE PROVISIONING OF THE IGW ....
#
#------------
#### Network Definitions ###
#resource "vpc_network", type: "network" do
#  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  cidr_block "192.168.164.0/24"
#end
#
#resource "vpc_subnet", type: "subnet" do
#  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  network_href @vpc_network
#  cidr_block "192.168.164.0/28"
#end
#
#resource "vpc_igw", type: "network_gateway" do
#  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  type "internet"
#  network @vpc_network
#end
#
#resource "vpc_route_table", type: "route_table" do
#  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  network @vpc_network
#end
#
## This route is needed to allow the server to be able to talk back to RightScale.
## For a production environment you would probably want to limit the outbound route to just RightScale CIDRs and required ports.
## But for a demo CAT, this is fine. :)
#resource "vpc_route", type: "route" do
#  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
#  destination_cidr_block "0.0.0.0/0" 
#  next_hop_network_gateway @vpc_igw
#  route_table @vpc_route_table
#end
#
#### Security Group Definitions ###
## Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
## to provision the security group and rules.
#
#----------------





# Sets up networking used for SAP-HANA CAT.
# Done separately for now
#       

name "Networking Constructs CAT"
rs_ca_ver 20161221
short_description "Testing the configuration of networking constructs."

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
  }
}
end

### Network Definitions ###
resource "vpc_network", type: "network" do
#  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  name "sap_vpc_test"
  cloud map($map_cloud, "AWS", "cloud")
  cidr_block "192.168.164.0/24"
end

resource "vpc_subnet", type: "subnet" do
#  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  name "sap_subnet_test"
  cloud map($map_cloud, "AWS", "cloud")
  network @vpc_network
  cidr_block "192.168.164.0/28"
end

resource "vpc_igw", type: "network_gateway", provision: "provision_gateway_and_set_route" do
#  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  name "sap_igw_test"
  cloud map($map_cloud, "AWS", "cloud")
  type "internet"
  network @vpc_network
end

define provision_gateway_and_set_route(@declaration) return @igw do
  $object = to_object(@declaration)
  $fields = $object["fields"]
  # note the network
  $network_href = $fields["network_href"]  
    
  call log($network_href, "")

  # create the IGW
  @igw = rs_cm.network_gateways.create($fields)
  @igw = @igw.get()
  
  # Update the IGW with the network
  @igw.update(network_gateway: {network_href: $network_href})
  
#  # Get the default route table
#  @default_route_table = @igw.network().default_route_table()
#  # Create a route back to RS platform
#  @route = @default_route_table.routes().create(route: {destination_cidr_block: "0.0.0.0/0", next_hop_type: "network_gateway", next_hop_href: @igw.href, route_table_href: @default_route_table.href})
#  # Add route to the default route table
#  @default_route_table.update(   rs.route_tables.get(filter: [join(["network_href==",to_s(@resource.network().href)])])[0]
#  # Update the route table to use the default route table 
#  @vpc_network.update(network: {route_table_href: to_s(@other_route_table.href)})
end



#resource "vpc_route_table", type: "route_table" do
##  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
#  name "sap_route_table"
#  cloud map($map_cloud, "AWS", "cloud")
#  network @vpc_network
#end
#
## This route is needed to allow the server to be able to talk back to RightScale.
## For a production environment you would probably want to limit the outbound route to just RightScale CIDRs and required ports.
## But for a demo CAT, this is fine. :)
#resource "vpc_route", type: "route" do
##  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
#  name "sap_route"
#  destination_cidr_block "0.0.0.0/0" 
#  next_hop_network_gateway @vpc_igw
#  route_table @vpc_route_table
#end

#### Security Group Definitions ###
## Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
## to provision the security group and rules.
#resource "sec_group", type: "security_group" do
##  name join(["HanaSecGrp-",last(split(@@deployment.href,"/"))])
#  name "sap_sec_group"
#  description "SAP Hana Securiy Group security group."
#  cloud map($map_cloud, "AWS", "cloud")
#  network @vpc_network
#end
#
#resource "sec_group_rule_ssh", type: "security_group_rule" do
##  name join(["SshRule-",last(split(@@deployment.href,"/"))])
#  name "sap_ssh_rule"
#  description "Allow SSH access."
#  source_type "cidr_ips"
#  security_group @sec_group
#  protocol "tcp"
#  direction "ingress"
#  cidr_ips "0.0.0.0/0"
#  protocol_details do {
#    "start_port" => "22",
#    "end_port" => "22"
#  } end
#end
#
#### SSH key declarations ###
#resource "ssh_key", type: "ssh_key" do
##  name join(["sshkey_", last(split(@@deployment.href,"/"))])
#  name "sap_sshkey"
#  cloud map($map_cloud, "AWS", "cloud")
#end

#operation "launch" do 
#  description "Set up networking"
#  definition "pre_auto_launch"
#end
#
#operation "terminate" do 
#  description "Clean things up"
#  definition "terminate"
#end

# Import and set up what is needed for the server and then launch it.
define pre_auto_launch(@vpc_network, @vpc_subnet, @vpc_igw, @sec_group, @sec_group_rule_ssh, @ssh_key) return @vpc_network, @vpc_subnet, @vpc_igw, @sec_group, @sec_group_rule_ssh, @ssh_key do

    # Do some of the network resource provisioning so as to change the default route table for the network to use
    # the one created in this CAT instead of the default one created when networks are created.
    provision(@vpc_network)
  
    concurrent return @vpc_subnet, @vpc_igw, @sec_group, @sec_group_rule_ssh, @ssh_key  do
      provision(@vpc_subnet)
      provision(@vpc_igw)
      # The provision of the rule will automatically provision the group so it needs to be returned outside 
      # of this concurrent operation but not explicitly provisioned.
      provision(@sec_group_rule_ssh)
      provision(@ssh_key)
    end
    
    # configure the default route table set up for the network to allow outbound to the RS platform.
    @vpc_network.update(network: {route_table_href: to_s(@vpc_route_table.href)})
    
    # configure the igw to point at the network.
    @vpc_igw.update(network_gateway: {network_href: to_s(@vpc_network.href)})
    
end

define terminate(@vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @sec_group, @sec_group_rule_ssh, @ssh_key) do
  
  # switch back in the default route table so that auto-terminate doesn't hit a dependency issue when cleaning up.
  # Another approach would have been to not create and associate a new route table but instead find the default route table
  # and add the outbound 0.0.0.0/0 route to it.
  
  @other_route_table = @vpc_route_table #  initializing the variable
  # Find the route tables associated with our network. 
  # There should be two: the one we created above and the default one that is created for new networks.
  @route_tables=rs.route_tables.get(filter: [join(["network_href==",to_s(@vpc_network.href)])])
  foreach @route_table in @route_tables do
    if @route_table.href != @vpc_route_table.href
      # We found the default route table
      @other_route_table = @route_table
    end
  end
  # Update the network to use the default route table 
  @vpc_network.update(network: {route_table_href: to_s(@other_route_table.href)})
  
  # detact the network from the gateway
  @vpc_igw.update(network_gateway: {network_href: ""})
  
  delete(@vpc_igw)
  delete(@vpc_network)
  delete(@vpc_sec_group)

end


# create an audit entry 
define log($summary, $details) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: $summary , detail: $details})
end