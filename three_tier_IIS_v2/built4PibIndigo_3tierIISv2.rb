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

# Deploys a simplex dev stack for consisting of LB, scalable IIS app server and MS SQL server.
# Works in AWS or Azure.
#
# No DNS needs to be set up - it passes the information around based on real-time IP assignments.
#
# PREREQUISITES:
#   Imported Server Templates:
#     Load Balancer with HAProxy (v13.5.11-LTS), revision: 25
#     Database Manager for Microsoft SQL Server (13.5.1-LTS)
#       You need to replace the Powershell library installation rightscript with a new version that sets things up to use TLS.
#         Import “SYS Install RightScale Powershell library (v13.5.1-LTS)” rev 5 or later
#         Import and clone “Database Manager for Microsoft SQL Server (v13.5.1-LTS)”
#           Replace the existing “SYS Install RightScale Powershell library” script in the Boot Sequence with the later version.
#         Name the new ServerTemplate: "Database Manager for Microsoft SQL Server (13.5.1-LTS) vTLS"
#     Microsoft IIS App Server (v13.5.0-LTS), revision: 3
#   Links to the given script calls down below in the enable operation need to be modified for the given account (I believe)
#   S3 Storage Setup
#     Create a bucket and update the mapping if necessary.
#     Store the database backup and application files:
#       Database backup file on S3 - as per tutorial using the provided DotNetNuke.bak file found here:
#           http://support.rightscale.com/@api/deki/files/6208/DotNetNuke.bak
#       Application file on S3 - as per tutorial using the provided DotNetNuke.zip file found here:
#           http://support.rightscale.com/@api/deki/files/6292/DotNetNuke.zip
#   SSH Key - see mapping for proper names or to change accordingly.
#   Placement Group in Azure - see mapping for proper names or change accordingly.
#   Security Group that is pretty wide open that covers all the VMs - see mapping for name.
#     ports: 80, 1433, 3389 (3389 is optional - only needed for debugging)
#     TODO: Use new security groups resource type to create specific security groups for the tiers.
#   The usual set of credentials as per the tutorial which are likely already available in the account.
#     WINDOWS_ADMIN_PASSWORD - Password used by user, Administrator to login to the windows VMs.
#     SQL_APPLICATION_USER - SQL database user with login privileges to the specified user database.
#     SQL_APPLICATION_PASSWORD - Password for the SQL database user with login privileges to the specified user database.
#     DBADMIN_PASSWORD - The password to encrypt the master key when it's created or decrypt it when opening an existing master key.
#     AWS_ACCESS_KEY 
#     AWS_ACCOUNT_NUMBER 
#     AWS_SECRET_ACCESS_KEY
#   Azure Cloud Configuration
#     You need to access the Azure console and enable a default placement group. Otherwise the SQL server launch will fail during 
#     volume creation.
#
# DEMO NOTES:
#   Scaling:
#     Operation available to scale out and in

name "IIS-SQL Dev Stack v2"
rs_ca_ver 20131202
short_description "![Windows](http://www.cscopestudios.com/images/winhosting.jpg)\n
Builds a scalable HAproxy - IIS - MS_SQL 3-tier website workload."
long_description "Deploys 3-tier website workload.\n
User can select the cloud, performance level, and size of scaling array.\n
Once deployed, user can scale out additional application servers. \n"

##############
# PARAMETERS #
##############

parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS-Australia", "AWS-Brazil", "AWS-Japan", "AWS-USA", "Azure-Netherlands", "Azure-Singapore", "Azure-USA"
#  allowed_values "Azure-USA", "AWS-USA", "AWS-Australia", "AWS-Brazil"
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
    "low" => "m3.medium",  
    "medium" => "m3.medium", 
    "high" => "m3.large", 
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
# _PIB Indigo is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "PIB Indigo",
  },
}
end

# TODO: Build sec groups here.
#       Use improved methods to find scripts instead of the hrefs.

