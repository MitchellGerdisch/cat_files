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

# OVERVIEW:
# Deploys the standard LB-PHP-MySQL three tier stack.
#   Simplex LB and DB
#   Scalable APP server
#     Includes a script to make scaling easy. See below for prerequisites.
# No DNS needs to be set up - it passes the information around based on real-time IP assignments.
#
# PREREQUISITES:
#   Imported Server Templates:
#     Load Balancer with HAProxy (v13.5.5-LTS), revision: 18 
#     Database Manager for MySQL 5.5 (v13.5.10-LTS), revision: 32
#     PHP App Server (v13.5.5-LTS), revision:19 
#       Cloned and alerts configured for scaling - needed until I can figure out how to do it in CAT for the array itself.
#       Name it: PHP App Server (V13.5.5-LTS) scaling
#       Modify it:
#         Create Alerts:
#           Grow Alert:
#             Name: Grow
#             Condition: If cpu-idle < 30
#             Vote to Grow with Tag: PHP App Server Array (this must match the name of the resource in the CAT below)
#           Shrink Alert:
#             Name: Shrink
#             Condition: If cpu-idle > 50
#             Vote to Shrink with Tag: PHP App Server Array (this must match the name of the resource in the CAT below)
# WORK IN PROGRESS:        Create and attach rightscript for scaling.
#           Should manipulate cpu load or whatever you chose for the Grow and Shrink alerts.
#           Example:
#               TBD
#   S3 Storage Setup
#     Create a bucket and update the mapping below if necessary.
#     Store the database backup and application files:
#       Database backup file on S3 - as per 3-tier tutorial using the provided http://support.rightscale.com/@api/deki/files/6241/app_test-201109010029.gz
#       Application file on S3 - as per tutorial using the provided http://support.rightscale.com/@api/deki/files/6299/phptest.tgz
#   SSH Key - see mapping for proper names or to change accordingly or just set one called "default"
#   Security Group that is pretty wide open that covers all the VMs - see mapping for name.
#     ports: 80, 8000, 3306
#   The usual set of credentials as per the tutorial which are likely already available in the account.
#     WINDOWS_ADMIN_PASSWORD - Password used by user, Administrator to login to the windows VMs.
#     SQL_APPLICATION_USER - SQL database user with login privileges to the specified user database.
#     SQL_APPLICATION_PASSWORD - Password for the SQL database user with login privileges to the specified user database.
#     DBADMIN_PASSWORD - The password to encrypt the master key when it's created or decrypt it when opening an existing master key.
#
# DEMO NOTES:
# WORK IN PROGRESS  Scaling:
#     Run scaler script ... ONCE ITS READY AND WORKING....


name 'HAproxy-PHP-MySQL Dev Stack'
rs_ca_ver 20131202
short_description 'Builds a scalable HAproxy-PHP-MySQL 3-tier website architecture in the cloud using RightScale\'s ServerTemplates and a Cloud Application Template.'

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
  allowed_values "Australia", "Brazil", "Japan", "Netherlands", "Singapore", "USA"
  default "USA"
end

parameter "param_performance" do 
  category "Deployment Options"
  label "Performance profile" 
  type "string" 
  description "Compute and RAM" 
  allowed_values "low", "medium", "high"
  default "low"
end

parameter "param_s3_bucket" do 
  category "S3 info"
  label "Bucket Name" 
  type "string" 
  description "Where DB and Application files are stored." 
  allowed_pattern "[a-z0-9][a-z0-9-.]*"
  default "three-tier-scaling"
end

parameter "param_db_file" do 
  category "S3 info"
  label "DB initial file" 
  type "string" 
  description "Initial file to use for DB" 
  allowed_pattern "[a-z0-9][a-z0-9-_.]*"
  default "app_test-201109010029.gz"
end

parameter "param_app_file" do 
  category "S3 info"
  label "Application file" 
  type "string" 
  description "PHP application file." 
  allowed_pattern "[a-z0-9][a-z0-9-_.]*"
  default "phptest.tgz"
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
    "low" => "c3.large",  # 2 CPUs x 3.75GB
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
  "Australia" => {
    "provider" => "AWS",
    "cloud" => "ap-southeast-2",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Brazil" => {
    "provider" => "AWS",
    "cloud" => "sa-east-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Netherlands" => {
    "provider" => "Azure",
    "cloud" => "Azure West Europe",
    "security_group" => null,
    "ssh_key" => null,
  },
  "Japan" => {
    "provider" => "AWS",
    "cloud" => "ap-northeast-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Singapore" => {
    "provider" => "Azure",
    "cloud" => "Azure Southeast Asia",
    "security_group" => null,
    "ssh_key" => null,
  },
  "USA" => {
    "provider" => "AWS",
    "cloud" => "us-east-1",
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

output 'end2end_test' do
  label "End to End Test" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address, "/dbread"])
  description "Verifies access through LB #1 to App server and App server access to the DB server."
end

output 'haproxy_status' do
  label "Load Balancer Status Page" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address, "/haproxy-status"])
  description "Accesses Load Balancer status page"
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

