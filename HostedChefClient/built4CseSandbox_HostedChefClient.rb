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
#   Imported Server Templates:
#     Chef Client Beta (v13.5.1) [rev 32] 
#
#   OpsCode Hosted Chef Setup 
#     Account on OpsCode hosted chef.
#     Organization defined
#     Role and related cookbooks defined (optional but recommended)
# DEMO NOTES:
#   TBD

name "Hosted Chef Client"
rs_ca_ver 20131202
short_description "![Chef](https://www.getchef.com/images/logo.svg)
Builds a Chef Client server that connects to a hosted chef server.
NO ROLE SUPPORT AT THIS TIME."

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
  label "Chef Role(s)" 
  type "string" 
  description "Chef role(s) to apply to the server." 
#  allowed_pattern "[A-Za-z0-9][A-Za-z0-9-_.]*"
  allowed_values "turner", "hooch"
  default "hooch"
end



##############
# MAPPINGS   #
##############

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
# _CSE Sandbox is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "CSE Sandbox",
  },
}
end

mapping "map_account" do {
  "CSE Sandbox" => {
    "security_group" => "default",
    "ssh_key" => "default",
    "chef_org" => "rs_demo",
    "chef_username" => "gerdisch",
    "chef_user_validation" => "GERDISCH_OPSCODE_VALIDATION_KEY",
  },
#  "Hybrid Cloud" => {
#    "security_group" => "IIS_3tier_default_SecGrp",
#    "ssh_key" => "default",
#    "s3_bucket" => "iis-3tier",
#    "restore_db_script_href" => "493424003",
#    "create_db_login_script_href" => "493420003",
#    "restart_iis_script_href" => "527791003",
#  },
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
  description "Assuming the server supports a webservice on port 80, this link can be used to access it."
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
    "chef/client/company" => join(["text:", map($map_account, map($map_current_account, "current_account_name", "current_account"), "chef_org")]),
    "chef/client/server_url" => join(["text:https://api.opscode.com/organizations/", map($map_account, map($map_current_account, "current_account_name", "current_account"), "chef_org")]),
    "chef/client/validation_name" => join(["text:", map($map_account, map($map_current_account, "current_account_name", "current_account"), "chef_username")]),
    "chef/client/validator_pem" => join(["cred:", map($map_account, map($map_current_account, "current_account_name", "current_account"), "chef_user_validation")]),
    "chef/client/log_level" => "text:debug",  
  } end
end


###############
## Operations #
###############

# executes automatically
operation "Apply Role" do
  description "Apply role to server."
  definition "apply_role"
end


##############
# Definitions#
##############

#
# Apply Role
# NOT READY YET
#
define apply_role(@client_server, $param_role) do
  task_label("Apply role")
  call run_recipe_inputs(@client_server, "chef::do_client_converge", { "chef/client/roles": join(["text:", $param_role]) })  
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

