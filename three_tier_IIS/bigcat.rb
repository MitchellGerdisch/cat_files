#x
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
#
# No DNS needs to be set up - it passes the information around based on real-time IP assignments.
#
# PREREQUISITES:
#   Imported Server Templates:
#     Load Balancer with HAProxy (v13.5.5-LTS), revision: 18 
#     Database Manager for Microsoft SQL Server (13.5.1-LTS), revision: 5
#     Microsoft IIS App Server (v13.5.0-LTS), revision: 3
#       Cloned and alerts configured for scaling - needed until I can figure out how to do it in CAT for the array itself.
#       Name it: Microsoft IIS App Server (v13.5.0-LTS) scaling
#       Modify it:
#         Create Alerts:
#           Grow Alert:
#             Name: Grow
#             Condition: If cpu-idle < 30
#             Vote to Grow with Tag: Tier 2 - IIS App Server
#           Shrink Alert:
#             Name: Shrink
#             Condition: If cpu-idle > 50
#             Vote to Shrink with Tag: Tier 2 - IIS App Server
#   Links to the given script calls down below in the enable operation need to be modified for the given account (I believe)
#   S3 Storage Setup
#     Create a bucket and update the mapping if necessary.
#     Store the database backup and application files:
#       Database backup file on S3 - as per tutorial using the provided DotNetNuke.bak file found here:
#           http://support.rightscale.com/@api/deki/files/6208/DotNetNuke.bak
#       Application file on S3 - as per tutorial using the provided DotNetNuke.zip file found here:
#           http://support.rightscale.com/@api/deki/files/6292/DotNetNuke.zip
#   SSH Key - see mapping for proper names or to change accordingly.
#   Security Group that is pretty wide open that covers all the VMs - see mapping for name.
#     ports: 80, 8000, 1433, 3389
#   The usual set of credentials as per the tutorial which are likely already available in the account.
#     WINDOWS_ADMIN_PASSWORD - Password used by user, Administrator to login to the windows VMs.
#     SQL_APPLICATION_USER - SQL database user with login privileges to the specified user database.
#     SQL_APPLICATION_PASSWORD - Password for the SQL database user with login privileges to the specified user database.
#     DBADMIN_PASSWORD - The password to encrypt the master key when it's created or decrypt it when opening an existing master key.
#
# DEMO NOTES:
#   Scaling:
#     Login to the App instance and download http://download.sysinternals.com/files/CPUSTRES.zip
#     Unzip file and run CPUSTRES.exe
#     Enable two threads at maximum and that should load the CPU and cause scaling.


name 'IIS-SQL Dev Stack'
rs_ca_ver 20131202
short_description '![Windows](http://www.cscopestudios.com/images/winhosting.jpg)
Builds an HAproxy-IIS-MS_SQL 3-tier website architecture in the cloud using RightScale\'s ServerTemplates and a Cloud Application Template.'

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

parameter "param_data_file" do 
  category "S3 info"
  label "DB initial file" 
  type "string" 
  description "Initial file to use for DB" 
  allowed_pattern "[a-z0-9][a-z0-9-_.]*"
  default "DotNetNuke.bak"
end

parameter "array_min_size" do
  category "Application Server Array"
  label "Array Minimum Size"
  type "number"
  description "Minimum number of servers in the array"
  default "1"
end

parameter "array_max_size" do
  category "Application Server Array"
  label "Array Maximum Size"
  type "number"
  description "Maximum number of servers in the array"
  default "5"
end


##############
# MAPPINGS   #
##############

