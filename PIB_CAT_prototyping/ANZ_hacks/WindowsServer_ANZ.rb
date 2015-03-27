#
#The MIT License (MIT)
#
#Copyright (c) 2014 by Richard Shade and Mitch Gerdisch
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

# DESCRIPTION
# Deploys a Windows Server of the type chosen by the user.
# It automatically imports the ServerTemplate it needs.
# Also, if needed by the target cloud, the security group and/or ssh key is automatically created by the CAT.


# Required prolog
name 'Windows Server'
rs_ca_ver 20131202
short_description "![Windows](http://www.cscopestudios.com/images/winhosting.jpg)\n
Launches a Windows server"
long_description "Launches a Windows server."

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure", "VMware"
  default "Azure"
end

parameter "param_servertype" do
  category "User Inputs"
  label "Windows Server Type"
  type "list"
  description "Type of Windows server to launch"
  allowed_values "Windows 2008R2 Base Server"
# CURRENTLY ONLY 2008R2 is supported in the ANZ vSphere env
#  "Windows 2008R2 IIS Server",
#  "Windows 2008R2 Server with SQL 2008",
#  "Windows 2008R2 Server with SQL 2012",
#  "Windows 2012 Base Server",
#  "Windows 2012 IIS Server",
#  "Windows 2012 Server with SQL 2012"
  default "Windows 2008R2 Base Server"
end

parameter "param_username" do 
  category "User Inputs"
  label "Windows Username" 
  description "Username (will be created)."
  type "string" 
  no_echo "false"
end

parameter "param_password" do 
  category "User Inputs"
  label "Windows Password" 
  description "Password (will be created).
  Windows password complexity requirements = at least 8 characters and contain at least 3 of: 
  Uppercase characters, Lowercase characters, Digits 0-9, Non alphanumeric characters." 
  type "string" 
  no_echo "true"
end


################################
# Outputs returned to the user #
################################
output "rdp_link" do
  label "RDP Link"
  category "Output"
  description "RDP Link to the Windows server."
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
    "sg" => '@sec_group',  # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
  },
  "Azure" => {   
    "cloud_provider" => "Azure", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "medium",
    "sg" => null, # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
  },
  "Google" => {
    "cloud_provider" => "Google", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
  },
  "VMware" => {
    "cloud_provider" => "vSphere", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "ANZ Bank vSphere",
    "zone" => "anz_bank_poc", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
  }
}
end

mapping "map_mci" do {
  "Windows 2008R2 Base Server" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_v14.1_VMware ANZ vSphere Support"
  },
  "Windows 2008R2 IIS Server" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_iis7.5_v13.5.0-LTS"
  },
  "Windows 2008R2 Server with SQL 2012" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_sqlsvr2012_v13.5.0-LTS"
  },
  "Windows 2008R2 Server with SQL 2008" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_sqlsvr2k8r2_v13.5.0-LTS"
  },
  "Windows 2012 IIS Server" => {
    "mci" => "RightImage_Windows_2012_x64_iis8_v13.5.0-LTS"
  },
  "Windows 2012 Server with SQL 2012" => {
    "mci" => "RightImage_Windows_2012_x64_sqlsvr2012_v13.5.0-LTS"
  },
  "Windows 2012 Base Server" => {
    "mci" => "RightImage_Windows_2012_x64_v13.5.0-LTS"
  },
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
  name join(["WindowsServerSecGrp-",@@deployment.href])
  description "Windows Server security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_rdp", type: "security_group_rule" do
  name "Windows Server RDP Rule"
  description "Allow RDP access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "3389",
    "end_port" => "3389"
  } end
end


### Server Definition ###
resource "windows_server", type: "server" do
  name 'Windows Server'
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"))
  ssh_key switch($needsSshKey, 'cat_sshkey', null)
#  security_groups switch($needsSecurityGroup, @sec_group, null)  # JIRA SS-1892
  security_group_hrefs map($map_cloud, $param_location, "sg")  # TEMPORARY UNTIL JIRA SS-1892 is solved
  # NOTE: No placement group field is provided here. Instead placement groups are handled in the launch definition below.
  server_template find('Base ServerTemplate for Windows (v14.1) - ANZ vSphere Support')
  inputs do {
    "ADMIN_ACCOUNT_NAME" => join(["text:",$param_username]),
    "ADMIN_PASSWORD" => join(["cred:CAT_WINDOWS_ADMIN_PASSWORD-",@@deployment.href]), # this credential gets created below using the user-provided password.
    "FIREWALL_OPEN_PORTS_TCP" => "text:3389",
    "SYS_WINDOWS_TZINFO" => "text:Pacific Standard Time",  
  } end
end


####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "launch_server"
  # Update the links provided in the outputs.
  output_mappings do {
    $rdp_link => $server_ip_address,
  } end
