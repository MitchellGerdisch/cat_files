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
#   TBD ....


name 'Multiple Cloud Windows Server Deploment'
rs_ca_ver 20131202
short_description "![Windows](http://www.cscopestudios.com/images/winhosting.jpg)\n
Deploys a pair of Windows servers across AWS and Azure."
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

# _CSE Sandbox is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "CSE Sandbox",
  },
}
end

mapping "map_account" do {
  "CSE Sandbox" => {
    "ssh_key" => "default",
    "group_owner" => "816783988377", # used for Security Group configuration
    "configure_user_script" => "524289004",
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

operation "op_stop_aws_server" do
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
  @aws_server.current_instance().stop
end


  
####################
# Helper functions #
####################
# Helper definition, runs a recipe on given server, waits until recipe completes or fails
# Raises an error in case of failure
define run_recipe(@target, $recipe_name) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

# Helper definition, runs a recipe on given server with the given inputs, waits until recipe completes or fails
# Raises an error in case of failure
define run_recipe_inputs(@target, $recipe_name, $recipe_inputs) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

# Helper definition, runs a script on given server, waits until script completes or fails
# Raises an error in case of failure
define run_script(@target, $right_script_href) do
  @task = @target.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

# Helper definition, runs a script on given server, waits until script completes or fails
# Raises an error in case of failure
define run_script_inputs(@target, $right_script_href, $script_inputs) do
  @task = @target.current_instance().run_executable(right_script_href: $right_script_href, inputs: $script_inputs)
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

# Helper definition, runs a script on all instances in the array.
# waits until script completes or fails
# Raises an error in case of failure
define multi_run_script(@target, $right_script_href) do
  @task = @target.multi_run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

####
# Author: Ryan Geyer
###
define get_array_of_size($size) return $array do
  $qty = 1
  $qty_ary = []
  while $qty <= to_n($size) do
    $qty_ary << $qty
    $qty = $qty + 1
  end

  $array = $qty_ary
end

####
# Loggers
# 
# Author: Ryan Geyer
####

define log_this($message) do
  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
end
 
###
# $notify acceptable values: None|Notification|Security|Error
###
define log($message, $notify) do
  rs.audit_entries.create(notify: $notify, audit_entry: {auditee_href: @@deployment.href, summary: $message})
end

define log_with_details($summary, $details, $notify) do
  rs.audit_entries.create(notify: $notify, audit_entry: {auditee_href: @@deployment.href, summary: $summary, detail: $details})
end

####
# get clouds
#
# Author: Ryan Geyer
####
define get_clouds_by_rel($rel) return @clouds do
  @@clouds = rs.clouds.empty()
  concurrent foreach @cloud in rs.clouds.get() do
    $rels = select(@cloud.links, {"rel": $rel})
    if size($rels) > 0
      @@clouds = @@clouds + @cloud
    end
  end
  @clouds = @@clouds
end

define get_execution_id() return $execution_id do
  #selfservice:href=/api/manager/projects/12345/executions/54354bd284adb8871600200e
  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment
  $href_tag = concurrent map $current_tag in $tags_on_deployment return $tag do
    if $current_tag =~ "(selfservice:href)"
      $tag = $current_tag
    end
  end

  if type($href_tag) == "array" && size($href_tag) > 0
    $tag_split_by_value_delimiter = split(first($href_tag), "=")
    $tag_value = last($tag_split_by_value_delimiter)
    $value_split_by_slashes = split($tag_value, "/")
    $execution_id = last($value_split_by_slashes)
  else
    $execution_id = "N/A"
  end

end

# Author: Ryan Geyer
#
# Converts a server to an rs.servers.create(server: $return_hash) compatible hash
#
# @param @server [ServerResourceCollection] a Server collection containing one
#   server (what happens if it contains more than one?) to be converted
#
# @return [Hash] a hash compatible with rs.servers.create(server: $return_hash)
define server_definition_to_media_type(@server) return $media_type do
  $top_level_properties = [
    "deployment_href",
    "description",
    "name",
    "optimized"
  ]
  $definition_hash = to_object(@server)
  $media_type = {}
  $instance_hash = {}
  foreach $key in keys($definition_hash["fields"]) do
    call log_with_details("Key "+$key, $key+"="+to_json($definition_hash["fields"][$key]), "None")
    if contains?($top_level_properties, [$key])
      $media_type[$key] = $definition_hash["fields"][$key]
    else
      $instance_hash[$key] = $definition_hash["fields"][$key]
    end
  end
  # TODO: Should be able to assign this directly in the "else" block above once
  # https://bookiee.rightscale.com/browse/SS-739 is fixed
  $media_type["instance"] = $instance_hash
end

### Provision Error Handler
define handle_provision_error($count) do
  call log("Handling provision error: " + $_error["message"], "Notification")
  if $count < 5 
    $_error_behavior = "retry"
  end
end