resource 'lb_1', type: 'server' do
  name 'Load Balancer'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,'instance_type_low')
  server_template find('Load Balancer with HAProxy (v13.5.5-LTS)', revision: 18)
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'lb/session_stickiness' => 'text:false',   
  } end
end

resource 'db_1', type: 'server' do
  name 'Database'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  server_template find("Database Manager for MySQL 5.5 (v13.5.10-LTS)", revision: 32)
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'db/backup/lineage' => join(['text:selfservice-demo-lineage-',@@deployment.href]),
    'db/dns/master/fqdn' => 'env:Database:PRIVATE_IP',
    'db/dns/master/id' => 'cred:DB_THROWAWAY_HOSTNAME_ID',
    'db/dump/container' => 'text:three-tier-scaling',
    'db/dump/database_name' => 'text:app_test',
    'db/dump/prefix' => 'text:app_test',
    'db/dump/storage_account_id' => 'cred:AWS_ACCESS_KEY_ID',
    'db/dump/storage_account_secret' => 'cred:AWS_SECRET_ACCESS_KEY',
    'db/init_slave_at_boot' => 'text:false',
    'db/replication/network_interface' => 'text:private',
    'sys_dns/choice' => 'text:DNSMadeEasy',
    'sys_dns/password' => 'cred:DNS_PASSWORD',
    'sys_dns/user' => 'cred:DNS_USER',
    'sys_firewall/enabled' => 'text:unmanaged',
    } end
end

resource 'server_array_1', type: 'server_array' do
  name 'PHP App Server Array'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  server_template find('PHP App Server (V13.5.5-LTS) scaling')
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'app/database_name' => 'app_test',
    'db/dns/master/fqdn' => 'env:Database:PRIVATE_IP',
    'db/provider_type' => 'text:db_mysql_5.5',
    'repo/default/provider' => 'text:s3',
    'repo/default/repository' => $param_s3_bucket,
    'repo/default/prefix' => 'text:phptest',
    'repo/default/account' => 'cred:AWS_ACCESS_KEY_ID',
    'repo/default/credential' => 'cred:AWS_SECRET_ACCESS_KEY',
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


##############
# Operations #
##############

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

# define launch_concurrent(@lb_1, @lb_2, @db_1, @db_2, @server_array_1, $high_availability) return @lb_1, @lb_2, @db_1, @db_2, @server_array_1 do
define launch_concurrent(@lb_1, @db_1, @server_array_1, $high_availability) return @lb_1, @db_1, @server_array_1 do
    task_label("Launch servers concurrently")

    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    
    @@launch_task_lb1 = @lb_1
#    @@launch_task_lb2 = @lb_2
    @@launch_task_db1 = @db_1
#    @@launch_task_db2 = @db_2
    @@launch_task_array1 = @server_array_1
    $$high_availability = $high_availability

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
#      sub task_name:"Launch LB-2" do
#        if $$high_availability
#          sleep(15)
#          task_label("Launching LB-2")
#          $lb2_retries = 0 
#          sub on_error: handle_provision_error($lb2_retries) do
#            $lb2_retries = $lb2_retries + 1
#            provision(@@launch_task_lb2)
#          end
#        end
#      end
      sub task_name:"Launch DB-1" do
        task_label("Launching DB-1")
        $db1_retries = 0 
        sub on_error: handle_provision_error($db1_retries) do
          $db1_retries = $db1_retries + 1
          provision(@@launch_task_db1)
        end
      end
#      sub task_name:"Launch DB-2" do
#        if $$high_availability
#          sleep(45)
#          task_label("Launching DB-2")
#          $db2_retries = 0 
#          sub on_error: handle_provision_error($db2_retries) do
#            $db2_retries = $db2_retries + 1
#            provision(@@launch_task_db2)
#          end
#        end
#      end

      sub task_name:"Provision Server Array" do
#        task_label("Provision Server Array: Waiting for DB tier")
#        wait_task "Launch DB-1"
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
#    @lb_2 = @@launch_task_lb2
    @db_1 = @@launch_task_db1
#    @db_2 = @@launch_task_db2
    @server_array_1 = @@launch_task_array1
    $high_availability = $$high_availability
end

define handle_provision_error($count) do
  call log("Handling provision error: " + $_error["message"])
  if $count < 5 
    $_error_behavior = 'retry'
  end
end
#
# Enable operation
#

#define enable_application(@db_1, @db_2, $high_availability) do
define enable_application(@db_1, @server_array_1, $high_availability, $map_cloud, $param_cloud) do
  
  $restore_db_script = map( $map_cloud, $param_cloud, 'restore_db_script_href' )
  $create_db_login_script = map( $map_cloud, $param_cloud, 'create_db_login_script_href' )
  $restart_iis_script = map( $map_cloud, $param_cloud, 'restart_iis_script_href' )
  
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

# Leaving this logic in here for future reference
#  if $high_availability
#    sleep(300)
#    call run_recipe(@db_2, "db::do_primary_init_slave")
#  end
end
 
#
# Import DB operation
#

define import_db_dump(@db_1) do
  task_label("Import the DB dump")
  call run_recipe(@db_1, "db::do_dump_import")  
end

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

define log($message) do
  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
end