mapping "map_account" do {
  "CSE Sandbox" => {
    "security_group" => "CE_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "consumers-energy",
    "restore_db_script_href" => "524831004",
    "create_db_login_script_href" => "524829004",
    "restart_iis_script_href" => "524965004",
    "lb_image_href" => "/api/multi_cloud_images/389690004"
  },
  "Hybrid Cloud" => {
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "iis-3tier",
    "restore_db_script_href" => "493424003",
    "create_db_login_script_href" => "493420003",
    "restart_iis_script_href" => "527791003",
    "lb_image_href" => "/api/multi_cloud_images/387180003",
    "placement_group" => "ds1ob0y95a19xw4"
  },
  "PIB Alpha" => {  # THIS CAT IN PIB ALPHA NOT WORKING AT THIS TIME
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "pib-alpha-bucket",
    "restore_db_script_href" => "538299003",
    "create_db_login_script_href" => "538294003",
    "restart_iis_script_href" => "538326003",
    "lb_image_href" => "/api/multi_cloud_images/390081003",
    "placement_group" => "pibalphapg0326"
  },
  "PIB Charlie" => {
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "pib-charlie-bucket",
    "restore_db_script_href" => "537973004",
    "create_db_login_script_href" => "537970004",
    "restart_iis_script_href" => "537998004",
    "lb_image_href" => "/api/multi_cloud_images/393678004",
    "placement_group" => "w3td20by9xw4321"
  },
  "PIB Indigo" => {
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "pib-indigo-bucket",
    "restore_db_script_href" => "544753003",
    "create_db_login_script_href" => "544751003",
    "restart_iis_script_href" => "544784003",
    "lb_image_href" => "/api/multi_cloud_images/396812003",
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

condition "inAzure" do
  equals?(map($map_cloud, $param_location,"provider"), "Azure")
end


##############
# OUTPUTS    #
##############

output "end2end_test" do
  label "Web Site" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address])
  description "Verifies access through LB #1 to App server and App server access to the DB server."
end

output "haproxy_status" do
  label "Load Balancer Status Page" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address, "/haproxy-status"])
  description "Accesses Load Balancer status page"
end

##############
# RESOURCES  #
##############

resource "lb_1", type: "server" do
  name "Tier 1 - LB 1"
  cloud map( $map_cloud, $param_location, "cloud" )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
  server_template find("Load Balancer with HAProxy (v13.5.11-LTS)", revision: 25)
  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
#usedefault  placement_group switch($inAzure, map($map_account, map($map_current_account, "current_account_name", "current_account"), "placement_group"), null)
  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
  multi_cloud_image_href switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "lb_image_href"), null)  
  inputs do {
    "lb/session_stickiness" => "text:false",   
  } end
end

resource "db_1", type: "server" do
  name "Tier 3 - DB 1"
  cloud map( $map_cloud, $param_location, "cloud" )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
  server_template find("Database Manager for Microsoft SQL Server (13.5.1-LTS) vTLS")
  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
#usedefault  placement_group switch($inAzure, map($map_account, map($map_current_account, "current_account_name", "current_account"), "placement_group"), null)  
  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
    inputs do {
      "ADMIN_PASSWORD" => "cred:WINDOWS_ADMIN_PASSWORD",
      "BACKUP_FILE_NAME" => "text:DotNetNuke.bak",
      "BACKUP_VOLUME_SIZE" => "text:10",
      "DATA_VOLUME_SIZE" => "text:10",
      "DB_LINEAGE_NAME" => "text:selfservicedblineage",
      "DB_NAME" => "text:DotNetNuke",
      "DB_NEW_LOGIN_NAME" => "cred:SQL_APPLICATION_USER",
      "DB_NEW_LOGIN_PASSWORD" => "cred:SQL_APPLICATION_PASSWORD",
      "OPT_FORCE_CREATE_VOLUMES" => "text:True",  # To make it easy to launch in different clouds, set this to true so it starts with a clean slate. 
      "DNS_SERVICE" => "text:Skip DNS registration",  # We're using IP addresses found within the application. No DNS needed.
      "LOGS_VOLUME_SIZE" => "text:1",
      "MASTER_KEY_PASSWORD" => "cred:DBADMIN_PASSWORD",
      "REMOTE_STORAGE_ACCOUNT_ID" => "cred:AWS_ACCESS_KEY_ID",
      "REMOTE_STORAGE_ACCOUNT_PROVIDER" => "text:Amazon_S3",
      "REMOTE_STORAGE_ACCOUNT_SECRET" => "cred:AWS_SECRET_ACCESS_KEY",
      "REMOTE_STORAGE_CONTAINER" => join(["text:", map( $map_account, map($map_current_account, "current_account_name", "current_account"), "s3_bucket" )]),
      "SYS_WINDOWS_TZINFO" => "text:Pacific Standard Time",
  } end
