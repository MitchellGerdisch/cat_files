#
#The MIT License (MIT)
#
#Copyright (c) 2014 BMitch Gerdisch
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
# A simple CAT file for a single Linux server.
# Used to play with ideas and approaches.
#
# User picks geographical location and performance level (CPU/RAM).
# CAT maps the location to a cloud AWS, Azure, Rackspace.
# CAT maps performance level to an instance type in the given cloud
# CAT deploys the RightImage_Ubuntu_12.04_x64_v13.5 [rev 33] image based on the above.
#   This image is a multicloud image for AWS, Azure and RackSpace.

name 'Simple Linux Server'
rs_ca_ver 20131202
short_description 'Deploys single Linux server.'


##############
# PARAMETERS #
##############

# User can select a geographical location for the server which will then pick a cloud and zone based on the mapping below.
# User can also select size parameter which is mapped to a given instance type/flavor for the selected cloud.

parameter "param_location" do 
  category "Deployment Options"
  label "Location" 
  type "string" 
  description "Geographical location for the server." 
  allowed_values "AWS US-East", "AWS US-West"
  default "AWS US-East"
end

parameter "param_performance" do 
  category "Deployment Options"
  label "Performance profile" 
  type "string" 
  description "Compute and RAM" 
  allowed_values "low", "medium", "high"
  default "low"
end




##############
# MAPPINGS   #
##############


mapping "map_instance_type" do {
  "AWS" => {
    "low" => "m1.small",  
    "medium" => "c3.xlarge", # 4 CPUs x 7GB
    "high" => "c3.2xlarge", # 8 CPUs x 15GB
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
  "AWS US-East" => {
    "provider" => "AWS",
    "cloud" => "us-east-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "AWS US-West" => {
    "provider" => "AWS",
    "cloud" => "us-west-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
}
end


##############
# CONDITIONS #
##############
# NONE #


##############
# OUTPUTS    #
##############

output 'ip_address' do
  label "Server IP Address" 
  category "Server Info"
  default_value @your_server.public_ip_address
  description "IP address of server."
end
 
output 'cloud' do
  label "Cloud" 
  category "Server Info"
  default_value @your_server.cloud
  description "Cloud used for the server deployment."
end

output 'instance_type' do
  label "Server specs"
  category "Server Info"
  default_value join([ $param_performance, ' (', @your_server.instance_type, ')'])
  description "The selected server performance level and related cloud instance_type"
end

##############
# RESOURCES  #
##############

resource 'your_server', type: 'server' do
  name 'Your Server'
  cloud map($map_cloud, $param_location, 'cloud')
  instance_type map( $map_instance_type, map( $map_cloud, $param_location,'provider'), $param_performance)
  server_template find('Base ServerTemplate for Linux (v13.5.5-LTS)', revision: 21)
  security_groups map( $map_cloud, $param_location, 'security_group' )
  ssh_key map( $map_cloud, $param_location, 'ssh_key' )
end

##############
# Operations #
##############
operation "enable" do
  description "Fake enabling the server (runs automatically)"
  definition "enable_server"
end

operation "manual_sub_task" do
  description "Fake manual task with Sub to play with"
  definition "do_manual_sub_task"
end

operation "manual_nosub_task" do
  description "Fake manual task with no Sub to play with"
  definition "do_manual_nosub_task"
end

###############
# Definitions #
###############


define enable_server(@your_server) do
  call log_this("At beginning of enable_server")
  task_label("Task: enable_server")
  sub task_name: "Enable Server Sub task" do
    call log_this("At beginning of enable sub task")
    log_title("MRG_ENABLE_LOG_TITLE")
    log_info("MRG_ENABLE_LOG_INFO: Just putting a log info message.")
    log_error("MRG_ENABLE_LOG_ERROR: This is what a log error looks like.")
  end
  call log_this("End of enable_server")
end

define do_manual_sub_task(@your_server) do
  call log_this("Beginning of do_manual_sub_task")
  task_label("Task: Pretending to do something when doing a manual task")
  sub task_name: "Do manual_sub_task Sub task" do
    call log_this("Beginning of manual_task_sub")
#    log_title("MRG_MANUAL_LOG_TITLE")
#    log_info("MRG_MANUAL_LOG_INFO: Just putting a log info message.")
#    log_error("MRG_MANUAL_LOG_ERROR: This is what a log error looks like.")
  end
  call log_this("End of do_manual_sub_task")
end

define do_manual_nosub_task(@your_server) do
  call log_this("Beginning of do_manual_no_sub_task")
#  log_title("MRG_MANUAL_NOSUBLOG_TITLE")
#  log_info("MRG_MANUAL_NOSUBLOG_LOG_INFO: Just putting a log info message.")
#  log_error("MRG_MANUAL_NOSUBLOG_LOG_ERROR: This is what a log error looks like.")
  call log_this("End of do_manual_no_sub_task")
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

