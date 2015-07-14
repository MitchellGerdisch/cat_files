#
# Multi-tier stack that can be launched in the CIBC SoftLayer and VMware environment
# 
# NOTES:
#   This CAT uses minimally modified off-the-shelf ServerTemplates.
#   The VMware environment's firewall rules prohibit access to some of the data sources used by these ServerTemplates.
#   Where feasible this was addressed by modifying the ServerTemplate to use RightScripts with attachments
#   However, the Load Balancer ServerTemplate was not able to be modified in this way thus far and so in the VMware environment,
#   there is no load balancer or scaling supported.
#   

name 'LAMP Stack - Scalable'
rs_ca_ver 20131202
short_description "![logo](http://nextstone.ca/nextstone.ca/nextstone/images/stories/lamp_logo.png)

Launches a multi-tier LAMP stack."
long_description "Launches a multi-tier LAMP stack."
##################
# User inputs    #
##################
parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  allowed_values "SoftLayer" # Can't get a LB to launch in VMware: , "VMware" 
  default "SoftLayer"
end

parameter "server_performance" do
  type "string"
  label "Server Performance Level"
  category "Resource pool"
  allowed_values "High", "Medium", "Low"
  default "Medium"
  #description "Server Performance Level"
end

parameter "transit_id" do
  type "string"
  label "Transit ID"
  category "Business"
  default "70762"
  allowed_values "70762", "76236", "76234", "78115"
  #description "Cost Center"
end

parameter "map_id" do
  type "string"
  label "MAP ID"
  category "Business"
  default "WL-5-b"
  description "LAMP workload project"
end


################################
# Outputs returned to the user #
################################
output "site_url" do
  label "LAMP Stack Test"
  category "Output"
  description "Click to test the stack."
end

output "lb_status_url" do
  condition $notInvSphere
  label "Load Balancer Status Page" 
  category "Output"
  description "Accesses Load Balancer status page"
end

output "lb_status_url" do
  condition $notInvSphere
  label "Load Balancer Status Page" 
  category "Output"
  description "Accesses Load Balancer status page"
end

output "vmware_note" do
  condition $invSphere
  label "Deployment Note"
  category "Output"
  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible."
end

##############
# MAPPINGS   #
##############

# Mapping and abstraction of cloud-related items.
mapping "map_cloud" do {
  "SoftLayer" => {
    "cloud_provider" => "SoftLayer", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "SoftLayer",
    "zone" => "Toronto 1", # We don't care which az AWS decides to use.
    "sg" => null, 
    "mci_name" => "RightImage_RHEL_6.6._v14.0_SoftLayer",
    "mci_rev" => "1",
    "ssh_key_href" => '/api/clouds/1869/ssh_keys/65DV7UQAFV7RB',
  },
  "VMware" => {
    "cloud_provider" => "vSphere", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "CIBC_POC",
    "zone" => "RightScale POC", # launches in vSphere require a zone being specified  
    "sg" => null, 
    "mci_name" => "RightImage_CentOS_6.6_x64_v14.2_VMware",
    "mci_rev" => "9",
    "ssh_key_href" => '/api/clouds/3145/ssh_keys/AIFVF99O097O1'
  }
}
end

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do {
  "lb" => {
    "name" => "Load Balancer with HAProxy (v14.1.1) CIBC POC",
    "rev" => "1",
  },
  "app" => {
    "name" => "PHP App Server (v14.1.1) CIBC GTY",
    "rev" => "5",
  },
  "db" => {
    "name" => "Database Manager for MySQL (v14.1.1) CIBC GTY",
    "rev" => "2",
  }
} end

# Mapping of names of the creds to use for the DB-related credential items.
# Allows for easier maintenance down the road if needed.
mapping "map_db_creds" do {
  "root_password" => {
    "name" => "CAT_MYSQL_ROOT_PASSWORD",
  },
  "app_username" => {
    "name" => "CAT_MYSQL_APP_USERNAME",
  },
  "app_password" => {
    "name" => "CAT_MYSQL_APP_PASSWORD",
  }
} end

mapping "instance_type_mapping" do {
    "High" => {
      "SoftLayer"=>"gLarge",
      "vSphere"=>"large"
    },
    "Medium" => {
      "SoftLayer"=>"gMedium",
      "vSphere"=>"large"
    },
    "Low" => {
      "SoftLayer"=>"gSmall",
      "vSphere"=>"small"
    },
  }
