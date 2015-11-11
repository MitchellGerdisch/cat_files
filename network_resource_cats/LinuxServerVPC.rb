#Copyright 2015 RightScale
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.


#RightScale Cloud Application Template (CAT)

# DESCRIPTION
# Deploys a basic Linux server of type CentOS or Ubuntu as selected by user.
# It automatically imports the ServerTemplate it needs. 
# Also creates a VPC and related networking bits.
#
# TO-DOs:
# Currently all the VPC IP blocks and stuff are hard-coded since I wrote this as an example.
# So making these inputs is a natural next step.


# Required prolog
name 'Linux Server on a VPC'
rs_ca_ver 20131202
short_description "![Linux](https://s3.amazonaws.com/rs-pft/cat-logos/linux.png)\n
Launch a Linux server on a VPC created by the CAT."
long_description "Launches a Linux server, defaults to Ubuntu in an AWS VPC."

##################
# User inputs    #
##################
parameter "param_servertype" do
  category "User Inputs"
  label "Linux Server Type"
  type "list"
  description "Type of Linux server to launch"
  allowed_values "CentOS", 
    "Ubuntu"
  default "Ubuntu"
end

parameter "param_instancetype" do
  category "User Inputs"
  label "Server Performance Level"
  type "list"
  description "Server performance level"
  allowed_values "standard performance",
    "high performance"
  default "standard performance"
end

################################
# Outputs returned to the user #
################################
output "ssh_link" do
  label "SSH Link"
  category "Output"
  description "Use this string to access your server."
end

##############
# MAPPINGS   #
##############
mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "zone" => null, # We don't care which az AWS decides to use.
    "instance_type" => "m3.medium",
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "Public",
  },
  "Azure" => {   
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "medium",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
    "mci_mapping" => "Public",
  },
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "mci_mapping" => "Public",
  },
  "VMware" => {
    "cloud" => "POC vSphere",
    "zone" => "POC-vSphere-Zone-1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "VMware",
  }
}
end

