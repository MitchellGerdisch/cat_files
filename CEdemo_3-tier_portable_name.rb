#
#The MIT License (MIT)
#
#Copyright (c) 2014 Bruno Ciscato, Ryan O'Leary
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

name 'Linux portable stack'
rs_ca_ver 20131202
short_description '![Lamp Stack](https://selfservice-demo.s3.amazonaws.com/lamp_logo.gif)

Builds a common 3-tier website architecture in the cloud using RightScale\'s ServerTemplates and a Cloud Application Template.'

long_description '![3tier application stack](https://selfservice-demo.s3.amazonaws.com/3tier.png)'


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
  default "high"
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
    #"datacenter" => "us-west-1a",
    #"subnet" => "us-west-1a",
    "instance_type_low" => "m1.small",
    "instance_type_high" => "m1.large",
    "security_group" => "CE_default_SecGrp",
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

condition "high_availability" do
  equals?($ha, "yes")
end


##############
# OUTPUTS    #
##############

output 'lb1_address' do
  label "LB1 IPs" 
  category "Connect"
  default_value join(["Public IP address: http://", @lb_1.public_ip_address, "dbread"])
  description "Service public IPs"
end

output 'lb2_address' do
  condition $high_availability
  label "LB2 IPs" 
  category "Connect"
  default_value join(["Public IP address: http://", @lb_2.public_ip_address, "dbread"])
  description "Service public IPs"
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
end

resource 'lb_2', type: 'server' do
  name 'Tier 1 - LB 2'
  like @lb_1
end

resource 'db_1', type: 'server' do
  name 'Tier 3 - DB 1'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  server_template find('Database Manager for MySQL 5.5 (v13.5.9-LTS)', revision: 30)
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
    inputs do {
    'db/backup/lineage' => join(['text:selfservice-demo-lineage-',@@deployment.href]),
    'db/dns/master/fqdn' => 'env:Tier 3 - DB 1:PRIVATE_IP',
    'db/dns/master/id' => 'cred:DB_TROWAWAY_HOSTNAME_ID',
    'db/dump/container' => 'text:selfservice-demo',
    'db/dump/database_name' => 'text:app_test',
    'db/dump/prefix' => 'text:app_test',
    'db/dump/storage_account_id' => 'cred:AWS_ACCESS_KEY_ID',
    'db/dump/storage_account_secret' => 'cred:AWS_SECRET_ACCESS_KEY',
    'db/init_slave_at_boot' => 'text:false',
    'db/replication/network_interface' => 'text:private',
    'sys_dns/choice' => 'text:DNSMadeEasy',
    'sys_dns/password' => 'cred:DNS_MADE_EASY_PASSWORD',
    'sys_dns/user' => 'cred:DNS_MADE_EASY_USER',
    'sys_firewall/enabled' => 'text:unmanaged',
  } end
end

resource 'db_2', type: 'server' do
  name 'Tier 3 - DB 2'
  like @db_1
end


resource 'server_array_1', type: 'server_array' do
  name 'Tier 2 - PHP App Servers'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  server_template find('PHP App Server (v13.5.5-LTS)', revision: 19)
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'app/backend_ip_type' => 'text:private',
    'app/database_name' => 'text:app_test',
    'app/port' => 'text:8000',
    'db/dns/master/fqdn' => 'env:Tier 3 - DB 1:PRIVATE_IP',
    'db/provider_type' => 'text:db_mysql_5.5',
    'repo/default/destination' => 'text:/home/webapps',
    'repo/default/perform_action' => 'text:pull',
    'repo/default/provider' => 'text:repo_git',
    'repo/default/repository' => 'text:git://github.com/rightscale/examples.git',
    'repo/default/revision' => 'text:unified_php',
    'sys_firewall/enabled' => 'text:unmanaged',

  } end
  state 'enabled'
  array_type 'alert'
  elasticity_params do {
    'bounds' => {
      'min_count'            => $array_min_size,
      'max_count'            => $array_max_size
    },
    'pacing' => {
      'resize_calm_time'     => 12,
      'resize_down_by'       => 1,
      'resize_up_by'         => 1
    },
    'alert_specific_params' => {
      'decision_threshold'   => 51,
      'voters_tag_predicate' => 'Tier 2 - PHP App Server'
    }
  } end
end


##############
# Operations #
##############

operation "launch" do
  description "Launches all the servers concurrently"
  definition "launch_concurrent"
end

operation "enable" do
  description "Initializes the master DB, imports a DB dump and initializes the slave DB"
  definition "enable_application"
end 

operation "Import DB dump" do
  description "Run script to import the DB dump"
  definition "import_db_dump"
end


##############
# Definitions#
##############

#
# Launch operation
#

define launch_concurrent(@lb_1, @lb_2, @db_1, @db_2, @server_array_1, $high_availability) return @lb_1, @lb_2, @db_1, @db_2, @server_array_1 do
    task_label("Launch servers concurrently")

    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    
    @@launch_task_lb1 = @lb_1
    @@launch_task_lb2 = @lb_2
    @@launch_task_db1 = @db_1
    @@launch_task_db2 = @db_2
    @@launch_task_array1 = @server_array_1
    $$high_availability = $high_availability

    
    concurrent do
      sub task_name:"Launch LB-1" do
        task_label("Launching LB-1")
        $lb1_retries = 0 
        sub on_error: handle_provision_error($lb1_retries) do
          $lb1_retries = $lb1_retries + 1
          provision(@@launch_task_lb1)
        end
      end
      sub task_name:"Launch LB-2" do
        if $$high_availability
    	  sleep(15)
          task_label("Launching LB-2")
          $lb2_retries = 0 
          sub on_error: handle_provision_error($lb2_retries) do
            $lb2_retries = $lb2_retries + 1
            provision(@@launch_task_lb2)
          end
        end
      end
      sub task_name:"Launch DB-1" do
    	sleep(30)
        task_label("Launching DB-1")
        $db1_retries = 0 
        sub on_error: handle_provision_error($db1_retries) do
          $db1_retries = $db1_retries + 1
          provision(@@launch_task_db1)
        end
      end
      sub task_name:"Launch DB-2" do
        if $$high_availability
    	sleep(45)
          task_label("Launching DB-2")
          $db2_retries = 0 
          sub on_error: handle_provision_error($db2_retries) do
            $db2_retries = $db2_retries + 1
            provision(@@launch_task_db2)
          end
        end
      end
      sub task_name:"Provision Server Array" do
    	sleep(60)
        task_label("Provisioning PHP-App-Server")
        $app_retries = 0 
        sub on_error: handle_provision_error($app_retries) do
          $app_retries = $app_retries + 1
          provision(@@launch_task_array1)
        end
      end
    end

    # Copy the globally-scoped resources back into the SS-scoped resources that we're returning
    @lb_1 = @@launch_task_lb1
    @lb_2 = @@launch_task_lb2
    @db_1 = @@launch_task_db1
    @db_2 = @@launch_task_db2
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

define enable_application(@db_1, @db_2, $high_availability) do
  call run_recipe(@db_1, "db::do_init_and_become_master")
  call run_recipe(@db_1, "db::do_primary_backup_schedule_disable")
  call run_recipe(@db_1, "db::do_dump_import")  
  call run_recipe(@db_1, "db::do_primary_backup")
  if $high_availability
    sleep(300)
    call run_recipe(@db_2, "db::do_primary_init_slave")
  end
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

define log($message) do
  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
end