end

##################
# CONDITIONS     #
##################

condition "needsSecurityGroup" do
  logic_or(equals?(map($map_cloud, $param_location, "cloud_provider"), "AWS"), equals?(map($map_cloud, $param_location, "cloud_provider"), "Google"))
end

condition "needsPlacementGroup" do
  equals?(map($map_cloud, $param_location, "cloud_provider"), "Azure")
end

condition "invSphere" do
  equals?(map($map_cloud, $param_location, "cloud_provider"), "vSphere")
end

condition "notInvSphere" do
  equals?("true","true") # temporarily overriding for some testing
#  logic_not($invSphere)
end

condition "inAzure" do
  equals?(map($map_cloud, $param_location, "cloud_provider"), "Azure")
end


############################
# RESOURCE DEFINITIONS     #
############################

### Security Group Declarations ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.

## TO-DO: Set up separate security groups for each tier with rules that allow the applicable port(s) only from the IP of the given tier server(s)
resource "sec_group", type: "security_group" do
  name join(["sec_group-",@@deployment.href])
  description "CAT security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_http", type: "security_group_rule" do
  name "CAT HTTP Rule"
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

resource "sec_group_rule_http8080", type: "security_group_rule" do
  name "CAT HTTP Rule"
  description "Allow HTTP port 8080 access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "8080",
    "end_port" => "8080"
  } end
end

resource "sec_group_rule_mysql", type: "security_group_rule" do
  name "CAT MySQL Rule"
  description "Allow MySQL access over standard port."
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

