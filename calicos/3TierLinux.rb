#
#The MIT License (MIT)
#
#Copyright (c) 2014 Bruno Ciscato, Ryan O'Leary, Jes Brouillette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sub-license, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following is:
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

name '3-Tier LAMP'
rs_ca_ver 20131202
short_description '
![Lamp Stack](https://selfservice-demo.s3.amazonaws.com/lamp_logo.gif)'

long_description '![3tier application stack](https://selfservice-demo.s3.amazonaws.com/3tier.png)'


##################################################
### PARAMETERS                                 ###
##################################################

parameter "param_cloud" do 
  category "Cloud options"
  label "Cloud Provider" 
  type "string" 
  allowed_values "AWS", "Azure"
  default "AWS"
end
parameter "performance" do
  category "Application Performance Setting" 
  label "Performance Level" 
  type "string" 
  allowed_values "low", "high"
  default "low"
end
parameter "array_min_size" do
  category "Application Scaling Settings"
  label "How many application servers to start with?"
  type "number"
  default "1"
end
parameter "array_max_size" do
  category "Application Scaling Settings"
  label "Maximum number of application servers to allow?"
  type "number"
  default "5"
end


##################################################
### MAPPINGS                                   ###
##################################################

mapping "profiles" do { 
  "low" => {   
    "db_instance_type"  => "instance_type_low",   
    "app_instance_type" => "instance_type_low" 
  }, 
  "high" => {   
    "db_instance_type"  => "instance_type_high",   
    "app_instance_type" => "instance_type_high"
  }
}
end

mapping "map_cloud" do {
  "AWS" => {
    "cloud"                 => "EC2 us-east-1",
    "instance_type_low"     => "m1.small",
    "instance_type_high"    => "m1.large",
    "ssh_key"               => "FalconDev1",
    "server_template_name"  => "Database Manager for MySQL 5.5 (v13.5.12-LTS)",
    "server_template_rev"   => "39",
    "db/backup/lineage"     => "text:selfservice-demo-lineage-aws",
	"db/dns/master/id"      => "cred:DEMO_AWS_DB1",
	"db/dns/slave/id"       => "cred:DEMO_AWS_DB2",
	"db/dns/master/fqdn"    => "cred:DEMO_AWS_DB1_FQDN",
  },
  "Azure" => {
    "cloud"                 => "Azure East US",
    "instance_type_low"     => "small",
    "instance_type_high"    => "large",
    "ssh_key"               => null,
    "server_template_name"  => "Database Manager for MySQL 5.5 (v13.5.12-LTS)",
    "server_template_rev"   => "39",
    "db/backup/lineage"     => "text:selfservice-demo-lineage-azure",
	"db/dns/master/id"      => "cred:DEMO_AZURE_DB1",
	"db/dns/slave/id"       => "cred:DEMO_AZURE_DB2",
	"db/dns/master/fqdn"    => "cred:DEMO_AZURE_DB1_FQDN",
  }
}
end

##################################################
### CONDITIONS                                 ###
##################################################
condition "azure" do
  equals?($param_cloud, "Azure")
end

condition "aws" do
  equals?($param_cloud, "AWS")
end

##################################################
### RESOURCES                                  ###
##################################################

resource "sec_group", type: "security_group" do
  name join(["LAMPsecgrp-",@@deployment.href])
  description "LAMP security group."
  cloud map( $map_cloud, $param_cloud, 'cloud' )
end

resource "sec_group_rule_http", type: "security_group_rule" do
  name "LAMP Security Group HTTP Rule"
  description "Allow HTTP access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "80",
    "end_port" => "80"
  } end
end

resource "sec_group_rule_http8000", type: "security_group_rule" do
  name "LAMP Security Group HTTP Port 8000 Rule"
  description "Allow HTTP port 8000 access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "8000",
    "end_port" => "8000"
  } end
end

resource "sec_group_rule_mysql", type: "security_group_rule" do
  name "LAMP Security Group MySQL Rule"
  description "Allow MySQL access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "3306",
    "end_port" => "3306"
  } end
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "LAMP Security Group SSH Rule"
  description "Allow SSH access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end

resource 'lb_1', type: 'server' do
  name 'Application Load Balancer'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets find(resource_uid: map( $map_cloud, $param_cloud, 'subnet'), network_href: '/api/networks/8T3F71KJ9M6MU')
  instance_type map( $map_cloud, $param_cloud,'instance_type_low')
  server_template find('Load Balancer with HAProxy (v13.5.11-LTS)', revision: 25)
  security_groups @sec_group
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
end

