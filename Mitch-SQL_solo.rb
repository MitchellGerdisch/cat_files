name 'Mitch - CSE Sandbox - AWS US-West - Solo MS SQL Server'
rs_ca_ver 20131202
short_description "1 Tier MS SQL deployment using the latest v13.5 LTS ServerTemplates."
long_description "
1 Tier MS SQL deployment using the latest v13.5 LTS ServerTemplates.
 - Database Manager for Microsoft SQL Server

DNS Provider: DNS Made Easy - kinda 

Notes:
 - All servers are configured for the Microsoft 'AWS US-West' cloud.
 - Microsoft SQL mirrored setup for failover purposes where volumes are used to establish mirroring between the principal and mirror servers.
 - Database servers use a single volume, although volume stripes are supported.
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


operation "provision" do
  description "Provisions just a single DB server"
  definition "launch_db_solo"
end

# Launch just a single DB server
#
#
define launch_db_solo(@db1, $staging) return @db1 do
    
    task_label("Launch Single DB Server")
    
    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    @@launch_db_master = @db1
    $$staging = $staging

    concurrent do
      
      sub task_name:"Launch DB Tier" do
        call launch_solo_db_tier_v13_LTS_windows()
      end
    
    end
  
    # Copy the globally-scoped resources back into the SS-scoped resources that we're returning
    @db1 = @@launch_db_master
        
end


# Starts a master-slave database configuration in RightScale's 3-tier 
# application stack.
#
# Assumes global resources "launch_db_master" and "launch_db_slave" are defined
#
define launch_solo_db_tier_v13_LTS_windows() do
    
  task_label("Launch Solo DB Server")

  $masterTaskName = "launch_and_configure_solo_db_server"
    
  # Create and launch DB servers in parallel
  concurrent do

    # Launch and configure master
    sub task_name: $masterTaskName do
                        
      task_label("Launching Solo DB")

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