mapping "map_instance_type" do {
  "AWS" => {
    "low" => "c3.large",  
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
  "AWS-Australia" => {
    "provider" => "AWS",
    "cloud" => "ap-southeast-2",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "AWS-Brazil" => {
    "provider" => "AWS",
    "cloud" => "sa-east-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Azure-Netherlands" => {
    "provider" => "Azure",
    "cloud" => "Azure West Europe",
    "security_group" => null,
    "ssh_key" => null,
  },
  "AWS-Japan" => {
    "provider" => "AWS",
    "cloud" => "ap-northeast-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Azure-Singapore" => {
    "provider" => "Azure",
    "cloud" => "Azure Southeast Asia",
    "security_group" => null,
    "ssh_key" => null,
  },
  "AWS-USA" => {
    "provider" => "AWS",
    "cloud" => "us-east-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Azure-USA" => {   
    "provider" => "Azure",
    "cloud" => "Azure East US",
    "security_group" => null,
    "ssh_key" => null,
  },
}
end

# TO-DO: Get account info from the environment and use the mapping accordingly.
# REAL TO-DO: Once API support is avaiable in CATs, create the security groups, etc in real-time.
# map($map_current_account, 'current_account_name', 'current_account')
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => 'CSE Sandbox',
  },
}
end

mapping "map_account" do {
  "CSE Sandbox" => {
    "security_group" => "CE_default_SecGrp",
    "ssh_key" => "MitchG_sshKey_2",
    "s3_bucket" => "consumers-energy",
    "restore_db_script_href" => "524831004",
    "create_db_login_script_href" => "524829004",
    "restart_iis_script_href" => "524965004",
  },
  "Hybrid Cloud" => {
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "CE_sshkey_HybridCloud",
    "s3_bucket" => "iis-3tier",
    "restore_db_script_href" => "493424003",
    "create_db_login_script_href" => "493420003",
    "restart_iis_script_href" => "527791003",
  },
}
end

##############
# CONDITIONS #
##############



##############
# OUTPUTS    #
##############

output 'end2end_test' do
  label "End to End Test" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address])
  description "Verifies access through LB #1 to App server and App server access to the DB server."
end

output 'haproxy_status' do
  label "Load Balancer Status Page" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address, "/haproxy-status"])
  description "Accesses Load Balancer status page"
end

##############
# RESOURCES  #
##############

resource 'lb_1', type: 'server' do
  name 'Tier 1 - LB 1'
  cloud map( $map_cloud, $param_location, 'cloud' )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,'provider'), $param_performance)
  server_template find('Load Balancer with HAProxy (v13.5.5-LTS)', revision: 18)
  security_groups map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'security_group' )
  ssh_key map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'ssh_key' )
  inputs do {
    'lb/session_stickiness' => 'text:false',   
  } end
end

resource 'db_1', type: 'server' do
  name 'Tier 3 - DB 1'
  cloud map( $map_cloud, $param_location, 'cloud' )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,'provider'), $param_performance)
  server_template find("Database Manager for Microsoft SQL Server (13.5.1-LTS)", revision: 5)
  security_groups map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'security_group' )
  ssh_key map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'ssh_key' )
    inputs do {
      'ADMIN_PASSWORD' => 'cred:WINDOWS_ADMIN_PASSWORD',
      'BACKUP_FILE_NAME' => 'text:DotNetNuke.bak',
      'BACKUP_VOLUME_SIZE' => 'text:10',
      'DATA_VOLUME_SIZE' => 'text:10',
      'DB_LINEAGE_NAME' => join(['text:selfservice-demo-lineage-',@@deployment.href]),
      'DB_NAME' => 'text:DotNetNuke',
      'DB_NEW_LOGIN_NAME' => 'cred:SQL_APPLICATION_USER',
      'DB_NEW_LOGIN_PASSWORD' => 'cred:SQL_APPLICATION_PASSWORD',
      'DNS_SERVICE' => 'text:Skip DNS registration',
#      'DNS_DOMAIN_NAME' => 'env:Tier 3 - DB 1:PRIVATE_IP',
#      'DNS_ID' => 'text:14762727',
#      'DNS_PASSWORD' => 'cred:DNS_MADE_EASY_PASSWORD',
#      'DNS_USER' => 'cred:DNS_MADE_EASY_USER',
      'LOGS_VOLUME_SIZE' => 'text:1',
      'MASTER_KEY_PASSWORD' => 'cred:DBADMIN_PASSWORD',
      'REMOTE_STORAGE_ACCOUNT_ID' => 'cred:AWS_ACCESS_KEY_ID',
      'REMOTE_STORAGE_ACCOUNT_PROVIDER' => 'text:Amazon_S3',
      'REMOTE_STORAGE_ACCOUNT_SECRET' => 'cred:AWS_SECRET_ACCESS_KEY',
      'REMOTE_STORAGE_CONTAINER' => join(['text:', map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 's3_bucket' )]),
      'SYS_WINDOWS_TZINFO' => 'text:Pacific Standard Time',
  } end
