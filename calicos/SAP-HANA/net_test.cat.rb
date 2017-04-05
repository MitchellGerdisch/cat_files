#
# REFERENCES:
#   CFT this CAT is based on: http://docs.aws.amazon.com/quickstart/latest/sap-hana/welcome.html
#     
# PREREQUISITES
#   SAP MCI that points at: ami-cef80ed8
#     This is a marketplace SUSE-based SAP-HANA AMI.
#     There is a RH version as well, but this CAT is being developed for a customer that uses the SUSE-based version.
#   SAP ST that points at the MCI.
#     Base on RL10 Base Linux ST
#     ST Boot Sequence Modified:
#       Remove NTP (not SUSE compatible code and not really needed)
#       Remove RedHat Subscription Register
#       Remove Setup Automatic Upgrade
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
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  cidr_block "192.168.164.0/24"
end

resource "vpc_subnet", type: "subnet" do
  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  network @vpc_network
  cidr_block "192.168.164.0/28"
end

resource "vpc_igw", type: "network_gateway" do
  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  type "internet"
  network @vpc_network
end

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
#resource "sec_group", type: "security_group" do
#  name join(["HanaSecGrp-",last(split(@@deployment.href,"/"))])
#  description "SAP Hana Securiy Group security group."
#  cloud map($map_cloud, "AWS", "cloud")
#  network @vpc_network
#end
#
#resource "sec_group_rule_ssh", type: "security_group_rule" do
#  name join(["SshRule-",last(split(@@deployment.href,"/"))])
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

#### SSH key declarations ###
#resource "ssh_key", type: "ssh_key" do
#  name join(["sshkey_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#end

#operation "launch" do 
#  description "orchestrate provisioning"
#  definition "orch_prov"
#end

define orch_prov(@vpc_network, @vpc_subnet, @vpc_igw) return @vpc_network, @vpc_subnet, @vpc_igw do
  provision(@vpc_network)
 
  concurrent return @vpc_subnet, @vpc_igw  do
    provision(@vpc_subnet)
    provision(@vpc_igw)
  end
  

end