resource 'db_1', type: 'server' do
  name 'Database Master'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets find(resource_uid: map( $map_cloud, $param_cloud, 'subnet'), network_href: '/api/networks/8T3F71KJ9M6MU')
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  server_template find( map( $map_cloud, $param_cloud, 'server_template_name'), revision: map($map_cloud, $param_cloud, 'server_template_rev') )
  security_groups @sec_group
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'db/backup/lineage'                => 'text:selfservice-demo-lineage',
    'db/dump/container'                => 'text:kronos-demo-lamp',
    'db/dump/database_name'            => 'text:app_test',
    'db/dump/prefix'                   => 'text:app_test',
    'db/dump/storage_account_id'       => 'cred:AWS_ACCESS_KEY_ID',
    'db/dump/storage_account_secret'   => 'cred:AWS_SECRET_ACCESS_KEY',
    'db/init_slave_at_boot'            => 'text:false',
    'db/replication/network_interface' => 'text:private',
    'sys_dns/choice'                   => 'text:DNSMadeEasy',
    'sys_dns/password'                 => 'cred:DEMO_RS_DNS_PASSWORD',
    'sys_dns/user'                     => 'cred:DEMO_RS_DNS_USER',
    'sys_firewall/enabled'             => 'text:unmanaged',
    'db/backup/lineage'                => map( $map_cloud, $param_cloud, 'db/backup/lineage' ),
    'db/dns/master/id'                 => map( $map_cloud, $param_cloud, 'db/dns/master/id' ),
    'db/dns/master/fqdn'               => 'env:Database Master:PRIVATE_IP',
    'db/dns/slave/id'                  => map( $map_cloud, $param_cloud, 'db/dns/slave/id' ),
  } end
end

resource 'db_2', type: 'server' do
  name 'Database Slave'
  like @db_1
end


resource 'server_array_1', type: 'server_array' do
  name 'PHP Application Servers'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets find(resource_uid: map( $map_cloud, $param_cloud, 'subnet'), network_href: '/api/networks/8T3F71KJ9M6MU')
  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
  server_template find('PHP App Server (v13.5.11-LTS)', revision: 26)
  security_groups @sec_group
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
  inputs do {
    'app/backend_ip_type'         => 'text:private',
    'app/database_name'           => 'text:app_test',
    'app/port'                    => 'text:8000',
    'db/dns/master/fqdn'          => 'env:Database Master:PRIVATE_IP',
    'db/provider_type'            => 'text:db_mysql_5.5',
    'repo/default/destination'    => 'text:/home/webapps',
    'repo/default/perform_action' => 'text:pull',
    'repo/default/provider'       => 'text:repo_git',
    'repo/default/repository'     => 'text:git://github.com/rightscale/examples.git',
    'repo/default/revision'       => 'text:unified_php',
    'sys_firewall/enabled'        => 'text:unmanaged',

  } end
  state 'enabled'
  array_type 'alert'
  elasticity_params do {
    'bounds' => {
      'min_count' => $array_min_size,
      'max_count' => $array_max_size
    },
    'pacing' => {
      'resize_calm_time' => 12,
      'resize_down_by'   => 1,
      'resize_up_by'     => 1
    },
    'alert_specific_params' => {
      'decision_threshold'   => 51,
      'voters_tag_predicate' => 'PHP Application Servers'
    }
  } end
end


##################################################
### Operations                                 ###
##################################################

operation "launch" do
  description "Launches all the servers concurrently"
  definition "launch_concurrent"
end

operation "enable" do
  description "Initializes the master DB, imports a DB dump and initializes the slave DB"
  definition "enable_application"
  output_mappings do {
    $lb1_address => join(["Public URL:  http://",$public_ip,"/dbread"])
  } end
end 

operation "Import DB dump" do
  description "Run script to import the DB dump"
  definition "import_db_dump"
end

operation "Update Application Code" do
  description "Run script to import the DB dump"
  definition "update_app_code"
end

operation "Scale Out" do
  description "Scale the application array up"
  definition "initiate_scale_up"
end

##################################################
### Definitions                                ###
##################################################

##################################################
#   => Launch operation
##################################################