mapping "map_instancetype" do {
  "standard performance" => {
    "AWS" => "m3.medium",
    "Azure" => "medium",
    "Google" => "n1-standard-1",
    "VMware" => "small",
  },
  "high performance" => {
    "AWS" => "m3.large",
    "Azure" => "large",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end

mapping "map_st" do {
  "linux_server" => {
    "name" => "Base ServerTemplate for Linux (RSB) (v14.1.1)",
    "rev" => "18",
  },
} end

mapping "map_mci" do {
  "VMware" => { # vSphere 
    "CentOS_mci" => "RightImage_CentOS_6.6_x64_v14.2_VMware",
    "CentOS_mci_rev" => "9",
    "Ubuntu_mci" => "RightImage_Ubuntu_14.04_x64_v14.2_VMware",
    "Ubuntu_mci_rev" => "7"
  },
  "Public" => { # all other clouds
    "CentOS_mci" => "RightImage_CentOS_6.6_x64_v14.2",
    "CentOS_mci_rev" => "24",
    "Ubuntu_mci" => "RightImage_Ubuntu_14.04_x64_v14.2",
    "Ubuntu_mci_rev" => "11"
  }
} end




############################
# RESOURCE DEFINITIONS     #
############################

### Network Definitions ###
resource "vpc_network", type: "network" do
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  cidr_block "192.168.164.0/24"
end

resource "vpc_subnet", type: "subnet" do
  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  network_href @vpc_network
  cidr_block "192.168.164.0/28"
end

resource "vpc_igw", type: "network_gateway" do
  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  type "internet"
  network @vpc_network
end

resource "vpc_route_table", type: "route_table" do
  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  network @vpc_network
end

resource "vpc_route", type: "route" do
  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
  destination_cidr_block "0.0.0.0/0"
  next_hop_network_gateway @vpc_igw
  route_table @vpc_route_table
end


### Server Definition ###
resource "linux_server", type: "server" do
  name 'Linux Server'
  cloud map($map_cloud, "AWS", "cloud")
  datacenter map($map_cloud, "AWS", "zone")
  network @vpc_network
  subnets @vpc_subnet
  instance_type map($map_instancetype, $param_instancetype, "AWS")
  ssh_key_href map($map_cloud, "AWS", "ssh_key")
  placement_group_href map($map_cloud, "AWS", "pg")
  security_group_hrefs map($map_cloud, "AWS", "sg")  
  server_template_href find(map($map_st, "linux_server", "name"), revision: map($map_st, "linux_server", "rev"))
  multi_cloud_image_href find(map($map_mci, map($map_cloud, "AWS", "mci_mapping"), join([$param_servertype, "_mci"])), revision: map($map_mci, map($map_cloud, "AWS", "mci_mapping"), join([$param_servertype, "_mci_rev"])))
  inputs do {
    "SECURITY_UPDATES" => "text:enable" # Enable security updates
  } end
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  name join(["LinuxServerSecGrp-",@@deployment.href])
  description "Linux Server security group."
  cloud map( $map_cloud, "AWS", "cloud" )
  network @vpc_network
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "Linux server SSH Rule"
  description "Allow SSH access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
end

##################
# Permissions    #
##################
permission "import_servertemplates" do
  actions   "rs.import"
  resources "rs.publications"
end

####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "pre_auto_launch"

end

operation "enable" do
  description "Get information once the app has been launched"
  definition "enable"
  
  # Update the links provided in the outputs.
  output_mappings do {
    $ssh_link => $server_ip_address,
  } end
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
define pre_auto_launch(@vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @linux_server, @sec_group, @sec_group_rule_ssh, @ssh_key, $map_cloud, $map_st) return @vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @linux_server, @sec_group, @sec_group_rule_ssh, @ssh_key do

    # Need the cloud name later on
    $cloud_name = map( $map_cloud, "AWS", "cloud" )

    # Check if the selected cloud is supported in this account.
    # Since different PIB scenarios include different clouds, this check is needed.
    # It raises an error if not which stops execution at that point.
    call checkCloudSupport($cloud_name)
    
    # Find and import the server template - just in case it hasn't been imported to the account already
    call importServerTemplate($map_st)
    
    # Do some of the network resource provisioning so as to change the default route table for the network to use
    # the one created in this CAT instead of the default one created when networks are created.
    # There is a request into product to have a "default_route_table" or similar parameter added to the network and/or subnet
    # declaration definition so that one can simply tell the system to use a different route table. 
    # But for now, we have to RCL this stuff to get the resources created and then point the network at the route table.
    provision(@vpc_network)
  
    concurrent return @vpc_subnet, @vpc_igw, @vpc_route_table  do
      provision(@vpc_subnet)
      provision(@vpc_igw)
      provision(@vpc_route_table)    
    end
    
    concurrent return @vpc_route, @sec_group, @sec_group_rule_ssh, @ssh_key do
      provision(@vpc_route)
      # The provision of the rule will automatically provision the group so it needs to be returned outside 
      # of this concurrent operation but not explicitly provisioned.
      provision(@sec_group_rule_ssh)
      provision(@ssh_key)
    end
    
    # configure the network to use the route table
    @vpc_network.update(network: {route_table_href: to_s(@vpc_route_table.href)})
    
    # provision the server
    provision(@linux_server)
    
end

define enable(@linux_server) return $server_ip_address do
    
    while equals?(@linux_server.current_instance().public_ip_addresses[0], null) do
      sleep(10)
    end
    $server_addr =  @linux_server.current_instance().public_ip_addresses[0]

    # Create the SSH download link like that in CM
    call find_shard(@@deployment) retrieve $shard_number
    call find_account_number() retrieve $account_number
    call get_server_access_link(@linux_server, "SSH", $shard_number, $account_number) retrieve $server_ip_address
end 

# Checks if the account supports the selected cloud
define checkCloudSupport($cloud_name) do
  # Gather up the list of clouds supported in this account.
  @clouds = rs.clouds.get()
  $supportedClouds = @clouds.name[] # an array of the names of the supported clouds
  
  # Check if the selected/mapped cloud is in the list and yell if not
  if logic_not(contains?($supportedClouds, [$cloud_name]))
    raise "Your trial account does not support the "+$cloud_name+" cloud."
  end
end

# Imports the server templates found in the given map.
# It assumes a "name" and "rev" mapping
define importServerTemplate($stmap) do
  foreach $st in keys($stmap) do
    $server_template_name = map($stmap, $st, "name")
    $server_template_rev = map($stmap, $st, "rev")
    @pub_st=rs.publications.index(filter: ["name=="+$server_template_name, "revision=="+$server_template_rev])
    @pub_st.import()
  end
end

# Used for retry mechanism
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end

# Helper Functions for creating the server access link provided back to the user
# Returns either an RDP or SSH link for the given server.
# This link can be provided as an output for a CAT and the user can select it to to get the
# RDP or SSH file just like in Cloud Management.
#
# INPUTS:
#   @server - server resource for which you want the link
#   $link_type - "SSH" or "RDP" to indicate which type of access link you want back.
#   $shard - the API shard to use. This can be found using the "find_shard.rb" definition.
#   $account_number - the account number. This can be found using the "find_account_number.rb" definition.
#
define get_server_access_link(@server, $link_type, $shard, $account_number) return $server_access_link do
  
#  rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: join(["received account_number ", $account_number]), detail: ""})

  $rs_endpoint = "https://us-"+$shard+".rightscale.com"
    
  $instance_href = @server.current_instance().href
  
  $response = http_get(
    url: $rs_endpoint+"/api/instances",
    headers: { 
    "X-Api-Version": "1.6",
    "X-Account": $account_number
    }
   )
  
  $instances = $response["body"]
  
  $instance_of_interest = select($instances, { "href" : $instance_href })[0]
#  rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: join(["instance of interest"]), detail: to_s($instance_of_interest)})
    
  $legacy_id = $instance_of_interest["legacy_id"]  

  $cloud_id = $instance_of_interest["links"]["cloud"]["id"]
  
  $instance_public_ips = $instance_of_interest["public_ip_addresses"]
  $instance_private_ips = $instance_of_interest["private_ip_addresses"]
  $instance_ip = switch(empty?($instance_public_ips), to_s($instance_private_ips[0]), to_s($instance_public_ips[0]))
#  rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: join(["instance_ip: ", $instance_ip]), detail: ""})

  $server_access_link_root = "https://my.rightscale.com/acct/"+$account_number+"/clouds/"+$cloud_id+"/instances/"+$legacy_id
  
  if $link_type == "RDP"
    $server_access_link = $server_access_link_root +"/rdp?host=" + $instance_ip
  elsif $link_type == "SSH"
    $server_access_link = $server_access_link_root +"/managed_ssh.jnlp?host=" + $instance_ip
  else
    raise "Incorrect link_type, " + $link_type + ", passed to get_server_access_link()."
  end
  
#  rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: "access link", detail: $server_access_link})

end

# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $rs_account_number do
  $cloud_accounts = to_object(first(rs.cloud_accounts.get()))
  @info = first(rs.cloud_accounts.get())
  $info_links = @info.links
  $rs_account_info = select($info_links, { "rel": "account" })[0]
  $rs_account_href = $rs_account_info["href"]  
    
  $rs_account_number = last(split($rs_account_href, "/"))
#  rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: "rs_account_number" , detail: to_s($rs_account_number)})
end

# Returns the RightScale shard for the account the given CAT is launched in.
# It relies on the fact that when a CAT is launched, the resultant deployment description includes a link
# back to Self-Service. 
# This link is exploited to identify the shard.
# Of course, this is somewhat dangerous because if the deployment description is changed to remove that link, 
# this code will not work.
# Similarly, since the deployment description is also based on the CAT description, if the CAT author or publisher
# puts something like "selfservice-8" in it for some reason, this code will likely get confused.
# However, for the time being it's fine.
define find_shard(@deployment) return $shard_number do
  
  $deployment_description = @deployment.description
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "deployment description" , detail: $deployment_description})
  
  # initialize a value
  $shard_number = "UNKNOWN"
  foreach $word in split($deployment_description, "/") do
    if $word =~ "selfservice-" 
    #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found word:",$word]) , detail: ""}) 
      foreach $character in split($word, "") do
        if $character =~ /[0-9]/
          $shard_number = $character
          rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: join(["found shard:",$character]) , detail: ""}) 
        end
      end
    end
  end
end


