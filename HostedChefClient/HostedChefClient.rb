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
short_description "![Chef](https://www.getchef.com/images/logo.svg)\n
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
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS-Australia", "AWS-Brazil", "AWS-Japan", "AWS-USA", "Azure-Netherlands", "Azure-Singapore", "Azure-USA"
  default "AWS-USA"
end

parameter "param_performance" do 
  category "Deployment Options"
  label "Performance profile" 
  type "string" 
  description "Compute and RAM" 
  allowed_values "low", "medium", "high"
  default "low"
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

mapping "map_instance_type" do {
  "AWS" => {
    "low" => "m1.medium",  
    "medium" => "c3.large", 
    "high" => "c3.xlarge", 
  },
  "RS" => {
    # These choices are driven by what is configured for RS London cloud in RS.
    "low" => "4GB Standard Instance", # 2 CPUs x 4GB
    "medium" => "8GB Standard Instance", # 4CPUs  x 8GB
    "high" => "15GB Standard Instance", # 6 CPUs x 15GB
  },
  "Azure" => {
    "low" => "medium", # 2 CPUs x 3.5GB
    "medium" => "large", # 4 CPUs x 7GB
    "high" => "extra large", # 8CPUs x 15GB
  },
}
end

mapping "map_cloud" do {
  "AWS-Australia" => {
    "provider" => "AWS",
    "cloud" => "ap-southeast-2",
  },
  "AWS-Brazil" => {
    "provider" => "AWS",
    "cloud" => "sa-east-1",
  },
  "Azure-Netherlands" => {
    "provider" => "Azure",
    "cloud" => "Azure West Europe",
  },
  "AWS-Japan" => {
    "provider" => "AWS",
    "cloud" => "ap-northeast-1",
  },
  "Azure-Singapore" => {
    "provider" => "Azure",
    "cloud" => "Azure Southeast Asia",
  },
  "AWS-USA" => {
    "provider" => "AWS",
    "cloud" => "us-west-1",
  },
  "Azure-USA" => {   
    "provider" => "Azure",
    "cloud" => "Azure East US",
  },
}
end

# TO-DO: Get account info from the environment and use the mapping accordingly.
# REAL TO-DO: Once API support is avaiable in CATs, create the security groups, etc in real-time.
# map($map_current_account, 'current_account_name', 'current_account')
# ___ACCOUNT_NAME__ is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "__ACCOUNT_NAME__",
  },
}
end

mapping "map_account" do {
  "CSE Sandbox" => {
    "security_group" => "default",
    "ssh_key" => "default",
  },
  "Hybrid Cloud" => {
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "default",
  },
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
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
  server_template find("Chef Client Beta (v13.5.1)", revision: 32)
  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
  inputs do {
    "chef/client/roles" => join(["text:", $param_role]),
    "chef/client/company" => join(["text:", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_org")]),
    "chef/client/server_url" => join(["text:https://api.opscode.com/organizations/", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_org")]),
    "chef/client/validation_name" => join(["text:", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_username")]),
    "chef/client/validator_pem" => join(["cred:", map($map_hosted_chef_account, "opscode_hosted_chef", "chef_user_validation")]),
    "chef/client/log_level" => "text:debug",  
  } end
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
  call run_recipe_inputs(@client_server, "chef::do_client_converge", { "chef/client/roles": join(["text:", $param_role]) })  
end
