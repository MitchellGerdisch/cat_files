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
#     Siege Load Tester, revision: 32
#     Load Balancer with HAProxy (v13.5.5-LTS), revision: 18 
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
Builds a scalable LAMP 3-tier website workload (using v14 server templates) along with a load generator server for testing."
long_description "Deploys 3-tier website workload.\n
User can select cloud, performance level, size of scaling array and whether or not to launch load generator server for testing.\n
Once deployed, user can generate load against the workload to cause scaling. \n
The load will run for 45 minutes unless stopped by the user."

##############
# PARAMETERS #
##############

parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS-US-East", "AWS-US-West"
  default "AWS-US-East"
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

parameter "param_deploy_siege_server" do 
  category "Deployment Options"
  label "Deploy Siege load generator?" 
  type "string" 
  description "Whether or not to deploy a Siege load generator server." 
  allowed_values "yes", "no"
  default "yes"
end

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
# ___ACCOUNT_NAME__ is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "__ACCOUNT_NAME__",
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
    "security_group" => "IIS_3tier_default_SecGrp", # TODO: Use CAT security group resource type to define security groups for each tier in CAT.
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

# Checks if siege load server should be deployed
condition "deploySiege" do
  equals?($param_deploy_siege_server, "yes")
end


##############
# OUTPUTS    #
##############

#output "end2end_test" do
#  label "Web Site" 
#  category "Connect"
#  default_value join(["http://", @lb_1.public_ip_address])
#  description "Verifies access through LB #1 to App server and App server access to the DB server."
#end
#
#output "haproxy_status" do
#  label "Load Balancer Status Page" 
#  category "Connect"
#  default_value join(["http://", @lb_1.public_ip_address, "/haproxy-status"])
#  description "Accesses Load Balancer status page"
#end

##############
# RESOURCES  #
##############

# TESTING DB DEPLOYMENT
#resource "lb_1", type: "server" do
#  name "Tier 1 - LB 1"
#  cloud map( $map_cloud, $param_location, "cloud" )
#  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
#  server_template find("Load Balancer with HAProxy (v13.5.5-LTS)", revision: 18)
##  security_groups map( $map_account, map($map_current_account, "current_account_name", "current_account"), "security_group" )
##  ssh_key map( $map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key" )
#  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
#  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
#  inputs do {
#    "lb/session_stickiness" => "text:false",   
#  } end
#end

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


resource "server_array_1", type: "server_array" do
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
  } end
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => $array_min_size,
      "max_count"            => $array_max_size
    },
    "pacing" => {
      "resize_calm_time"     => 20, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "Tier 2 - IIS App Server"
    }
  } end
end

## Siege server
#resource "load_generator", type: "server" do
#  name "Load Generator"
#  condition $deploySiege
#  cloud map( $map_cloud, $param_location, "cloud" )
#  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
#  server_template find("Siege Load Tester", revision: 32)
#  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
#  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
#  inputs do {
#    "SIEGE_TEST_URL" => "env:Tier 1 - LB 1:PRIVATE_IP",
#    "SIEGE_TEST_CONCURRENT_USERS" => "text:200",
#    "SIEGE_TEST_DURATION" => "text:45",
#    "SIEGE_TEST_MAX_DELAY" => "text:2",
#  } end
#end

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

#operation "start_load" do
#  description "Generates load to cause scaling."
#  condition $deploySiege
#  definition "start_load"
#end
#
#operation "stop_load" do
#  description "Stops load generation."
#  condition $deploySiege
#  definition "stop_load"
#end


##############
# Definitions#
##############

#
# Launch operation
#

#define launch_concurrent(@lb_1, @db_1, @server_array_1, @load_generator) return @lb_1, @db_1, @server_array_1, @load_generator do
define launch_concurrent(@db_1, @server_array_1) return @db_1, @server_array_1 do
    task_label("Launch servers concurrently")

    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    
#    @@launch_task_lb1 = @lb_1
    @@launch_task_db1 = @db_1
    @@launch_task_array1 = @server_array_1
#    @@launch_task_lg = @load_generator

    # Do just the DB and LB concurrently.
    # It may be the case that the DB server needs to be operational before the App server will work properly.
    # There's a known issue in DotNetNuke where it'll throw the under construction page if the DB server we restarted after the app server connected.
    concurrent do
#      sub task_name:"Launch LB-1" do
#        task_label("Launching LB-1")
#        $lb1_retries = 0 
#        sub on_error: handle_provision_error($lb1_retries) do
#          $lb1_retries = $lb1_retries + 1
#          provision(@@launch_task_lb1)
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

      sub task_name:"Provision Server Array" do
        task_label("Provision Server Array: Provisioning the array now.")
        sleep(90) # Give the DB a chance to at least get created, App server needs its Private PRIVATE_IP
        $app_retries = 0 
        sub on_error: handle_provision_error($app_retries) do
          $app_retries = $app_retries + 1
          provision(@@launch_task_array1)
        end
      end
#      
#      sub task_name:"Launch Load Generator" do
#        task_label("Launching Load Generator")
#        $lg_retries = 0 
#        sub on_error: handle_provision_error($lg_retries) do
#          $lg_retries = $lg_retries + 1
#          provision(@@launch_task_lg)
#        end
#      end
      
    end

    # Copy the globally-scoped resources back into the SS-scoped resources that we're returning
#    @lb_1 = @@launch_task_lb1
    @db_1 = @@launch_task_db1
    @server_array_1 = @@launch_task_array1
#    @load_generator = @@launch_task_lg
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
  
  task_label("Enabling monitoring for MySQL.")
  call run_recipe(@db_1, "rs-mysql::collectd")
  
  task_label("Configuring storage volume.")
  call run_recipe(@db_1, "rs-mysql::volume")
  
  task_label("Configuring MySQL server as master.")
  call run_recipe(@db_1, "rs-mysql::master")
  
  task_label("Restoring DB from backup file.")
  call run_recipe(@db_1, "rs-mysql::dump_import")

end

#define start_load(@load_generator, $map_current_account, $map_account) do
#  task_label("Start load generation.")
#  $cur_account = map($map_current_account, "current_account_name", "current_account")
#  $siege_start_load = map( $map_account, $cur_account, "siege_start_load_href" )
#  call run_script(@load_generator,  join(["/api/right_scripts/", $siege_start_load]))
#end
#
#define stop_load(@load_generator, $map_current_account, $map_account) do
#  task_label("Stop load generation.")
#  $cur_account = map($map_current_account, "current_account_name", "current_account")
#  $siege_stop_load = map( $map_account, $cur_account, "siege_stop_load_href" )
#  call run_script(@load_generator,  join(["/api/right_scripts/", $siege_stop_load]))
#end


