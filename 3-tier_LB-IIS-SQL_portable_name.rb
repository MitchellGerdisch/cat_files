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

# Mitch Hack and Deployment Notes:
#   Focused on getting an IIS-MS SQL SS demo and for learnin' purposes.
#   Nothing fancy in terms of SSL or replication or anything like that.
#   Single DB server
#     Not doing any backups
#   Single HAProxy LB server
#   Scalable App Servers
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
#       Database backup file on S3 - as per tutorial using the provided DotNetNuke.bak file
#       Application file on S3 - as per tutorial using the provided DotNetNuke.zip file
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
short_description 'Builds an HAproxy-IIS-MS_SQL 3-tier website architecture in the cloud using RightScale\'s ServerTemplates and a Cloud Application Template.'


##############
# PARAMETERS #
##############

parameter "param_cloud" do 
  category "Cloud options"
  label "Cloud" 
  type "string" 
  description "Cloud provider" 
  allowed_values "AWS - Hybrid Cloud", "AWS - CSE Sandbox", "Azure"
  default "AWS - Hybrid Cloud"
end
#parameter "param_bucket_name" do 
#  category "S3 info"
#  label "Bucket Name" 
#  type "string" 
#  description "Bucket from which to grab initial data files." 
#  allowed_pattern "[a-z0-9][a-z0-9-.]*"
#  default "consumers-energy"
#end
parameter "param_data_file" do 
  category "S3 info"
  label "DB initial file" 
  type "string" 
  description "Initial file to use for DB" 
  allowed_pattern "[a-z0-9][a-z0-9-_.]*"
  default "DotNetNuke.bak"
end
parameter "performance" do
  category "Performance profile" 
  label "Application Performance" 
  type "string" 
  description "Determines the instance type of the DB and App Servers" 
  allowed_values "low", "high"
  default "high"
end
#parameter "ha" do 
#  category "Performance profile" 
#  label "High Availability"
#  type "string" 
#  description "Redundant DB and LB required?" 
#  allowed_values "yes", "no"
#  default "no"
#end
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

mapping "profiles" do { 
  "low" => {   
    "db_instance_type" => "instance_type_low",   
    "app_instance_type" => "instance_type_low"  }, 
  "high" => {   
    "db_instance_type" => "instance_type_high",   
    "app_instance_type" => "instance_type_high"  } }
end

# Not really happy with this approach of throwing the script hrefs in the cloud map since they are account mappings.
# But for now, will work.
mapping "map_cloud" do {
  "AWS - CSE Sandbox" => {
    "cloud" => "us-west-1",
    "datacenter" => null,
    "subnet" => null,
    "instance_type_low" => "m1.small",
    "instance_type_high" => "m1.large",
    "security_group" => "CE_default_SecGrp",
    "ssh_key" => "MitchG_sshKey_2",
    "s3_bucket" => "consumers-energy",
    "restore_db_script_href" => "524831004",
    "create_db_login_script_href" => "524829004",
    "restart_iis_script_href" => "524965004",
  },
  "AWS - Hybrid Cloud" => {
    "cloud" => "us-west-1",
    "datacenter" => null,
    "subnet" => null,
    "instance_type_low" => "m1.small",
    "instance_type_high" => "m1.large",
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "CE_sshkey_HybridCloud",
    "s3_bucket" => "iis-3tier",
    "restore_db_script_href" => "493424003",
    "create_db_login_script_href" => "493420003",
    "restart_iis_script_href" => "527791003",
  },
  "Azure - Hybrid Cloud" => {
    "cloud" => "Azure East US",
    "datacenter" => null,
    "subnet" => null,
    "instance_type_low" => "small",
    "instance_type_high" => "large",
    "security_group" => null,
    "ssh_key" => null,
    "s3_bucket" => "iis-3tier",
    "restore_db_script_href" => "493424003",
    "create_db_login_script_href" => "493420003",
    "restart_iis_script_href" => "527791003",
  }
}
end

##############
# CONDITIONS #
##############

condition "high_availability" do
#  equals?($ha, "yes")
  equals?(1, 2)

end


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

#resource 'lb_2', type: 'server' do
#  name 'Tier 1 - LB 2'
#  condition $high_availability
#  like @lb_1
#end

resource 'db_1', type: 'server' do
  name 'Tier 3 - DB 1'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  server_template find("Database Manager for Microsoft SQL Server (13.5.1-LTS)", revision: 5)
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
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
      'REMOTE_STORAGE_CONTAINER' => join(['text:', map( $map_cloud, $param_cloud, 's3_bucket' )]),
      'SYS_WINDOWS_TZINFO' => 'text:Pacific Standard Time',
  } end
end

#resource 'db_2', type: 'server' do
#  name 'Tier 3 - DB 2'
#  condition $high_availability
#  like @db_1
#end


resource 'server_array_1', type: 'server_array' do
  name 'Tier 2 - IIS App Servers'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  #server_template find('Microsoft IIS App Server (v13.5.0-LTS)', revision: 3)
  server_template find('Microsoft IIS App Server (v13.5.0-LTS) scaling')
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'REMOTE_STORAGE_ACCOUNT_ID_APP' => 'cred:AWS_ACCESS_KEY_ID',
    'REMOTE_STORAGE_ACCOUNT_PROVIDER_APP' => 'text:Amazon_S3',
    'REMOTE_STORAGE_ACCOUNT_SECRET_APP' => 'cred:AWS_SECRET_ACCESS_KEY',
    'REMOTE_STORAGE_CONTAINER_APP' => join(['text:', map( $map_cloud, $param_cloud, 's3_bucket' )]),
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