end


resource "server_array_1", type: "server_array" do
  name "Tier 2 - IIS App Server"
  cloud map( $map_cloud, $param_location, "cloud" )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
  server_template find("Microsoft IIS App Server (v13.5.0-LTS)")
  ssh_key switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "ssh_key"), null)
#usedefault  placement_group switch($inAzure, map($map_account, map($map_current_account, "current_account_name", "current_account"), "placement_group"), null)
  security_groups switch($inAWS, map($map_account, map($map_current_account, "current_account_name", "current_account"), "security_group"), null)
  inputs do {
    "APPLICATION_LISTENER_PORT" => "text:80", # allows the links on the site to work using the default configuraiton.
    "REMOTE_STORAGE_ACCOUNT_ID_APP" => "cred:AWS_ACCESS_KEY_ID",
    "REMOTE_STORAGE_ACCOUNT_PROVIDER_APP" => "text:Amazon_S3",
    "REMOTE_STORAGE_ACCOUNT_SECRET_APP" => "cred:AWS_SECRET_ACCESS_KEY",
    "REMOTE_STORAGE_CONTAINER_APP" => join(["text:", map( $map_account, map($map_current_account, "current_account_name", "current_account"), "s3_bucket" )]),
    "ZIP_FILE_NAME" => "text:DotNetNuke.zip",
    "OPT_CONNECTION_STRING_DB_NAME" => "text:DotNetNuke",
    "OPT_CONNECTION_STRING_DB_SERVER_NAME" => "env:Tier 3 - DB 1:PRIVATE_IP",
    "OPT_CONNECTION_STRING_DB_USER_ID" => "cred:SQL_APPLICATION_USER",
    "OPT_CONNECTION_STRING_DB_USER_PASSWORD" => "cred:SQL_APPLICATION_PASSWORD",
    "OPT_CONNECTION_STRING_NAME" => "text:SiteSqlServer",
    "ADMIN_PASSWORD" => "cred:WINDOWS_ADMIN_PASSWORD",
    "FIREWALL_OPEN_PORTS_TCP" => "text:80",
    "SYS_WINDOWS_TZINFO" => "text:Pacific Standard Time",    
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
  
  output_mappings do {
    $end2end_test => join(["http://", $lb_1_public_ip_address]),
    $haproxy_status => join(["http://", $lb_1_public_ip_address, "/haproxy-status"])
  } end
end 

#operation "start" do
#  condition $inAWS  # Can only do stop/start in AWS
#  description "Used to restart servers after stopping them."
#  definition "start_servers"
#  
#  # Update the links provided in the outputs.
#  output_mappings do {
#    $end2end_test => join(["http://", $lb_1_public_ip_address]),
#    $haproxy_status => join(["http://", $lb_1_public_ip_address, "/haproxy-status"])
#  } end
#  
#end
#
#operation "stop" do
#  condition $inAWS # Can only do stop/start in AWS
#  description "Used to stop servers without terminating them."
#  definition "stop_servers"
#end

operation "scale_out" do
  description "Scales out another application server."
  definition "scale_out_array"
end

operation "scale_in" do
  description "Scales in the server array."
  definition "scale_in_array"
end


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

#
# Enable operation
#

define enable_application(@lb_1, @db_1, @server_array_1, $inAzure, $map_current_account, $map_account) return $lb_1_public_ip_address do
  
  $cur_account = map($map_current_account, "current_account_name", "current_account")
  $restore_db_script = map( $map_account, $cur_account, "restore_db_script_href" )
  $create_db_login_script = map( $map_account, $cur_account, "create_db_login_script_href" )
  $restart_iis_script = map( $map_account, $cur_account, "restart_iis_script_href" )
  
  task_label("Restoring DB from backup file.")
  @task = @db_1.current_instance().run_executable(right_script_href: join(["/api/right_scripts/", $restore_db_script]), inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")

  task_label("Creating App login to the DB.")
  # call run_recipe(@db_1, "DB SQLS Create login (v13.5.0-LTS)")
  # call run_script(@db_1, "/api/right_scripts/524829004")
  call run_script(@db_1,  join(["/api/right_scripts/", $create_db_login_script]))

  task_label("Restarting IIS so it can connect to DB.")
  # call run_recipe(@server_array_1, "IIS Restart application (v13.5.0-LTS)")
  # call multi_run_script(@server_array_1, "/api/right_scripts/524965004")
  call multi_run_script(@server_array_1,  join(["/api/right_scripts/", $restart_iis_script]))
    
  # If deployed in Azure one needs to provide the port mapping that Azure uses.
  if $inAzure
     @bindings = rs.clouds.get(href: @lb_1.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @lb_1.current_instance().href])
     @binding = select(@bindings, {"private_port":80})
     $lb_1_public_ip_address = join([to_s(@lb_1.current_instance().public_ip_addresses[0]),":",@binding.public_port])
  else
     $lb_1_public_ip_address = @lb_1.current_instance().public_ip_addresses[0]
  end
  
end

# See operations above - this operation is only allowed in certain environments
define start_servers(@lb_1, @db_1, @server_array_1, $inAWS, $inAzure, $map_current_account, $map_account) return $lb_1_public_ip_address do
  task_label("Starting the servers in the Application.")
  
  $cur_account = map($map_current_account, "current_account_name", "current_account")
  $restart_iis_script = map( $map_account, $cur_account, "restart_iis_script_href" )
  
  @lb_1.current_instance().start() 
  @server_array_1.current_instances().start()
  @db_1.current_instance().start()
  
  # Wait until LB is up so that we can scrape the IP address for the output mapping.
  sleep_until(@lb_1.state == "operational" || @lb_1.state == "stranded")
  if @lb_1.state == "stranded"
    call log("Terminating Server:"+@lb_1.name+" | "+@lb_1.state+"=@lb_1.state")
    @lb_1.terminate()
    sleep_until(@lb_1.state == "inactive")
    raise "Instance stranded"
  end
  
  # And make sure the DB tier is good to go
  sleep_until(@db_1.state == "operational" || @db_1.state == "stranded")
  if @db_1.state == "stranded"
    call log("Terminating Server:"+@db_1.name+" | "+@db_1.state+"=@lb_1.state")
    @db_1.terminate()
    sleep_until(@db_1.state == "inactive")
    raise "Instance stranded"
  end
    
  # Now wait until the Application tier is good to go.
  sleep_until(@server_array_1.current_instances().state == "operational" || @server_array_1.current_instances().state == "stranded")
  if (@server_array_1.current_instances().state == "operational")
    task_label("Restarting IIS so it can connect to DB.")
    call multi_run_script(@server_array_1,  join(["/api/right_scripts/", $restart_iis_script]))
  else
    raise "Server array instance(s) stranded"
  end
  
  # Now that everything is happy, re-enable the server array
  @server_array_1.update(server_array: { state: "enabled"})
    
  # Return the new LB's IP address
  $lb_1_public_ip_address = @lb_1.current_instance().public_ip_addresses[0]
  
end

define stop_servers(@lb_1, @db_1, @server_array_1, $inAWS) do
  task_label("Stopping the servers in the Application.")
  
  # disable the server array for scaling
  @server_array_1.update(server_array: { state: "disabled"})

  foreach @server in @server_array_1.current_instances() do
    if (@server.state == "operational")
        @server.stop()
#        sleep_until(@server.state == "provisioned")
    end
  end
  
  @lb_1.current_instance().stop() 
  @db_1.current_instance().stop()
  
  # Now wait for things to be stopped. 
  sleep_until(@db_1.state == "provisioned" && @lb_1.state == "provisioned")
end

define scale_out_array(@server_array_1) do
  task_label("Scale out application server.")
  @task = @server_array_1.launch(inputs: {})
end


define scale_in_array(@server_array_1) do
  task_label("Scale in application server array.")
  $found_terminatable_server = false
  
  foreach @server in @server_array_1.current_instances() do
    if (!$found_terminatable_server) && (@server.state == "operational" || @server.state == "stranded")
      rs.audit_entries.create(audit_entry: {auditee_href: @server.href, summary: "Scale In: terminating server, " + @server.href + " which is in state, " + @server.state})
      @server.terminate()
      $found_terminatable_server = true
    end
  end
  
  if (!$found_terminatable_server)
    rs.audit_entries.create(audit_entry: {auditee_href: @server_array_1.href, summary: "Scale In: No terminatable server currently found in the server array"})
  end
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