### Server Declarations ###
resource 'lb_server', type: 'server' do
  name 'Load Balancer'
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($instance_type_mapping, $server_performance, map($map_cloud, $param_location, "cloud_provider"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key_href")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  server_template find(map($map_st, "lb", "name"), revision: map($map_st, "lb", "rev"))
  multi_cloud_image find(map($map_cloud, $param_location, "mci_name"), revision: map($map_cloud, $param_location, "mci_rev"))
  inputs do {
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
    'rs-haproxy/balance_algorithm' => 'text:roundrobin',
    'rs-haproxy/health_check_uri' => 'text:/',
    'rs-haproxy/incoming_port' => 'text:80',
    'rs-haproxy/pools' => 'array:["text:default"]',
    'rs-haproxy/schedule/enable' => 'text:true',
    'rs-haproxy/schedule/interval' => 'text:15',
    'rs-haproxy/session_stickiness' => 'text:false',
    'rs-haproxy/stats_uri' => 'text:/haproxy-status',
    "rightscale/security_updates" => "text:enable", # Enable security updates
  } end
end

resource 'db_server', type: 'server' do
  name 'Database Server'
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($instance_type_mapping, $server_performance, map($map_cloud, $param_location, "cloud_provider"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key_href")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  server_template find(map($map_st, "db", "name"), revision: map($map_st, "db", "rev"))
  multi_cloud_image find(map($map_cloud, $param_location, "mci_name"), revision: map($map_cloud, $param_location, "mci_rev"))
  inputs do {
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
    'rs-mysql/application_user_privileges' => 'array:["text:select","text:update","text:insert"]',
    'rs-mysql/backup/keep/dailies' => 'text:14',
    'rs-mysql/backup/keep/keep_last' => 'text:60',
    'rs-mysql/backup/keep/monthlies' => 'text:12',
    'rs-mysql/backup/keep/weeklies' => 'text:6',
    'rs-mysql/backup/keep/yearlies' => 'text:2',
    'rs-mysql/bind_network_interface' => 'text:private',
    'rs-mysql/device/count' => 'text:2',
    'rs-mysql/device/destroy_on_decommission' => 'text:false',
    'rs-mysql/device/detach_timeout' => 'text:300',
    'rs-mysql/device/mount_point' => 'text:/mnt/storage',
    'rs-mysql/device/nickname' => 'text:data_storage',
    'rs-mysql/device/volume_size' => 'text:10',
    'rs-mysql/schedule/enable' => 'text:false',
    'rs-mysql/server_usage' => 'text:dedicated',
    'rs-mysql/backup/lineage' => 'text:demolineage',
    'rs-mysql/server_root_password' => "cred:CAT_MYSQL_ROOT_PASSWORD",
    'rs-mysql/application_password' => "cred:CAT_MYSQL_APP_PASSWORD",
    'rs-mysql/application_username' => "cred:CAT_MYSQL_APP_USERNAME",
    'rs-mysql/application_database_name' => 'text:app_test',
    'rs-mysql/import/dump_file' => 'text:app_test.sql',
    'rs-mysql/import/repository' => 'text:git://github.com/rightscale/examples.git',
    'rs-mysql/import/revision' => 'text:unified_php',
    "MYSQLROOTPASSWORD" => "cred:CAT_MYSQL_ROOT_PASSWORD",
  } end
end

resource 'app_server', type: 'server_array' do
  name 'App Server'
  cloud map( $map_cloud, $param_location, "cloud" )
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($instance_type_mapping, $server_performance, map($map_cloud, $param_location, "cloud_provider"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key_href")
  security_group_hrefs map($map_cloud, $param_location, "sg") 
  server_template find(map($map_st, "app", "name"), revision: map($map_st, "app", "rev"))
  multi_cloud_image find(map($map_cloud, $param_location, "mci_name"), revision: map($map_cloud, $param_location, "mci_rev"))
  inputs do {
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-application_php/app_root' => 'text:/',
    'rs-application_php/application_name' => 'text:default',
    'rs-application_php/bind_network_interface' => 'text:private',
    'rs-application_php/database/host' => 'env:Database Server:PRIVATE_IP',
    'rs-application_php/database/password' => 'cred:CAT_MYSQL_APP_PASSWORD',
    'rs-application_php/database/schema' => 'text:app_test',
    'rs-application_php/database/user' => 'cred:CAT_MYSQL_APP_USERNAME',
    'rs-application_php/listen_port' => 'text:80',
    'rs-application_php/scm/repository' => 'text:git://github.com/rightscale/examples.git',
    'rs-application_php/scm/revision' => 'text:unified_php',
    'rs-application_php/vhost_path' => 'text:/',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
    "DBAPPLICATION_USER" => "cred:CAT_MYSQL_APP_USERNAME",
    "DBAPPLICATION_PASSWORD" => "cred:CAT_MYSQL_APP_PASSWORD",
    "DB_SCHEMA_NAME" => "text:app_test",
    "MASTER_DB_DNSNAME" => "env:Database Server:PRIVATE_IP",
    "APPLICATION" => "text:",
  } end
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => 1,
      "max_count"            => 4
    },
    "pacing" => {
      "resize_calm_time"     => 5, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "APP_LAMP_GTY"
    }
  } end
end

####################
# OPERATIONS       #
####################
operation 'launch' do 
  description 'Launch the application' 
  definition 'generated_launch' 
  output_mappings do {
    $site_url => $site_link,
    $lb_status_url => $lb_status,
  } end
end 

operation "terminate" do
  description "Terminate the servers and clean up"
  definition "terminate_server"
end

operation "Scale Out" do
  description "Adds (scales out) an app server."
  condition $notInvSphere
  definition "scale_out_array"
end

operation "Scale In" do
  description "Scales in an app server."
  condition $notInvSphere
  definition "scale_in_array"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
<<<<<<< HEAD
define generated_launch(@lb_server, @app_server, @db_server, @sec_group, @sec_group_rule_http, @sec_group_rule_http8080, @sec_group_rule_mysql, $map_cloud, $map_st, $map_db_creds, $param_location, $transit_id, $map_id, $needsPlacementGroup, $needsSecurityGroup, $invSphere) return @lb_server, @app_server, @db_server, $site_link, $lb_status do 
=======
define generated_launch(@lb_server, @app_server, @db_server, @sec_group, @sec_group_rule_http, @sec_group_rule_http8080, @sec_group_rule_mysql, $map_cloud, $map_st, $map_db_creds, $param_location, $line_of_business, $cost_center, $project_code, $needsPlacementGroup, $needsSecurityGroup, $invSphere, $notInvSphere)  return @lb_server, @app_server, @db_server, $site_link, $lb_status do 
>>>>>>> refs/heads/scalable_gty_lampstack
  
  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call checkCloudSupport($cloud_name, $param_location)
  
  # Create a placement group if needed and update the server declaration to use it
  call createPlacementGroup($needsPlacementGroup, $cloud_name) retrieve $pg_name
  if logic_not($invSphere)
    call managePlacementGroup($needsPlacementGroup, $cloud_name, @lb_server, $pg_name) retrieve @lb_server
  end
  call managePlacementGroup($needsPlacementGroup, $cloud_name, @app_server, $pg_name) retrieve @app_server
  call managePlacementGroup($needsPlacementGroup, $cloud_name, @db_server, $pg_name) retrieve @db_server
  
  # Create the MySQL credentials if needed
  $mysql_creds = ["CAT_MYSQL_ROOT_PASSWORD","CAT_MYSQL_APP_PASSWORD","CAT_MYSQL_APP_USERNAME"]
  foreach $cred_name in $mysql_creds do
    @cred = rs.credentials.get(filter: join(["name==",$cred_name]))
    if empty?(@cred) 
      $cred_value = join(split(uuid(), "-"))[0..14] # max of 16 characters for mysql username and we're adding a letter next.
      $cred_value = "a" + $cred_value # add an alpha to the beginning of the value - just in case.
      @task=rs.credentials.create({"name":$cred_name, "value": $cred_value})
    end
  end
  
  # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
  if $needsSecurityGroup
    provision(@sec_group_rule_http)
    provision(@sec_group_rule_http8080)
    provision(@sec_group_rule_mysql)
  end
  
  # Before launching the servers, we need to set the subnet if in vSphere environment.
  # SoftLayer environment sets default subnets that work fine.
  # Softlayer has two subnets, but vsphere only has one.  
  # vsphere is set in the source from the map.
  if $invSphere
    $subnet_hrefs = ["/api/clouds/3145/subnets/594LFJRGPJ5E9"]
    # Currently not supporting LB in vSphere: call manageSubnets(@lb_server, $subnet_hrefs) retrieve @lb_server
    call manageSubnets(@app_server, $subnet_hrefs) retrieve @app_server
    call manageSubnets(@db_server, $subnet_hrefs) retrieve @db_server
  end
 
  # Launch the servers concurrently
  concurrent return  @lb_server, @app_server, @db_server do 
    if $notInvSphere 
      provision(@lb_server)
    end
    provision(@app_server)
    provision(@db_server)
  end 
  
  #Add business-related tags to the servers
  $tags=[join(["cibc:transit_id=",$transit_id]),
    join(["cibc:map_id=",$map_id])]
  rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
  rs.tags.multi_add(resource_hrefs: @@deployment.server_arrays().current_instances().href[], tags: $tags)

  
  # Run some post-launch scripts to get things working together
  # Call RightScript that imports attached database file
  call run_script(@db_server,  "/api/right_scripts/543136003")
    
  # Set up the tags for the load balancer and app servers to find each other - if applicable
  # Current no LB is launched when using the VMware environment.
  if $notInvSphere
    call multi_run_recipe_inputs(@app_server, "rs-application_php::tags", {}) 
    call run_recipe_inputs(@lb_server, "rs-haproxy::tags", {})
    # Now tell the LB to find the app server
    sleep(15) # wait to give the server array instances  a chance to get tagged.
    call run_recipe_inputs(@lb_server, "rs-haproxy::frontend", {})
  end
    
  # Depending on the environment, the link provided back to the user needs to be tweaked
  if  $invSphere
    # Use private IP address (of app_server) in VMware
    $ip_address = @app_server.current_instance().private_ip_addresses[0]
  else
    $ip_address = @lb_server.current_instance().public_ip_addresses[0]
  end
  $site_link = join(["http://", to_s($ip_address)])
<<<<<<< HEAD
  $lb_status = join(["http://", to_s($ip_address), "/haproxy-status"]) 
=======
  $lb_status = join(["http://", to_s($ip_address), "/haproxy-status"])
    
>>>>>>> refs/heads/scalable_gty_lampstack
end 

# Terminate the servers
define terminate_server(@lb_server, @app_server, @db_server, @sec_group, $map_cloud, $param_location, $needsSecurityGroup, $needsPlacementGroup, $invSphere, $notInvSphere) do
    
    $cloud_name = map( $map_cloud, $param_location, "cloud" )

    # find the placement group before deleting the server and then delete the PG once the server is gone
    if $needsPlacementGroup 
      sub on_error: skip do  # if might throw an error if we are stopped and there's nothing existing at this point.
        @pg_res = @db_server.current_instance().placement_group()
        $$pg_name = @pg_res.name
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Placement group associated with the server: ", $$pg_name])})
      end
    end
    
    # Terminate the servers
    concurrent do 
      if $notInvSphere
        delete(@lb_server)
      end
      delete(@app_server)
      delete(@db_server)
    end

    if $needsSecurityGroup
      rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Deleting security group, ", @sec_group])})
      @sec_group.destroy()
    end
    
    if $needsPlacementGroup
       rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Placement group name to delete: ", $$pg_name])})
       
       $cloud_href = rs.clouds.get(filter: [join(["name==",$cloud_name])]).href
         
       @pgs=rs.placement_groups.get(filter:[join(["cloud_href==",$cloud_href]), join(["name==",$$pg_name])])
         
       foreach @pg in @pgs do
         if @pg.name == $$pg_name
           rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Found placement group and deleting: ", @pg.name])})
           $attempts = 0
           sub on_error: handle_retries($attempts) do
             $attempts = $attempts + 1
             @pg.destroy()
           end
         end
       end
    end
end

# Scale out (add) server
define scale_out_array(@app_server, @lb_server, $transit_id, $map_id) do
  task_label("Scale out application server.")
  @task = @app_server.launch(inputs: {})
  sleep(60)
  # Wait until the new server is up and running. 
  foreach @server in @app_server.current_instances() do
    if ((@server.state == "pending") || (@server.state == "booting") || (@server.state == "queued"))
      sleep_until(@server.state == "operational")
    end
  end
  
<<<<<<< HEAD
  # Tag the app server(s) with the business tags
  $tags=[join(["cibc:transit_id=",$transit_id]),
      join(["cibc:map_id=",$map_id])]
=======
end

# Scale out (add) server
define scale_out_array(@app_server, @lb_server, $line_of_business, $cost_center, $project_code) do
  task_label("Scale out application server.")
  @task = @app_server.launch(inputs: {})
  sleep(60)
  # Wait until the new server is up and running. 
  foreach @server in @app_server.current_instances() do
    if ((@server.state == "pending") || (@server.state == "booting") || (@server.state == "queued"))
      sleep_until(@server.state == "operational")
    end
  end
  
  # Tag the app server(s) with the business tags
  $tags=[join(["cibc:line_of_business=",$$lob]),
    join(["cibc:cost_center=",$$cc]),
    join(["cibc:project_code=",$$pc])]
>>>>>>> refs/heads/scalable_gty_lampstack
  rs.tags.multi_add(resource_hrefs: @app_server.current_instances().href[], tags: $tags)
    
  # Tag the servers for Load Balancing
  call multi_run_recipe_inputs(@app_server, "rs-application_php::tags", {}) 
  # Now tell the LB to find the app server
  call run_recipe_inputs(@lb_server, "rs-haproxy::frontend", {})
end

# Scale in (remove) server
define scale_in_array(@app_server) do
  task_label("Scale in application server.")
  $found_terminatable_server = false
  
  foreach @server in @app_server.current_instances() do
    if (!$found_terminatable_server) && (@server.state == "operational" || @server.state == "stranded")
      rs.audit_entries.create(audit_entry: {auditee_href: @server.href, summary: "Scale In: terminating server, " + @server.href + " which is in state, " + @server.state})
      
      # Detach the instance from the load balancer
      call run_recipe_inputs(@server, "rs-application_php::application_backend_detached", {})
      
      # destroy the instance
      @server.terminate()
      sleep_until(@server.state != "operational")
      $found_terminatable_server = true
    end
  end
  
  if (!$found_terminatable_server)
    rs.audit_entries.create(audit_entry: {auditee_href: @app_server.href, summary: "Scale In: No terminatable server currently found in the server array"})
  end
end

####################
# Helper Functions #
####################
# Checks if the account supports the selected cloud
define checkCloudSupport($cloud_name, $param_location) do
  # Gather up the list of clouds supported in this account.
  @clouds = rs.clouds.get()
  $supportedClouds = @clouds.name[] # an array of the names of the supported clouds
  
  # Check if the selected/mapped cloud is in the list and yell if not
  if logic_not(contains?($supportedClouds, [$cloud_name]))
    raise "Your trial account does not support the "+$param_location+" cloud. Contact RightScale for more information on how to enable access to that cloud."
  end
end

# Modifies subnet hrefs in the server hash
define manageSubnets(@server, $subnet_href_array) return @server do
  $definition_hash = to_object(@server)
  $definition_hash["fields"]["subnet_hrefs"] = $subnet_hrefs
  @server = $definition_hash
end

# Creates a Placement Group if needed.
define createPlacementGroup($needsPlacementGroup, $cloud_name) return $pg_name do
  # Create the placement group that will be used (if needed)
  $pg_name = null
  if $needsPlacementGroup
    
    # Dump the hash before doing anything
    #$my_server_hash = to_object(@linux_server)
    #rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: "server hash before adding pg", detail: to_s($my_server_hash)})
  
    # Create a unique placement group name, create it, and then place the href into the server declaration.
    $pg_name = join(split(uuid(), "-"))[0..23] # unique placement group - global variable for later deletion 
#    $pg_name = join(["rspg",split(@@deployment.href, "/")[3]])
   
    # create the placement group ....
    $cloud_href = rs.clouds.get(filter: [join(["name==",$cloud_name])]).href
  
    $placement_group_name=$pg_name
          
    $attempts = 0
    $succeeded = false
    $pg_href = null
    while ($attempts < 3) && ($succeeded == false) do
  
      @placement_groups=rs.placement_groups.get(filter: [join(["name==",$placement_group_name])])
        
      if empty?(@placement_groups)
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Did not find placement group, ", $placement_group_name, ". So creating it now."])})
        sub on_error: skip do # ignore an error - we'll deal with possibilities later
          @task=rs.placement_groups.create({"name" : $placement_group_name, "cloud_href" : $cloud_href})
        end
        
      elsif (@placement_groups.state == "available")
        # all good 
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Found placement group, ", $placement_group_name])})
        $succeeded=true
        $pg_href = @placement_groups.href # Will use this later
  
      else # found a placement group but it's in some funky state, so delete and try again.
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["The placement group ", $placement_group_name, "was not created but is in state, ",@placement_groups.state," So deleting and recreating"])})
        sub on_error: skip do # ignore error - we'll deal with possibilities later
          @task=rs.placement_groups.delete({"name" : $placement_group_name, "cloud_href" : $cloud_href})
        end
      end  
      $attempts=$attempts+1
    end
        
    if ($succeeded == false) 
      # If we get here, I'm going to sleep for 8 more minutes and check one last time since there is sometimes a lag between making the request to create and it existing.
      sleep(480)
      @placement_groups=rs.placement_groups.get(filter: [join(["name==",$placement_group_name])])
      if empty?(@placement_groups)
        # just forget it - we tried ....
        raise "Failed to create placement group"
      end
      rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Finally. Placement group, ", $placement_group_name, " has been created."])})
    end
  else # no placement group needed
    $pg_name = "NoPlacementGroupNeeded"
    rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["No placement group is needed for cloud, ", $cloud_name])})
  end
end

# Adds a Placement Group to server if needed.
define managePlacementGroup($needsPlacementGroup, $cloud_name, @server, $pg_name) return @server do
  # Create the placement group that will be used (if needed)
  if $needsPlacementGroup
  
    # Find the placement group created earlier
    @placement_groups=rs.placement_groups.get(filter: [join(["name==",$pg_name])])
    $pg_href = @placement_groups.href # Will use this later

    # Configure the server with the placement group
    $my_server_hash = to_object(@server)
    $my_server_hash["fields"]["placement_group_href"] = $pg_href
    @server = $my_server_hash
      
    # Dump the hash after the update
    #rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: "server hash after adding pg", detail: to_s($my_server_hash)})
  end
end

# Helper functions
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end

define run_recipe_inputs(@target, $recipe_name, $recipe_inputs) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

define multi_run_recipe_inputs(@target, $recipe_name, $recipe_inputs) do
  @task = @target.multi_run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
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

# Helper definition, runs a script on given server array, waits until script completes or fails
# Raises an error in case of failure
define multi_run_script(@target, $right_script_href) do
  @task = @target.multi_run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end
