#
#The MIT License (MIT)
#
#Copyright (c) 2014 Bruno Ciscato, Ryan O'Leary, Mitch Gerdisch
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

# Deploys a simplex dev stack for consisting of LB, scalable (based on CPU load) IIS app server and MS SQL server.
# Works in AWS or Azure.
# Includes option to deploy a siege load server and operations to start/stop the load.
#
# No DNS needs to be set up - it passes the information around based on real-time IP assignments.
#
# PREREQUISITES:
#   Imported Server Templates:
#NOT USED AT THIS TIME:     Siege Load Tester, revision: 32
#NOT USED AT THIS TIME:     Load Balancer with HAProxy (v14.1.0), revision: 36
#     Database Manager for MySQL (v14.1.0), revision: 43
#     PHP App Server (v14.1.0), revision: 36
#       Cloned and alerts configured for scaling
#       Name it: PHP App Server (v14.1.0) scaling
#       Modify it:
#         Create Alerts:
#           Grow Alert:
#             Name: Grow
#             Condition: If cpu-idle < 30
#             Vote to Grow with Tag: Tier 2 - App Server
#           Shrink Alert:
#             Name: Shrink
#             Condition: If cpu-idle > 50
#             Vote to Shrink with Tag: Tier 2 - App Server
#   GIT Repo Setup
#     Create a GIT repo
#     Store the database backup file:
#           https://github.com/rightscale/examples/raw/unified_php/app_test.sql.bz2
#     Set up a Deploy Key for the repo and use that for the DEMO_SUPPORT_FILES_KEY below.
#   SSH Key - see mapping for proper names or to change accordingly.
#   Security Group that is pretty wide open that covers all the VMs - see mapping for name.
#     ports: 80, 8000, 3306, 22
#     TODO: Use new security groups resource type to create specific security groups for the tiers.
#   Credentials needed:
#     cred: MYSQL_ROOT_PASSWORD - Used by MySQL ST for root password to MySQL.
#     cred: MYSQL_APP_USERNAME - Used by application to access DB
#     cred: MYSQL_APP_PASSWORD - Used by application to access DB
#     cred: DEMO_SUPPORT_FILES_KEY - This is a deploy key for Mitch's demo_support_files github repo that can be used to access the necessary files for the deployment. 
#
# DEMO NOTES:
#   Scaling:
#     Deploy with siege server and use operations to start/stop load.


name "LAMP Dev Stack"
rs_ca_ver 20131202
short_description "![Lamp Stack](https://selfservice-demo.s3.amazonaws.com/lamp_logo.gif)\n
Builds a basic LAMP website workload."
long_description "Deploys 2-tier LAMP website workload.\n
User can select cloud and performance level."

##############
# PARAMETERS #
##############

parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS-US-East", "AWS-US-West"
  default "AWS-US-West"
end

parameter "param_performance" do 
  category "Deployment Options"
  label "Performance profile" 
  type "string" 
  description "Compute and RAM" 
  allowed_values "low", "medium", "high"
  default "low"
end

#parameter "param_data_file" do 
#  category "S3 info"
#  label "DB initial file" 
#  type "string" 
#  description "Initial file to use for DB" 
#  allowed_pattern "[a-z0-9][a-z0-9-_.]*"
#  default "DotNetNuke.bak"
#end

#parameter "array_min_size" do
#  category "Application Server Array"
#  label "Array Minimum Size"
#  type "number"
#  description "Minimum number of servers in the array"
#  default "1"
#end
#
#parameter "array_max_size" do
#  category "Application Server Array"
#  label "Array Maximum Size"
#  type "number"
#  description "Maximum number of servers in the array"
#  default "5"
#end
#
#parameter "param_deploy_siege_server" do 
#  category "Deployment Options"
#  label "Deploy Siege load generator?" 
#  type "string" 
#  description "Whether or not to deploy a Siege load generator server." 
#  allowed_values "yes", "no"
#  default "yes"
#end

##############
# MAPPINGS   #
##############

mapping "map_instance_type" do {
  "AWS" => {
    "low" => "m3.medium",  
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

# Customized for VC POC to represent AWS clouds where things are set up for the CAT (e.g. SSH keys)
mapping "map_cloud" do {
  "AWS-US-East" => {
    "provider" => "AWS",
    "cloud" => "us-east-1",
  },
  "AWS-US-West" => {
    "provider" => "AWS",
    "cloud" => "us-west-1",
  },
}
end

# TO-DO: Get account info from the environment and use the mapping accordingly.
# REAL TO-DO: Once API support is avaiable in CATs, create the security groups, etc in real-time.
# map($map_current_account, 'current_account_name', 'current_account')
# _VC infrastructure is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "VC infrastructure",
  },
}
end

