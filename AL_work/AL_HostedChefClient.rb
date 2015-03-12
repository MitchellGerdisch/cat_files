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
    "chef_user_validation" => "RIGHTSCALE_GERDISCH_OPSCODE_VALIDATION_KEY",
  }
}
end


##############
# OUTPUTS    #
##############

output "server_url" do
  label "Server URL" 
  category "Connect"
  default_value join(["http://", @client_server.private_ip_address])
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
  cloud 'EC2 us-east-1'
  ssh_key 'adam.alexander'
  subnets find(resource_uid: 'subnet-7eb8e638', network_href: '/api/networks/E3118NLDQQGGH')
  security_groups 'httpandssh'
  instance_type 'm3.medium'
  server_template find("Chef Client Beta (v13.5.1)", revision: 32)
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