end


resource 'server_array_1', type: 'server_array' do
  name 'Tier 2 - IIS App Servers'
  cloud map( $map_cloud, $param_location, 'cloud' )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,'provider'), $param_performance)
  #server_template find('Microsoft IIS App Server (v13.5.0-LTS)', revision: 3)
  server_template find('Microsoft IIS App Server (v13.5.0-LTS) scaling')
  security_groups map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'security_group' )
  ssh_key map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'ssh_key' )
  inputs do {
    'REMOTE_STORAGE_ACCOUNT_ID_APP' => 'cred:AWS_ACCESS_KEY_ID',
    'REMOTE_STORAGE_ACCOUNT_PROVIDER_APP' => 'text:Amazon_S3',
    'REMOTE_STORAGE_ACCOUNT_SECRET_APP' => 'cred:AWS_SECRET_ACCESS_KEY',
    'REMOTE_STORAGE_CONTAINER_APP' => join(['text:', map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 's3_bucket' )]),
    'ZIP_FILE_NAME' => 'text:DotNetNuke.zip',
    'OPT_CONNECTION_STRING_DB_NAME' => 'text:DotNetNuke',
    'OPT_CONNECTION_STRING_DB_SERVER_NAME' => 'env:Tier 3 - DB 1:PRIVATE_IP',
    'OPT_CONNECTION_STRING_DB_USER_ID' => 'cred:SQL_APPLICATION_USER',
    'OPT_CONNECTION_STRING_DB_USER_PASSWORD' => 'cred:SQL_APPLICATION_PASSWORD',
    'OPT_CONNECTION_STRING_NAME' => 'text:SiteSqlServer',
    'ADMIN_PASSWORD' => 'cred:WINDOWS_ADMIN_PASSWORD',
    'SYS_WINDOWS_TZINFO' => 'text:Pacific Standard Time',    
  } end
  state 'enabled'
  array_type 'alert'
  elasticity_params do {
    'bounds' => {
      'min_count'            => $array_min_size,
      'max_count'            => $array_max_size
    },
    'pacing' => {
      'resize_calm_time'     => 20, 
      'resize_down_by'       => 1,
      'resize_up_by'         => 1
    },
    'alert_specific_params' => {
      'decision_threshold'   => 51,
      'voters_tag_predicate' => 'Tier 2 - IIS App Server'
    }
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
  description "Initializes the master DB, imports a DB dump and restarts the IIS application."
  definition "enable_application"
end 

# allows user to import a DB dump at any time (operational script).
# Not supported at this time
#operation "Import DB dump" do
#  description "Run script to import the DB dump"
#  definition "import_db_dump"
#end


##############
# Definitions#
##############

#
# Launch operation
#

define launch_concurrent(@lb_1, @db_1, @server_array_1) return @lb_1, @db_1, @server_array_1 do
    task_label("Launch servers concurrently")

    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    
    @@launch_task_lb1 = @lb_1
    @@launch_task_db1 = @db_1
    @@launch_task_array1 = @server_array_1

    # Do just the DB and LB concurrently.
    # It may be the case that the DB server needs to be operational before the App server will work properly.
    # There's a known issue in DotNetNuke where it'll throw the under construction page if the DB server we restarted after the app server connected.
    concurrent do
      sub task_name:"Launch LB-1" do
        task_label("Launching LB-1")
        $lb1_retries = 0 
        sub on_error: handle_provision_error($lb1_retries) do
          $lb1_retries = $lb1_retries + 1
          provision(@@launch_task_lb1)
        end
      end
      
      sub task_name:"Launch DB-1" do
        task_label("Launching DB-1")
        $db1_retries = 0 
        sub on_error: handle_provision_error($db1_retries) do
          $db1_retries = $db1_retries + 1
          provision(@@launch_task_db1)
        end
      end

      sub task_name:"Provision Server Array" do
        task_label("Provision Server Array: Provisioning the array now.")
        sleep(90) # Give the DB a chance to at least get created, App server needs its Private PRIVATE_IP
        $app_retries = 0 
        sub on_error: handle_provision_error($app_retries) do
          $app_retries = $app_retries + 1
          provision(@@launch_task_array1)
        end
      end
    end

    # Copy the globally-scoped resources back into the SS-scoped resources that we're returning
    @lb_1 = @@launch_task_lb1
    @db_1 = @@launch_task_db1
    @server_array_1 = @@launch_task_array1
end

define handle_provision_error($count) do
  call log("Handling provision error: " + $_error["message"], "Notification")
  if $count < 5 
    $_error_behavior = 'retry'
  end
end
#
# Enable operation
#

define enable_application(@db_1, @server_array_1, $map_cloud, $param_location) do
  
  $restore_db_script = map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'restore_db_script_href' )
  $create_db_login_script = map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'create_db_login_script_href' )
  $restart_iis_script = map( $map_account, map($map_current_account, 'current_account_name', 'current_account'), 'restart_iis_script_href' )
  
  task_label("Restoring DB from backup file.")
  # call run_recipe(@db_1, "DB SQLS Restore database from local disk / Remote Storage (v13.5.0-LTS)")
  # call run_script(@db_1, "/api/right_scripts/524831004")
  call run_script(@db_1,  join(["/api/right_scripts/", $restore_db_script]))

  task_label("Creating App login to the DB.")
  # call run_recipe(@db_1, "DB SQLS Create login (v13.5.0-LTS)")
  # call run_script(@db_1, "/api/right_scripts/524829004")
  call run_script(@db_1,  join(["/api/right_scripts/", $create_db_login_script]))

  task_label("Restarting IIS so it can connect to DB.")
  # call run_recipe(@server_array_1, "IIS Restart application (v13.5.0-LTS)")
  # call multi_run_script(@server_array_1, "/api/right_scripts/524965004")
  call multi_run_script(@server_array_1,  join(["/api/right_scripts/", $restart_iis_script]))

