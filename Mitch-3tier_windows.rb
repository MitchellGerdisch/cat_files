name 'Mitch - 3Tier: Windows IIS with MS SQL Server'
rs_ca_ver 20131202
short_description "Mitch-ified Version of Ryan O'Leary's 3 Tier deployment using the latest v13.5 LTS ServerTemplates."
long_description "
3 Tier deployment using the latest v13.5 LTS ServerTemplates.
 - HAProxy Load Balancer, Microsoft IIS Application Server, Database Manager for Microsoft SQL Server

DNS Provider: DNS Made Easy but not really since this version passes IP address to the services.

Notes:
 - All servers are configured for the Microsoft 'AWS US-West' cloud.
 - Microsoft SQL mirrored setup for failover purposes where volumes are used to establish mirroring between the principal and mirror servers.
 - Database servers use a single volume, although volume stripes are supported.
 - Application servers checkout the application code from an Amazon S3 bucket.
 - HAProxy load balancers demonstrate a single load balancing pool ('default') configuration.
 - The deployment does not have a server array for autoscaling the application tier.
 "
##############
# PARAMETERS #
##############

parameter "param_cloud" do 
  category "Cloud options"
  label "Cloud" 
  type "string" 
  description "Cloud provider" 
  allowed_values "AWS", "Azure"
  default "AWS"
end
parameter "performance" do
  category "Performance profile" 
  label "Application Performance" 
  type "string" 
  description "Determines the instance type of the DB and App Servers" 
  allowed_values "low", "high"
  default "low"
end
parameter "ha" do 
  category "Performance profile" 
  label "High Availability"
  type "string" 
  description "Redundant DB and LB required?" 
  allowed_values "yes", "no"
  default "no"
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
parameter "environment" do
  type "string"
  label "Environment Type"
  category "Environment"
  allowed_values "Dev", "Staging"
  default "Dev"
  description "Specify whether you'd like a Dev or Staging environment. The primary difference is the Dev environment does not stand up a Slave DB or take Master DB backups regularly."
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

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "us-west-1",
    "datacenter" => "us-west-1c",
    "subnet" => "us-west-1c",
    "instance_type_low" => "m1.small",
    "instance_type_high" => "m1.large",
    "security_group" => "MitchG_DB",
    "ssh_key" => "MitchG_sshKey_2",
  },
  "Azure" => {
    "cloud" => "Azure West Europe",
    "datacenter" => null,
    "subnet" => null,
    "instance_type_low" => "small",
    "instance_type_high" => "large",
    "security_group" => null,
    "ssh_key" => null,
  }
}
end

##############
# CONDITIONS #
##############
condition "staging" do
  equals?($environment, "Staging")
end


##############
# OUTPUTS    #
##############
output 'db_ip' do
  label "Database VM IP"
  category "General"
  default_value @db1.public_ip_address
  description "IP of the DB VM"
end

output 'application_url' do
  label "Application URL"
  category "General"
  default_value join(["http://",@lb1.public_ip_address])
  description "URL for the DB test for the application"
end

output 'haproxy_status' do
  label "HAProxy Status"
  category "General"
  default_value join(["http://",@lb1.public_ip_address,"/haproxy-status"])
  description "HAProxy Status page showing connected app servers and their status"
end

##############
# RESOURCES  #
##############
resource 'db1', type: 'server' do
  name 'db1'  
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
    'DB_LINEAGE_NAME' => 'text:mitchgtest',
    'DB_NAME' => 'text:DotNetNuke',
    'DB_NEW_LOGIN_NAME' => 'cred:SQL_APPLICATION_USER',
    'DB_NEW_LOGIN_PASSWORD' => 'cred:SQL_APPLICATION_PASSWORD',
    'DNS_DOMAIN_NAME' => 'text:using.direct.ip.fake',
    'DNS_ID' => 'text:14762727',
    'DNS_PASSWORD' => 'cred:DNS_MADE_EASY_PASSWORD',
    'DNS_SERVICE' => 'text:DNS Made Easy',
    'DNS_USER' => 'cred:DNS_MADE_EASY_USER',
    'LOGS_VOLUME_SIZE' => 'text:1',
    'MASTER_KEY_PASSWORD' => 'cred:MitchG_DBADMIN_PASSWORD',
    'REMOTE_STORAGE_ACCOUNT_ID' => 'cred:AWS_ACCESS_KEY_ID',
    'REMOTE_STORAGE_ACCOUNT_PROVIDER' => 'text:Amazon_S3',
    'REMOTE_STORAGE_ACCOUNT_SECRET' => 'cred:AWS_SECRET_ACCESS_KEY',
    'REMOTE_STORAGE_CONTAINER' => 'text:mitchgbucket',
    'SYS_WINDOWS_TZINFO' => 'text:Pacific Standard Time',
  } end
end

