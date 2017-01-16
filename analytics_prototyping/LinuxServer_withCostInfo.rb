# Playing with the idea of presenting cost info to the user as part of the launch sequence.


# Required prolog
name 'Mitch Cost Info Test'
rs_ca_ver 20131202
short_description "![Linux](http://armetrix.com/sites/default/files/styles/thumbnail/public/linux-logo.png)\n
Get a Linux Server VM in any of our supported public or private clouds"
long_description "Launches a Linux server, defaults to Ubuntu.\n
\n
Clouds Supported: <B>AWS, Azure, Google, VMware</B>"

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure", "Google", "VMware"
  default "AWS"
end

parameter "param_servertype" do
  category "User Inputs"
  label "Linux Server Type"
  type "list"
  description "Type of Linux server to launch"
  allowed_values "CentOS", 
    "Ubuntu"
  default "Ubuntu"
end

parameter "param_instancetype" do
  category "User Inputs"
  label "Server Performance Level"
  type "list"
  description "Server performance level"
  allowed_values "standard performance",
    "high performance"
  default "standard performance"
end

################################
# Outputs returned to the user #
################################
output "ssh_link" do
  label "SSH Link"
  category "Output"
  description "Use this string along with your SSH key to access your server."
end

output "vmware_note" do
  condition $invSphere
  label "Deployment Note"
  category "Output"
  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible. If you need access to the CloudApp, please contact your RightScale rep for network access."
end

output "ssh_key_info" do
  label "Link to your SSH Key"
  category "Output"
  description "Use this link to download your SSH private key and use it to login to the server using provided \"SSH Link\"."
  default_value "https://my.rightscale.com/global/users/ssh#ssh"
end

output "estimated_cost" do
  label "Estimated Cost"
  category "Cost"
  description "Estimated cost of this system."
end


##############
# MAPPINGS   #
##############
mapping "map_cloud" do {
  "AWS" => {
    "cloud_provider" => "AWS", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "EC2 us-west-1",
    "zone" => null, # We don't care which az AWS decides to use.
    "instance_type" => "m3.medium",
    "sg" => '@sec_group',  
  },
  "Azure" => {   
    "cloud_provider" => "Azure", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "medium",
    "sg" => null, 
  },
  "Google" => {
    "cloud_provider" => "Google", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
  },
  "VMware" => {
    "cloud_provider" => "vSphere", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "POC vSphere",
    "zone" => "POC-vSphere-Zone-1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
  }
}
end

mapping "map_instancetype" do {
  "standard performance" => {
    "AWS" => "m3.medium",
    "Azure" => "medium",
    "Google" => "n1-standard-1",
    "vSphere" => "small",
  },
  "high performance" => {
    "AWS" => "m3.large",
    "Azure" => "large",
    "Google" => "n1-standard-2",
    "vSphere" => "large",
  }
} end

mapping "map_serverconfig" do {
  "vSphere" => { # vSphere 
    "name" => "Base ServerTemplate for Linux (RSB) (v14.1.0)",
    "rev" => "13",
    "CentOS_mci" => "RightImage_CentOS_6.5_x64_v14.1_vSphere",
    "CentOS_mci_rev" => "7",
    "Ubuntu_mci" => "RightImage_Ubuntu_12.04_x64_v14.1_vSphere",
    "Ubuntu_mci_rev" => "7"
  },
  "Other" => { # all other clouds
    "name" => "Base ServerTemplate for Linux (RSB) (v13.5.11-LTS)",
    "rev" => "23",
    "CentOS_mci" => "RightImage_CentOS_6.6_x64_v13.5_LTS",
    "CentOS_mci_rev" => "14",
    "Ubuntu_mci" => "RightImage_Ubuntu_12.04_x64_v13.5_LTS",
    "Ubuntu_mci_rev" => "11"
  }
} end


##################
# CONDITIONS     #
##################

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  logic_or(equals?(map($map_cloud, $param_location, "cloud_provider"), "AWS"), equals?(map($map_cloud, $param_location, "cloud_provider"), "vSphere"))
end

