#
#The MIT License (MIT)
#
#Copyright (c) 2014 Mitch Gerdisch
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.


#RightScale Cloud Application Template (CAT)

# Deploys a single Chef Client server that connects to an OpsCode hosted chef server.
#
# PREREQUISITES:
# Cloud Management:
#   Imported Server Templates:
#     Chef Client Beta (v13.5.1) [rev 32] 
#   Credential: GERDISCH_OPSCODE_VALIDATION_KEY 
#     Or the key for the opscode user specified below.
#
# OpsCode Hosted Chef
#   Account on OpsCode hosted chef.
#   Organization defined: rs_demo
#
# Demo Notes:
#   - Pick a role when deploying.
#   - Click link to server to see the deployed role.
#   - Apply other role after deployment.
#   - Refresh link to see new role.

name "Chef Client with Hosted Chef"
rs_ca_ver 20131202
short_description "![Chef](https://s3.amazonaws.com/rs-pft/cat-logos/chef_logo_new.png)\n
Builds a Chef Client server that connects to a hosted chef server."
long_description "Deploy using one of the two preconfigured roles: turner or hooch.\n
After deployment click the link to see the web server display.\n
Use More Actions to change to the other role.\n
After updated with the new role, refresh the web page.\n
\nYou can also see the client registration with the Chef server by accessing the opscode account. Contact Mitch Gerdisch to be invited to the opscode account."

##############
# PARAMETERS #
##############

parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure", "Google"
  default "AWS"
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

parameter "param_role" do 
  category "Chef"
  label "Chef Role" 
  type "string" 
  description "Chef role to apply to the server." 
#  allowed_pattern "[A-Za-z0-9][A-Za-z0-9-_.]*"
  allowed_values "turner", "hooch"
  default "hooch"
end



##############
# MAPPINGS   #
##############

mapping "map_hosted_chef_account" do {
  "opscode_hosted_chef" => {
    "chef_org" => "rs_demo",
    "chef_username" => "gerdisch",
    "chef_user_validation" => "GERDISCH_OPSCODE_VALIDATION_KEY",
  }
}
end

mapping "map_instancetype" do {
  "standard performance" => {
    "AWS" => "m3.medium",
    "Azure" => "D1",
    "Google" => "n1-standard-1",
    "VMware" => "small",
  },
  "high performance" => {
    "AWS" => "m3.large",
    "Azure" => "D2",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end

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
    "instance_type" => "D1",
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
    "cloud" => "VMware Private Cloud",
    "zone" => "VMware_Zone_1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "VMware",
  }
}
end


##############
# CONDITIONS #
##############

# Checks if being deployed in AWS.
# This is used to decide whether or not to pass an SSH key and security group when creating the servers.
condition "inAWS" do
  equals?(map($map_cloud, $param_location,"provider"), "AWS")
end

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "VMware"))
end

condition "needsSecurityGroup" do
  logic_or(equals?($param_location, "AWS"), equals?($param_location, "Google"))
end

condition "invSphere" do
  equals?($param_location, "VMware")
end

condition "inAzure" do
  equals?($param_location, "Azure")
end

condition "needsPlacementGroup" do
  equals?($param_location, "Azure")
end 

##############
# OUTPUTS    #
##############

output "server_url" do
  label "Server URL" 
  category "Connect"
  default_value join(["http://", @client_server.public_ip_address])
  description "Assuming the role supports a webservice on port 80, this link can be used to access it."
end

output "hosted_chef_url" do
  label "Show Registered Chef Client Nodes"
  category "Connect"
  default_value "https://manage.opscode.com"
  description "Link to the hosted chef site."
end

##############
# RESOURCES  #
##############

resource "client_server", type: "server" do
  name "Chef Client Server"
  cloud map( $map_cloud, $param_location, "cloud" )
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  server_template find("Chef Client Beta (v13.5.1)", revision: 32)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  inputs do {
    "chef/client/roles" => join(["text:", $param_role]),
    "chef/client/company" => join(["text:", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_org")]),
    "chef/client/server_url" => join(["text:https://api.opscode.com/organizations/", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_org")]),
    "chef/client/validation_name" => join(["text:", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_username")]),
    "chef/client/validator_pem" => join(["cred:", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_user_validation")]),
    "chef/client/log_level" => "text:debug",  
  } end
end

resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup

  name join(["LinuxServerSecGrp-",last(split(@@deployment.href,"/"))])
  description "Linux Server security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  condition $needsSecurityGroup

  name join(["Linux server SSH Rule-",last(split(@@deployment.href,"/"))])
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
  condition $needsSshKey

  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  condition $needsPlacementGroup

  name last(split(@@deployment.href,"/"))
  cloud map($map_cloud, $param_location, "cloud")
end 

###############
## Operations #
###############

operation "enable" do
  description "Enable the application."
  definition "enable_application"
  output_mappings do {
    $hosted_chef_url => join(["https://manage.opscode.com/organizations/", $chef_org, "/nodes"])
  } end
end

# Allows user to apply different role after app is running
operation "Apply Role" do
  description "Apply role to server."
  definition "apply_role"
end


##############
# Definitions#
##############

# 
# Enable Application
# Generates a better chef_url output value to take user directly to the Nodes listing.
#
define enable_application(@client_server, $map_hosted_chef_account) return $chef_org do
  task_label("Enabling application")
  
  # Return the chef org for the updated mapping.
  # Was not able to see a way to use the mapping directly in the output or output_mapping.
  $chef_org = map($map_hosted_chef_account, "opscode_hosted_chef", "chef_org")

end


#
# Apply Role
#
define apply_role(@client_server, $param_role) do
  task_label("Apply role")
  call log_this("Updating INPUT to " + $param_role)
  $inp = {
     "chef/client/roles": join(["text:", $param_role])
   }
   @client_server.current_instance().multi_update_inputs(inputs: $inp)
  #@client_server.update(inputs:[{ "name":"Set of Client Roles", "value":join(["text:", $param_role])}])
  call log_this("Running recipe to apply new role " + $param_role)
  # I don't think I need to pass an input in this case since I just modified it for the instance in the previous step.
  call run_recipe_inputs(@client_server, "chef::do_client_converge", { "chef/client/roles": join(["text:", $param_role]) })  
end