define launch_concurrent(@lb_1, @db_1, @db_2, @server_array_1, @sec_group, @sec_group_rule_http, @sec_group_rule_http8000, @sec_group_rule_mysql, @sec_group_rule_ssh, $azure, $aws, $map_cloud, $param_cloud) return @lb_1, @db_1, @db_2, @server_array_1, @sec_group, @sec_group_rule_http, @sec_group_rule_http8000, @sec_group_rule_mysql, @sec_group_rule_ssh do
    task_label("Launch servers concurrently")
    
    # If in AWS, then need to provision the Sec Group rules before provisioning the servers
    if $aws
      provision(@sec_group_rule_http)
      provision(@sec_group_rule_http8000)
      provision(@sec_group_rule_mysql)
      provision(@sec_group_rule_ssh)
    end

    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #  to that task. Since we want to modify these particular resources, we copy them
    #  into global scope and copy them back at the end
    
    @@launch_task_lb1 = @lb_1
    @@launch_task_db1 = @db_1
    @@launch_task_db2 = @db_2
    @@launch_task_array1 = @server_array_1

	concurrent do
      sub task_name:"Launch Application Load Balancer" do
        task_label("Launching LB")
        $lb1_retries = 0 
        sub on_error: handle_provision_error($lb1_retries) do
          $lb1_retries = $lb1_retries + 1
          provision(@@launch_task_lb1)
        end
      end
      sub task_name:"Launch DB Master" do
    	sleep(5)
        task_label("Launching DB Master")
        $db1_retries = 0 
        sub on_error: handle_provision_error($db1_retries) do
          $db1_retries = $db1_retries + 1
          provision(@@launch_task_db1)
        end
      end
      sub task_name:"Launch DB Slave" do
    	sleep(10)
        task_label("Launching DB Slave")
        $db2_retries = 0 
        sub on_error: handle_provision_error($db2_retries) do
          $db2_retries = $db2_retries + 1
          provision(@@launch_task_db2)
        end
      end
      sub task_name:"Provision Server Array" do
    	sleep(15)
        task_label("Provisioning PHP Application Servers")
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
    @db_2 = @@launch_task_db2
    @server_array_1 = @@launch_task_array1
end

define handle_provision_error($count) do
  call log("Handling provision error: " + $_error["message"])
  if $count < 5 
    $_error_behavior = 'retry'
  end
end

##################################################
#   => Enable operation
##################################################

define enable_application(@lb_1, @db_1, @db_2, $azure) return $public_ip, @lb_1, @binding do
  call log("Azure:: " + to_s($azure))
  if $azure
    @bindings = rs.clouds.get(href: @lb_1.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @lb_1.current_instance().href])
	@binding = select(@bindings, {"private_port":80})
    $public_ip = join([to_s(@lb_1.current_instance().public_ip_addresses[0]),":",@binding.public_port])
  else
    $public_ip = @lb_1.current_instance().public_ip_addresses[0]
  end
  call log("Public IP:: " + to_s($public_ip))
  if logic_and($public_ip, null)
    $public_ip = "no_ip_found"
  end

  call run_recipe(@db_1, "db::do_init_and_become_master")
  if !$azure
    call run_recipe(@db_1, "db::do_primary_backup_schedule_disable")
  end
  call run_recipe(@db_1, "db::do_dump_import")  
  if !$azure
    call run_recipe(@db_1, "db::do_primary_backup")
    sleep(180)
    call run_recipe(@db_2, "db::do_primary_init_slave")
  end
end
 
##################################################
#   => Action for "Import DB Dump"
##################################################

define import_db_dump(@db_1) do
  task_label("Import the DB dump")
  call run_recipe(@db_1, "db::do_dump_import")  
end

##################################################
#   => Action for "Update Application Code"
##################################################

define update_app_code(@server_array_1) do
  task_label("Update Application Code")
  call run_recipe_array(@server_array_1, "app::do_update_code")
end

##################################################
#   => Action for "Update Application Code"
##################################################

define initiate_scale_up(@server_array_1) do
  task_label("Scale Array Up")
  call scale_up_array(@server_array_1)
end

##################################################
#   => Run a given script/recipe on a single instance
##################################################

define run_recipe(@target, $recipe_name) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

##################################################
#   => Run a given script/recipe on all instances within an array
##################################################

define run_recipe_array(@target, $recipe_name) do
  @task = @target.multi_run_executable(recipe_name: $recipe_name, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

##################################################
#   => Add a single instance into a given array
##################################################

define scale_up_array(@target) do
  @task = @target.launch(inputs: {})
end

define log($message) do
  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
end

##################################################
### OUTPUTS                                    ###
##################################################

output "lb1_address" do
  category "Connect"
  label "Application URL" 
  description "Service public IPs"
end

output "output_param_cloud" do 
  category "Cloud options"
  label "Cloud Provider" 
  description "Cloud provider" 
  default_value $param_cloud
end

output "output_performance" do
  category "Performance level" 
  label "Application Performance" 
  description "Determines the instance type of the DB and App Servers." 
  default_value $performance
end

output "output_array_min_size" do
  category "Application Scaling Parameters"
  label "How many application servers to start with?"
  description "Minimum number of servers in the application tier."
  default_value $array_min_size
end

output "output_array_max_size" do
  category "Application Scaling Parameters"
  label "Maximum number of application servers to allow?"
  description "Maximum number of servers in the application tier."
  default_value $array_max_size
end