condition "needsSecurityGroup" do
  logic_or(equals?(map($map_cloud, $param_location, "cloud_provider"), "AWS"), equals?(map($map_cloud, $param_location, "cloud_provider"), "Google"))
end

condition "invSphere" do
  equals?(map($map_cloud, $param_location, "cloud_provider"), "vSphere")
end

condition "inAzure" do
  equals?(map($map_cloud, $param_location, "cloud_provider"), "Azure")
end

condition "needsPlacementGroup" do
  equals?(map($map_cloud, $param_location, "cloud_provider"), "Azure")
end

############################
# RESOURCE DEFINITIONS     #
############################

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  name join(["LinuxServerSecGrp-",@@deployment.href])
  description "Linux Server security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "Linux server SSH Rule"
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


### Server Definition ###
resource "linux_server", type: "server" do
  name 'Linux Server'
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_instancetype, $param_instancetype, map($map_cloud, $param_location, "cloud_provider"))
  ssh_key switch($needsSshKey, 'cat_sshkey', null)
  security_group_hrefs map($map_cloud, $param_location, "sg")  
# NOTE: No placement group field is provided here. Instead placement groups are handled in the launch definition below.
  server_template find(map($map_serverconfig, "Other", "name"), revision: map($map_serverconfig, "Other", "rev"))
  multi_cloud_image find(map($map_serverconfig, "Other", join([$param_servertype, "_mci"])), revision: map($map_serverconfig, "Other", join([$param_servertype, "_mci_rev"])))
  inputs do {
    "SECURITY_UPDATES" => "text:enable" # Enable security updates
  } end
end


####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Do cost analytics"
  definition "price_my_system"
  output_mappings do {
    $estimated_cost => $est_cost,
  } end
end

operation "start" do 
  description "Launch the server"
  definition "launch_server"
  # Update the links provided in the outputs.
  output_mappings do {
    $ssh_link => $server_ip_address,
  } end
end

operation "stop" do
  description "Stop the server and clean up"
  definition "terminate_server"
end

operation "terminate" do
  description "Terminate the server and clean up"
  definition "terminate_server"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

define price_my_system(@linux_server, $map_cloud, $param_location, $param_servertype) return $est_cost do
  
  $est_cost = "Your estimated cost for this system is $1M per hour. If that's OK with you, click the Start button."
  
  
end

# Import and set up what is needed for the server and then launch it.
# This does NOT install WordPress.
define launch_server(@linux_server, @sec_group, @sec_group_rule_ssh, $map_cloud, $map_serverconfig, $param_location, $param_servertype, $needsSshKey, $needsSecurityGroup, $needsPlacementGroup, $inAzure, $invSphere) return @linux_server, @sec_group, $server_ip_address do
  

    # Need the cloud name later on
    $cloud_name = map( $map_cloud, $param_location, "cloud" )

    # Check if the selected cloud is supported in this account.
    # Since different PIB scenarios include different clouds, this check is needed.
    # It raises an error if not which stops execution at that point.
    call checkCloudSupport($cloud_name, $param_location)
    
    # gather up servertemplate and mci values from the mapping
    $server_config = "Other"
    if $invSphere
      $server_config = "vSphere"
    end

    $st_name = map($map_serverconfig, $server_config, "name")
    $st_rev = map($map_serverconfig, $server_config, "rev")
    $mci_name = map($map_serverconfig, $server_config, join([$param_servertype, "_mci"]))
    $mci_rev = map($map_serverconfig, $server_config, join([$param_servertype, "_mci_rev"]))

    # Import the applicable ServerTemplate
    @pub_st=rs.publications.index(filter: [join(["name==",$st_name]), join(["revision==",$st_rev])])
    @pub_st.import()
 
    # Create the SSH key that will be used (if needed)
    call manageSshKey($needsSshKey, $cloud_name)

    # Create a placement group if needed and update the server declaration to use it
    call managePlacementGroup($needsPlacementGroup, $cloud_name, @linux_server) retrieve @linux_server

    # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
    if $needsSecurityGroup
      provision(@sec_group_rule_ssh)
    end
    
    #  tweak the server object to use the applicable ServerTemplate and MCI hrefs for the environment
    if $invSphere
       @st_href = find("server_templates", { name: $st_name, revision: $st_rev })
       $st_href = @st_href.href
       @mci_href = find("multi_cloud_images", { name: $mci_name, revision: $mci_rev })
       $mci_href = @mci_href.href
       
       $my_server_hash = to_object(@linux_server)
       $my_server_hash["fields"]["server_template_href"] = $st_href
       $my_server_hash["fields"]["multi_cloud_image_href"] = $mci_href
    
       @linux_server = $my_server_hash
    end

    # Provision the server
    provision(@linux_server)
    
    # If deployed in Azure one needs to provide the port mapping that Azure uses.
    if $inAzure
       @bindings = rs.clouds.get(href: @linux_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @linux_server.current_instance().href])
       @binding = select(@bindings, {"private_port":22})
       $server_ip_address = join(["-p ", @binding.public_port, " rightscale@", to_s(@linux_server.current_instance().public_ip_addresses[0])])
    else
       if $invSphere  # Use private IP for VMware envs
          $server_addr =  @linux_server.current_instance().private_ip_addresses[0]
       else
          $server_addr =  @linux_server.current_instance().public_ip_addresses[0]
       end
       $server_ip_address = join(["rightscale@", $server_addr])
    end
   