end

operation "terminate" do
  description "Terminate the server and clean up"
  definition "terminate_server"
end

operation "Update Server Password" do
  description "Update/reset password."
  definition "update_password"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
define launch_server(@windows_server, @sec_group, @sec_group_rule_rdp, $map_cloud, $param_location, $param_password, $needsSshKey, $needsSecurityGroup, $needsPlacementGroup, $inAzure) return @windows_server, @sec_group, $server_ip_address do
  
    # Need the cloud name later on
    $cloud_name = map( $map_cloud, $param_location, "cloud" )
    
    # Check if the selected cloud is supported in this account.
    # Since different PIB scenarios include different clouds, this check is needed.
    # It raises an error if not which stops execution at that point.
    call checkCloudSupport($cloud_name, $param_location)

    # Find and import the server template - just in case it hasn't been imported to the account already
#    @pub_st=rs.publications.index(filter: ["name==Base ServerTemplate for Windows (v13.5.0-LTS)", "revision==3"])
#    @pub_st.import()
    
    # Create the Admin Password credential used for the server based on the user-entered password.
    $credname = join(["CAT_WINDOWS_ADMIN_PASSWORD-",@@deployment.href])
    @task=rs.credentials.create({"name":$credname, "value": $param_password})
    
    # Create the SSH key that will be used (if needed)
    call manageSshKey($needsSshKey, $cloud_name)
    
    # Create a placement group if needed and update the server declaration to use it
    call managePlacementGroup($needsPlacementGroup, $cloud_name, @windows_server) retrieve @windows_server
     
    
    # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
    if $needsSecurityGroup
      provision(@sec_group_rule_rdp)
    end

    # Provision the server
    provision(@windows_server)
    
    # If deployed in Azure one needs to provide the port mapping that Azure uses.
    if $inAzure
       @bindings = rs.clouds.get(href: @windows_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @windows_server.current_instance().href])
       @binding = select(@bindings, {"private_port":3389})
       $server_ip_address = join([to_s(@windows_server.current_instance().public_ip_addresses[0]),":",@binding.public_port])
    else
       $server_ip_address = @windows_server.current_instance().public_ip_addresses[0]
    end
   
end 

# post launch action to change the credentials
define update_password(@windows_server, $param_password) do
  task_label("Update the windows server password.")

  if $param_password
    $cred_name = join(["CAT_WINDOWS_ADMIN_PASSWORD-",@@deployment.href])
    # update the credential
    rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Updating credential, ", $cred_name])})
    @cred = rs.credentials.get(filter: join(["name==",$cred_name]))
    @cred.update(credential: {"value" : $param_password})
  end
  
  # Now run the set admin script which will use the newly updated credential.
  $script_name = "SYS Set admin account (v13.5.0-LTS)"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href
  @task = @windows_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end  
end

# Terminate the cred and server
define terminate_server(@windows_server, @sec_group, $map_cloud, $param_location, $needsSecurityGroup, $needsPlacementGroup) do
  
  # Delete the cred we created for the user-provided password
  $credname = join(["CAT_WINDOWS_ADMIN_PASSWORD-",@@deployment.href])
  @cred=rs.credentials.get(filter: [join(["name==",$credname])])
  @cred.destroy()
  
  # find the placement group before deleting the server and then delete the PG once the server is gone
  if $needsPlacementGroup 
    sub on_error: skip do  # if might throw an error if we are stopped and there's nothing existing at this point.
      @pg_res = @windows_server.current_instance().placement_group()
      $$pg_name = @pg_res.name
      rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Placement group associated with the server: ", $$pg_name])})
    end
  end
    
  # Terminate the server
  delete(@windows_server)
  
  if $needsSecurityGroup
    rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Deleting security group, ", @sec_group])})
    @sec_group.destroy()
  end
  
  if $needsPlacementGroup
     rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Placement group name to delete: ", $$pg_name])})
  
     # Sleep a bit to make sure server is cleaned up and I can delete the PG
     sleep(120)

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
define managePlacementGroup($needsPlacementGroup, $cloud_name, @windows_server) return @windows_server do
  # Create the placement group that will be used (if needed)
  if $needsPlacementGroup
    
    # Dump the hash before doing anything
    #$my_server_hash = to_object(@windows_server)
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
    $my_server_hash = to_object(@windows_server)
    $my_server_hash["fields"]["placement_group_href"] = $pg_href
      
    # Dump the hash after the update
    #rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: "server hash after adding pg", detail: to_s($my_server_hash)})
  
    # Copy things back for the later provision ...
    @windows_server = $my_server_hash
  
  else # no placement group needed
    rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["No placement group is needed for cloud, ", $cloud_name])})
  end
end


define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end


