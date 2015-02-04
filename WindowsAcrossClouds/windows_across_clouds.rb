#
#The MIT License (MIT)
#
#Copyright (c) 2014 By Mitch Gerdisch
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

# DESCRIPTION
# Deploys a pair of Windows servers across AWS and Azure.
# Demonstrates:
#   multi-cloud support,
#   stop/start capability,


name 'Windows Server Deployment'
rs_ca_ver 20131202
short_description "![Windows](http://www.cscopestudios.com/images/winhosting.jpg)\n
Deploys a pair of Windows servers across AWS and Azure.\n
Application can be stopped and started."
long_description "Deploys a pair of Windows servers.\n"

##############
# PARAMETERS #
##############

parameter "param_username" do 
  category "User Information"
  label "User Name" 
  description "User name you want to use when accessing the jump and QA servers." 
  type "string" 
  no_echo "false"
end

parameter "param_password" do 
  category "User Information"
  label "User Password" 
  description "Password you want to use when accessing the jump and QA servers." 
  type "string" 
  no_echo "true"
end


##############
# MAPPINGS   #
##############

# ___ACCOUNT_NAME__ is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "__ACCOUNT_NAME__",
  },
}
end

mapping "map_account" do {
  "CSE Sandbox" => {
    "ssh_key" => "default",
    "configure_user_script" => "524289004",
  },
  "Hybrid Cloud" => {
    "ssh_key" => "default",
    "configure_user_script" => "493406003",
  },
}
end


##############
# CONDITIONS #
##############

# No conditions


##############
# OUTPUTS    #
##############

output "aws_server_ip" do
  label "AWS Server IP Address" 
  category "Connect"
  default_value @aws_server.public_ip_address
  description "IP address of the AWS server."
end

# TO DO NEED TO GET PORT INFO - SEE JnJ RECIPE
#output "azure_server_ip" do
#  label "Azure Server IP Address" 
#  category "Connect"
#  default_value @azure_server.private_ip_address
#  description "IP address of the Azure server."
#end


##############
# RESOURCES  #
##############

resource "aws_server_sg", type: "security_group" do
  name join(["aws_server_SG-",@@deployment.href])
  description "AWS Windows Server security group."
  cloud "EC2 us-east-1"
end

resource "aws_server_rule_rdp", type: "security_group_rule" do
  name "AWS Windows Server RDP Rule"
  description "Allow RDP access to AWS Windows server."
  source_type "cidr_ips"
  security_group @aws_server_sg
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0" # Can be set to be more restrictive
  protocol_details do {
    "start_port" => "3389",
    "end_port" => "3389"
  } end
end


resource "aws_server", type: "server" do
  name "AWS Windows Server"
  cloud "us-east-1"
  instance_type  "m3.medium"
  server_template find("Base ServerTemplate for Windows (v13.5.0-LTS)", revision: 3)
  ssh_key map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key")
  security_groups @aws_server_sg
  inputs do {
      "ADMIN_PASSWORD" => "cred:WINDOWS_ADMIN_PASSWORD",
      "SYS_WINDOWS_TZINFO" => "text:Central Standard Time",
  } end
end

#resource "azure_server", type: "server" do
#  name "QA Server"
#  cloud "Azure East US"
#  instance_type  "medium"
#  server_template find("Base ServerTemplate for Windows (v13.5.0-LTS)", revision: 3)
#  inputs do {
#      "ADMIN_PASSWORD" => "cred:WINDOWS_ADMIN_PASSWORD",
#      "SYS_WINDOWS_TZINFO" => "text:Central Standard Time",
#  } end
#end


###############
## Operations #
###############

# concurrently launch the servers
operation "launch" do
  description "Launches all the servers concurrently"
  definition "launch_concurrent"
end

# configure the servers 
operation "enable" do
  description "Configures the servers"
  definition "configure_servers"
end

operation "start" do
  description "Starts the servers"
  definition "start_servers"
end

operation "stop" do
  description "Stops the servers"
  definition "stop_servers"
end

operation "stop_aws_server" do
  description "Stop the AWS server."
  definition "stop_aws_server"
end


##############
# Definitions#
##############

# Concurrently launch the servers
define launch_concurrent(@aws_server, @aws_server_sg, @aws_server_rule_rdp) return @aws_server, @aws_server_sg, @aws_server_rule_rdp do
#define launch_concurrent(@aws_server, @azure_server, @aws_server_sg, @aws_server_rule_rdp) return @aws_server, @azure_server, @aws_server_sg, @aws_server_rule_rdp do
    task_label("Launching servers concurrently")
    
    # Although the security groups will be automatically provisioned when the servers are provisioned, 
    # it's necessary to provision the rules explicitly so they'll be defined when the groups are created.
    provision(@aws_server_rule_rdp)

    # Globals for the concurrent block
    @@aws_server = @aws_server
#    @@azure_server = @azure_server

    # Launch the servers concurrently to speed up deployment.
    concurrent do
      provision(@@aws_server)
#      provision(@@azure_server)
    end
    
    @aws_server = @@aws_server
#    @azure_server = @@azure_server

end

# Configure the servers for use
define configure_servers(@aws_server, $map_current_account, $map_account, $param_username, $param_password) do
#define configure_servers(@aws_server, @azure_server, $map_current_account, $map_account, $param_username, $param_password) do
  task_label("Configuring the servers")
 
  # Gather up the script references
  $cur_account = map($map_current_account, "current_account_name", "current_account")
  $configure_user_script = map( $map_account, $cur_account, "configure_user_script" )
  
  # Configure the user and password on both servers
  task_label("Configuring user, " + $param_username)
  call run_script_inputs(@aws_server,  join(["/api/right_scripts/", $configure_user_script]), { ADMIN_ACCOUNT_NAME:"text:"+$param_username, ADMIN_PASSWORD:"text:"+$param_password }) 
#  call run_script_inputs(@azure_server,  join(["/api/right_scripts/", $configure_user_script]), { ADMIN_ACCOUNT_NAME:"text:"+$param_username, ADMIN_PASSWORD:"text:"+$param_password }) 

end

define start_servers(@aws_server) do
  task_label("Starting the servers. NO-OP AT THIS TIME")
end

define stop_servers(@aws_server) do
  task_label("Stopping the servers. NO-OP AT THIS TIME")
end
define stop_aws_server(@aws_server) do
  task_label("Stopping the AWS ")
  @aws_server.current_instance().stop()
end

