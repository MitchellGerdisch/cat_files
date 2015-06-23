name 'LAMP Stack'
rs_ca_ver 20131202
short_description "![logo](http://nextstone.ca/nextstone.ca/nextstone/images/stories/lamp_logo.png)

Launches a 3-tier LAMP stack."
long_description "Launches a 3-tier LAMP stack."
##################
# User inputs    #
##################
parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  allowed_values "SoftLayer", "VMware" 
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

parameter "cost_center" do
  type "string"
  label "Cost Center"
  category "Business"
  allowed_values "CC a","CC b","CC c","CC d","CC e"
  #description "Cost Center"
end

parameter "line_of_business" do
  type "string"
  label "Line of Business"
  category "Business"
  allowed_values "LOB 1","LOB 2","LOB 3","LOB 4","LOB 5"
  #description "Line of Business"
end

parameter "project_code" do
  type "string"
  label "Project Code"
  category "Business"
  default "abcd1234"
  #description "Eight digit project code"
end


################################
# Outputs returned to the user #
################################
output "site_url" do
  label "LAMP Stack Test"
  category "Output"
  description "Click to test the stack."
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
#    "mci_name" => "RightImage_CentOS_6.6_x64_v14.2_1_VMware_CIBC_POC",
#    "mci_rev" => null,
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
    "name" => "PHP App Server (v14.1.1) CIBC POC",
    "rev" => "1",
  },
  "db" => {
    "name" => "Database Manager for MySQL (v14.1.1) CIBC POC",
    "rev" => "1",
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
  } end
end

resource 'app_server', type: 'server' do
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
    'rs-application_php/listen_port' => 'text:8080',
    'rs-application_php/scm/repository' => 'text:git://github.com/rightscale/examples.git',
    'rs-application_php/scm/revision' => 'text:unified_php',
    'rs-application_php/vhost_path' => 'text:/dbread',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
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
  } end
end 

operation "terminate" do
  description "Terminate the servers and clean up"
  definition "terminate_server"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
define generated_launch(@lb_server, @app_server, @db_server, @sec_group, @sec_group_rule_http, @sec_group_rule_http8080, @sec_group_rule_mysql, $map_cloud, $map_st, $map_db_creds, $param_location, $line_of_business, $cost_center, $project_code, $needsPlacementGroup, $needsSecurityGroup, $invSphere)  return @lb_server, @app_server, @db_server, $site_link do 
  
  # Need the cloud name later on
  $cloud_name = map( $map_cloud, $param_location, "cloud" )

  # Check if the selected cloud is supported in this account.
  # Since different PIB scenarios include different clouds, this check is needed.
  # It raises an error if not which stops execution at that point.
  call checkCloudSupport($cloud_name, $param_location)
  
  # Create a placement group if needed and update the server declaration to use it
  call createPlacementGroup($needsPlacementGroup, $cloud_name) retrieve $pg_name
  call managePlacementGroup($needsPlacementGroup, $cloud_name, @lb_server, $pg_name) retrieve @lb_server
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
    call manageSubnets(@lb_server, $subnet_hrefs) retrieve @lb_server
    call manageSubnets(@app_server, $subnet_hrefs) retrieve @app_server
    call manageSubnets(@db_server, $subnet_hrefs) retrieve @db_server
  end
 
  # Launch the servers concurrently
  concurrent return  @lb_server, @app_server, @db_server do 
    provision(@lb_server)
    provision(@app_server)
    provision(@db_server)
  end 
  
  #Add business-related tags to the servers
  $tags=[join(["cibc:line_of_business=",$line_of_business]),
    join(["cibc:cost_center=",$cost_center]),
    join(["cibc:project_code=",$project_code])]
  rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
  
  # Run some post-launch scripts to get things working together
  # Import a test database
  call run_recipe_inputs(@db_server, "rs-mysql::dump_import", {})  # applicable inputs were set at launch
    
  # Set up the tags for the load balancer and app servers to find each other.
  call run_recipe_inputs(@lb_server, "rs-haproxy::tags", {})
  call run_recipe_inputs(@app_server, "rs-application_php::tags", {})  
    
  # Now tell the LB to find the app server
  call run_recipe_inputs(@lb_server, "rs-haproxy::frontend", {})
    
  # Depending on the environment, the link provided back to the user needs to be tweaked
  # assume public IP
  $ip_address = @lb_server.current_instance().public_ip_addresses[0]
  if  $invSphere
    # Use private IP address
    $ip_address = @lb_server.current_instance().private_ip_addresses[0]
  end
  
  # Now if in Azure need to get the port mapping.
  if $inAzure
     @bindings = rs.clouds.get(href: @lb_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @lb_server.current_instance().href])
     @binding = select(@bindings, {"private_port":80})
     $site_link = join(["http://", to_s($ip_address), ":", @binding.public_port, "/dbread"])
  else
    $site_link = join(["http://", to_s($ip_address), "/dbread"])
  end
end 

# Terminate the servers
define terminate_server(@lb_server, @app_server, @db_server, @sec_group, $map_cloud, $param_location, $needsSecurityGroup, $needsPlacementGroup) do
    
    $cloud_name = map( $map_cloud, $param_location, "cloud" )

    # find the placement group before deleting the server and then delete the PG once the server is gone
    if $needsPlacementGroup 
      sub on_error: skip do  # if might throw an error if we are stopped and there's nothing existing at this point.
        @pg_res = @lb_server.current_instance().placement_group()
        $$pg_name = @pg_res.name
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Placement group associated with the server: ", $$pg_name])})
      end
    end
    
    # Terminate the servers
    concurrent do 
      delete(@lb_server)
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