mapping "map_account" do {
  "CSE Sandbox" => {
    "security_group" => "LAMP_3tier_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "three-tier-scaling",
    "siege_start_load_href" => "530065004",
    "siege_stop_load_href" => "530066004",
  },
  "Hybrid Cloud" => {
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "iis-3tier",
    "siege_start_load_href" => "443613001",
    "siege_stop_load_href" => "443616001",
  },
  "VC infrastructure" => {
    "security_group" => "LAMP_default_secgrp", # TODO: Use CAT security group resource type to define security groups for each tier in CAT.
    "ssh_key" => "default",
    "s3_bucket" => "vc-poc", 
    "siege_start_load_href" => "530594004",
    "siege_stop_load_href" => "530595004",
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

output "end2end_test" do
  label "Basic Website test" 
  category "Connect"
  default_value join(["http://", @appserver_1.public_ip_address,":8000/dbread"])
  description "Verifies access through LB #1 to App server and App server access to the DB server."
end

output "phpinfo" do
  label "PHP Server Info" 
  category "Connect"
  default_value join(["http://", @appserver_1.public_ip_address,":8000/phpinfo.php"])
  description "Displays given App server's PHP info."
end

##############
# RESOURCES  #
##############

resource "db_1", type: "server" do
  name "Tier 3 - DB 1"
  cloud map( $map_cloud, $param_location, "cloud" )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
# server_template find("Database Manager for MySQL 5.5 (v13.5.10-LTS)", revision: 32)
  server_template find("Database Manager for MySQL (v14.1.0)", revision: 43)
#  security_groups map( $map_account, map($map_current_account, "current_account_name", "current_account"), "security_group" )
#  ssh_key map( $map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key" )
  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
  inputs do {
    # TEMP 'db/backup/lineage' => join(['text:selfservice-demo-lineage-',@@deployment.href]),
    'rs-mysql/server_root_password' => 'cred:MYSQL_ROOT_PASSWORD',
    'rs-mysql/application_password' => 'cred:MYSQL_APP_PASSWORD',
    'rs-mysql/application_username' => 'cred:MYSQL_APP_USERNAME',
    'rs-mysql/backup/lineage' => 'text:selfservice-demo-lineage-test1124',
    'rs-mysql/device/count' => 'text:1',
    'rs-mysql/device/destroy_on_decommission' => 'text:true',
    'rs-mysql/application_database_name' => 'text:app_test',
    'rs-mysql/import/dump_file' => 'text:app_test.sql.bz2',
    'rs-mysql/import/private_key' => 'cred:DEMO_SUPPORT_FILES_KEY',
    'rs-mysql/import/repository' => 'text:git@github.com:MitchellGerdisch/demo_support_files.git',
    'rs-mysql/import/revision' => 'text:master',
    'rs-mysql/dns/master_fqdn' => 'env:Tier 3 - DB 1:PRIVATE_IP',
} end
end


resource "appserver_1", type: "server" do
  name "Tier 2 - App Server"
  cloud map( $map_cloud, $param_location, "cloud" )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
  server_template find("PHP App Server (v14.1.0)", revision: 36)
#  security_groups map( $map_account, map($map_current_account, "current_account_name", "current_account"), "security_group" )
#  ssh_key map( $map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key" )
  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
  inputs do {
    'rs-application_php/application_name' => 'text:test_app',
    'rs-application_php/database/host' => 'env:Tier 3 - DB 1:PRIVATE_IP',
    'rs-application_php/database/password' => 'cred:MYSQL_APP_PASSWORD',
    'rs-application_php/database/user' => 'cred:MYSQL_APP_USERNAME',
    'rs-application_php/database/schema' => 'text:app_test',
    'rs-application_php/scm/repository' => 'text:git://github.com/rightscale/examples.git',
    'rs-application_php/scm/revision' => 'text:unified_php',
    'rs-application_php/listen_port' => 'text:8000',
    'rs-application_php/vhost_path' => 'text:default',
  } end
end


###############
## Operations #
###############

# executes automatically
operation "launch" do
  description "Launches all the servers concurrently"
  definition "launch_concurrent"
end

# executes automatically
operation "enable" do
  description "Initializes the master DB, imports a DB dump and gets application running."
  definition "enable_application"
end 



##############
# Definitions#
##############

#
# Launch operation
#

define launch_concurrent(@db_1, @appserver_1) return @db_1, @appserver_1 do
    task_label("Launch servers concurrently")

    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    
    @@launch_task_db1 = @db_1
    @@launch_task_appserver1 = @appserver_1

    # Do just the DB and LB concurrently.
    # It may be the case that the DB server needs to be operational before the App server will work properly.
    # There's a known issue in DotNetNuke where it'll throw the under construction page if the DB server we restarted after the app server connected.
    concurrent do
      
      sub task_name:"Launch DB-1" do
        task_label("Launching DB-1")
        provision(@@launch_task_db1)
      end

      sub task_name:"Launch app server" do
        task_label("Launching App Server")
        sleep(60) # Give the DB a chance to at least get created, App server needs its Private PRIVATE_IP
        provision(@@launch_task_appserver1)
      end
      
    end

    # Copy the globally-scoped resources back into the SS-scoped resources that we're returning
    @db_1 = @@launch_task_db1
    @appserver_1 = @@launch_task_appserver1
end

define handle_provision_error($count) do
  call log("Handling provision error: " + $_error["message"], "Notification")
  if $count < 5 
    $_error_behavior = "retry"
  end
end

# Enable operation
#

#define enable_application(@db_1, @server_array_1) do
define enable_application(@db_1) do
  
  task_label("Enabling monitoring for MySQL server.")
  call run_recipe(@db_1, "rs-mysql::collectd")
  
  task_label("Configuring storage volume.")
  call run_recipe(@db_1, "rs-mysql::volume")
  
  task_label("Configuring MySQL server as master.")
  call run_recipe(@db_1, "rs-mysql::master")
  
  task_label("Restoring DB from backup file.")
  call run_recipe(@db_1, "rs-mysql::dump_import")


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

define multi_run_recipe(@target, $recipe_name) do
  @task = @target.multi_run_executable(recipe_name: $recipe_name, inputs: {})
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


###
# $notify acceptable values: None|Notification|Security|Error
###
define log($message, $notify) do
  rs.audit_entries.create(notify: $notify, audit_entry: {auditee_href: @@deployment.href, summary: $message})
end