end
 
#
# Import DB operation
#

define import_db_dump(@db_1) do
  task_label("Import the DB dump")
  call run_recipe(@db_1, "db::do_dump_import")  
end

## Helper definition, runs a recipe on given server, waits until recipe completes or fails
## Raises an error in case of failure
#define run_recipe(@target, $recipe_name) do
#  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: {})
#  sleep_until(@task.summary =~ "^(completed|failed)")
#  if @task.summary =~ "failed"
#    raise "Failed to run " + $recipe_name
#  end
#end
#
## Helper definition, runs a script on given server, waits until script completes or fails
## Raises an error in case of failure
#define run_script(@target, $right_script_href) do
#  @task = @target.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
#  sleep_until(@task.summary =~ "^(completed|failed)")
#  if @task.summary =~ "failed"
#    raise "Failed to run " + $right_script_href
#  end
#end
#
## Helper definition, runs a script on all instances in the array.
## waits until script completes or fails
## Raises an error in case of failure
#define multi_run_script(@target, $right_script_href) do
#  @task = @target.multi_run_executable(right_script_href: $right_script_href, inputs: {})
#  sleep_until(@task.summary =~ "^(completed|failed)")
#  if @task.summary =~ "failed"
#    raise "Failed to run " + $right_script_href
#  end
#end
#
#define log($message) do
#  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
#end
  
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