resource 'app1', type: 'server' do
  name 'app1'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'app_instance_type'))
  server_template find("Microsoft IIS App Server (v13.5.0-LTS)", revision: 3)
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'ADMIN_PASSWORD' => 'cred:WINDOWS_ADMIN_PASSWORD',
    'OPT_CONNECTION_STRING_DB_NAME' => 'text:DotNetNuke',
    'OPT_CONNECTION_STRING_DB_SERVER_NAME' => 'text:ryan-master-windows.rightscaleuniversity.com',
    'OPT_CONNECTION_STRING_DB_USER_ID' => 'cred:SQL_APPLICATION_USER',
    'OPT_CONNECTION_STRING_DB_USER_PASSWORD' => 'cred:SQL_APPLICATION_PASSWORD',
    'OPT_CONNECTION_STRING_NAME' => 'text:SiteSqlServer',
    'REMOTE_STORAGE_ACCOUNT_ID' => 'cred:AWS_ACCESS_KEY_ID',
    'REMOTE_STORAGE_ACCOUNT_ID_APP' => 'cred:AWS_ACCESS_KEY_ID',
    'REMOTE_STORAGE_ACCOUNT_PROVIDER' => 'text:Amazon_S3',
    'REMOTE_STORAGE_ACCOUNT_PROVIDER_APP' => 'text:Amazon_S3',
    'REMOTE_STORAGE_ACCOUNT_SECRET' => 'cred:AWS_SECRET_ACCESS_KEY',
    'REMOTE_STORAGE_ACCOUNT_SECRET_APP' => 'cred:AWS_SECRET_ACCESS_KEY',
    'REMOTE_STORAGE_CONTAINER' => 'text:michelle-db',
    'REMOTE_STORAGE_CONTAINER_APP' => 'text:michelle-app',
    'SYS_WINDOWS_TZINFO' => 'text:Pacific Standard Time',
    'ZIP_FILE_NAME' => 'text:DotNetNuke.zip',
  } end
end

#resource 'db2', type: 'server' do
#  name 'db2'
#  like @db1
#end

#resource 'lb1', type: 'server' do
#  name 'lb1'
#  like @app1
#  server_template find("Load Balancer with HAProxy (v13.5.5-LTS)", revision: 18)
#  inputs do {
#
#  } end
#end

operation "provision" do
  description "Provisions the 3-tiers of a 3-tier app"
  definition "launch_3_tier_v13_3"
end

# Launches a 3-tier application stack based on RightScale's 3-tier architecture.
#
#
define launch_3_tier_v13_3(@app1, @db1, @db2, @lb1, $staging) return @app1, @db1, @db2, @lb1 do
    
    task_label("Launch 3-Tier Application")
    
    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    @@launch_task_lb = @lb1
    @@launch_db_master = @db1
    @@launch_db_slave = @db2
    @@launch_app = @app1
    $$staging = $staging

    concurrent do
      
      sub task_name:"Launch LB Tier" do
        task_label("Launching LB tier")
        provision(@@launch_task_lb)
      end
      
      sub task_name:"Launch DB Tier" do
        call launch_db_tier_v13_LTS_windows()
      end

      sub task_name:"Launch App Tier" do
        task_label("Launching App Tier")
        sleep(60) # Give the DB a chance to at least get created, App server needs its Private PRIVATE_IP
        provision(@@launch_app)

        task_label("Waiting for DB tier to complete")
        wait_task "Launch DB Tier"

        task_label("Restarting IIS Application")
        #  IIS Restart application
        call run_script(@@launch_app, "/api/right_scripts/504573003")
      end
    
    end
  
    # Copy the globally-scoped resources back into the SS-scoped resources that we're returning
    @lb1 = @@launch_task_lb
    @db1 = @@launch_db_master
    @db2 = @@launch_db_slave
    @app1 = @@launch_app
        
end


# Starts a master-slave database configuration in RightScale's 3-tier 
# application stack.
#
# Assumes global resources "launch_db_master" and "launch_db_slave" are defined
#
define launch_db_tier_v13_LTS_windows() do
    
  task_label("Launch Master-Slave DB Pair")

  $masterTaskName = "launch_and_configure_master"
  $slaveTaskName = "launch_and_configure_slave"
    
  # Create and launch DB servers in parallel
  concurrent do

    # Launch and configure master
    sub task_name: $masterTaskName do
                        
      task_label("Launching Master DB")

      # Tag the server with our workflow tag
      provision(@@launch_db_master)
              
      # First recipe was failing because it was being run too quickly
      sleep(20)

      task_label("Initializing Master DB")

      # Wait for Master to be operational, then run config scripts sequentially
      # DB SQLS Restore database from local disk / Remote Storage"
      call run_script(@@launch_db_master, "/api/right_scripts/504422003")
      
      # Create the user
      # DB SQLS Create login
      call run_script(@@launch_db_master, "/api/right_scripts/504417003")

      if $$staging 
        # Create a backup
        # DB SQLS Backup Data and Log volumes
        call run_script(@@launch_db_master, "/api/right_scripts/504413003")

      end

    end # launch_and_configure_master

    # Launch and configure slave
    sub task_name: $slaveTaskName do

      # Only launch the slave if we're setting up a staging env
      if $$staging 
        task_label("Launching Slave DB")

        provision(@@launch_db_slave)
              
        task_label("Slave waiting for Master...")

        log_info( "Slave task waiting for master to complete" )
        wait_task $masterTaskName
        log_info( "Slave task continuing after completion of master" )

        task_label("Initializing Slave DB")

        # Init slave
        call run_recipe(@@launch_db_slave, "db::do_primary_init_slave")
      end

    end # launch_and_configure_slave

  end # concurrent begin

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

# Helper definition, runs a recipe on given server, waits until recipe completes or fails
# Raises an error in case of failure
define run_script(@target, $right_script_href) do
  @task = @target.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end