end 


# Terminate the server and clean up the other items around it.
define terminate_server(@linux_server, @sec_group, $map_cloud, $param_location, $needsSecurityGroup, $needsPlacementGroup) do
    
    # find the placement group before deleting the server and then delete the PG once the server is gone
    if $needsPlacementGroup 
      sub on_error: skip do  # if might throw an error if we are stopped and there's nothing existing at this point.
        @pg_res = @linux_server.current_instance().placement_group()
        $$pg_name = @pg_res.name
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Placement group associated with the server: ", $$pg_name])})
      end
    end
    
    # Terminate the server
    delete(@linux_server)
    
    # Clean up the security group
    if $needsSecurityGroup
      rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Deleting security group, ", @sec_group])})
      @sec_group.destroy()
    end
    
    # Now that the server is gone, we can clean up the placement group
    if $needsPlacementGroup
       rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Placement group name to delete: ", $$pg_name])})
       
       $cloud_name = map( $map_cloud, $param_location, "cloud" )
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
  
# Creates CAT SSH key if needed
define manageSshKey($needsSshKey, $cloud_name) do
  if $needsSshKey
    $ssh_key_name="cat_sshkey"
    @key=rs.clouds.get(filter: [join(["name==",$cloud_name])]).ssh_keys(filter: [join(["resource_uid==",$ssh_key_name])])
    if empty?(@key)
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Did not find SSH key, ", $ssh_key_name, ". So creating it now."])})
        rs.clouds.get(filter: [join(["name==",$cloud_name])]).ssh_keys().create({"name" : $ssh_key_name})
    else
        rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["SSH key, ", $ssh_key_name, " already exists."])})
    end
  else
    rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["No SSH key is needed for cloud, ", $cloud_name])})
  end
end

# Creates a Placement Group if needed.
define managePlacementGroup($needsPlacementGroup, $cloud_name, @linux_server) return @linux_server do
  # Create the placement group that will be used (if needed)
  if $needsPlacementGroup
    
    # Dump the hash before doing anything
    #$my_server_hash = to_object(@linux_server)
    #rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: "server hash before adding pg", detail: to_s($my_server_hash)})
  
    # Create a unique placement group name, create it, and then place the href into the server declaration.
    $pg_name = join(split(uuid(), "-"))[0..23] # unique placement group - global variable for later deletion 
    
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
    
    # If I get here, then I have a placement group that I need to insert into the server resource declaration.
    $my_server_hash = to_object(@linux_server)
    $my_server_hash["fields"]["placement_group_href"] = $pg_href
      
    # Dump the hash after the update
    #rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: "server hash after adding pg", detail: to_s($my_server_hash)})
  
    # Copy things back for the later provision ...
    @linux_server = $my_server_hash
  
  else # no placement group needed
    rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["No placement group is needed for cloud, ", $cloud_name])})
  end
end

# Used for retry mechanism
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end
