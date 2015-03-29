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
# Deploys a basic Linux server of type CentOS or Ubuntu as selected by user.
# Installs and sets up simple HTML5 website with user-supplied "Hello World" type text.
# It automatically imports the ServerTemplate it needs.
# Also, if needed by the target cloud, the security group and/or ssh key, etc. is automatically created by the CAT.


# Required prolog
name 'Hello World Web Site'
rs_ca_ver 20131202
short_description "![HTML 5](https://cdn0.iconfinder.com/data/icons/HTML5/128/HTML_Logo.png)\n
Launches a simple HTML 5 web site with user-provided text."
long_description "Launches a simple HTML 5 website with user-provided text."

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure", "VMware"
  default "AWS"
end

parameter "param_servertype" do
  category "User Inputs"
  label "Linux Server Type"
  type "list"
  description "Type of Linux server to launch"
  allowed_values "CentOS 6.6", 
    "Ubuntu 12.04"
  default "CentOS 6.6"
end

parameter "param_webtext" do 
  category "User Inputs"
  label "Web Site Text" 
  type "string" 
  description "Text to display on the web site." 
  default "Hello World!"
end

################################
# Outputs returned to the user #
################################
output "site_link" do
  label "Web Site URL"
  category "Output"
  description "Click to see your web site."
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
    "cloud" => "Azure West US",
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
    "cloud" => "POC vSphere",
    "zone" => "POC-vSphere-Zone-1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
  }
}
end

mapping "map_mci" do {
  "CentOS 6.6" => {
    "mci" => "RightImage_CentOS_6.6_x64_v13.5_LTS"
  },
  "Ubuntu 12.04" => {
    "mci" => "RightImage_Ubuntu_12.04_x64_v13.5_LTS"
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
  name join(["LinuxServerSecGrp-",@@deployment.href])
  description "Linux Server security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "Web server SSH Rule"
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

resource "sec_group_rule_http", type: "security_group_rule" do
  name "Web server HTTP Rule"
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


### Server Definition ###
resource "linux_server", type: "server" do
  name 'Web Site Server'
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"))
  ssh_key switch($needsSshKey, 'cat_sshkey', null)
#  security_groups switch($needsSecurityGroup, @sec_group, null)  # JIRA SS-1892
  security_group_hrefs map($map_cloud, $param_location, "sg")  # TEMPORARY UNTIL JIRA SS-1892 is solved
  subnets 'TenantSubnet'  # Hardcoded to point at the subnet in account 80278
  associate_public_ip_address "false"
# NOTE: No placement group field is provided here. Instead placement groups are handled in the launch definition below.
  server_template find('Simple HTML5 Website', revision: 4)
#  WEBTEXT input is managed at the deployment level so that it is persistent across stop/starts
#  inputs do {
#    "WEBTEXT" => join(["text:", $param_webtext])
#  } end
end


####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "launch_server"
  output_mappings do {
    $site_link => $server_ip_address,
  } end
end

operation "terminate" do
  description "Terminate the server and clean up"
  definition "terminate_server"
end


operation "Update Web Site Text" do
  description "Update the text displayed on the web site."
  definition "update_website"
end




##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
# This does NOT install WordPress.
define launch_server(@linux_server, @sec_group, @sec_group_rule_ssh, @sec_group_rule_http, $map_cloud, $param_location, $param_webtext, $needsSshKey, $needsSecurityGroup, $needsPlacementGroup, $inAzure) return @linux_server, @sec_group, $server_ip_address, $param_webtext do
  
    # Need the cloud name later on
    $cloud_name = map( $map_cloud, $param_location, "cloud" )
  
    # Check if the selected cloud is supported in this account.
    # Since different PIB scenarios include different clouds, this check is needed.
    # It raises an error if not which stops execution at that point.
    call checkCloudSupport($cloud_name, $param_location)

    # Find and import the server template - just in case it hasn't been imported to the account already
    @pub_st=rs.publications.index(filter: ["name==Simple HTML5 Website", "revision==4"])
    @pub_st.import()
    
    # Create the SSH key that will be used (if needed)
    call manageSshKey($needsSshKey, $cloud_name)
    
    # Create a placement group if needed and update the server declaration to use it
    call managePlacementGroup($needsPlacementGroup, $cloud_name, @linux_server) retrieve @linux_server
    
    # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
    if $needsSecurityGroup
      provision(@sec_group_rule_ssh)
      provision(@sec_group_rule_http)
    end
    
    # The CREDENTIAL mechanism in CM is used to store the web text so it can be remembered
    # TODO: Use a deployment-level tag to store this info instead since the deployment survives stop/starts.
    $cred_name = join(["HELLOWORLDTEXT-",@@deployment.href])
    @cred = rs.credentials.get(filter: join(["name==",$cred_name]))
    if empty?(@cred)  # this is the first time through so create the cred to store the info
      @task=rs.credentials.create({"name":$cred_name, "value": $param_webtext})
    end
    
    # set the deployment level WEBTEXT input so it is inherited by the launched server
    @cred = rs.credentials.get(filter: join(["name==",$cred_name]), view:"sensitive")
    $cred_hash = to_object(@cred)
    $my_webtext = to_s($cred_hash["details"][0]["value"])
    $inp = {
     "WEBTEXT": join(["text:", $my_webtext])
     }
    @@deployment.multi_update_inputs(inputs: $inp)
    
    # Provision the server
    provision(@linux_server)
    
    # If deployed in Azure one needs to provide the port mapping that Azure uses.
    if $inAzure
       @bindings = rs.clouds.get(href: @linux_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @linux_server.current_instance().href])
       @binding = select(@bindings, {"private_port":80})
       $server_ip_address = join(["http://", to_s(@linux_server.current_instance().public_ip_addresses[0]), ":", @binding.public_port])
    else
       $server_ip_address = join(["http://", to_s(@linux_server.current_instance().public_ip_addresses[0])])
    end
    
    # Take this opportunity to clean up any orphaned creds
    call clean_webtext_stores() 
    
end 

#
# Modify the web page text
#
define update_website(@linux_server, $param_webtext) return $param_webtext do
  task_label("Update Web Page")
  
  # Update the cred that contains the web text for later use
  $cred_name = join(["HELLOWORLDTEXT-",@@deployment.href])
  @cred = rs.credentials.get(filter: join(["name==",$cred_name]))
  @cred.update(credential: {"value" : $param_webtext})
    
  # Update the deployment and server with the new webtext
  $inp = {
   "WEBTEXT": join(["text:", $param_webtext])
  }
  @@deployment.multi_update_inputs(inputs: $inp)
  
  # The text also needs to be pushed to the existing server level since currently deployment level inputs are not inherited by CAT-provisioned server
  @linux_server.current_instance().multi_update_inputs(inputs: $inp)
   
  # Now run the script to update the web page.
  $script_name = "Hello World - HTML5"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href
  @task = @linux_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
#  @task = @linux_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {WEBTEXT: "text:"+$param_webtext})
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end  
end

# Terminate the server
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
    
    if $needsSecurityGroup
      rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Deleting security group, ", @sec_group])})
      @sec_group.destroy()
    end
    
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

# Cleans up any orphaned webtext creds from old deployments.
define clean_webtext_stores() do
  
  # Find all the hello world cred stores
  $cred_root = "HELLOWORLDTEXT-"
  @creds = rs.credentials.get(filter: join(["name==",$cred_root]))
      
  # Find all the current deployments
  @deployments = rs.deployments.get()
  $deployment_hrefs = @deployments.href[]
    
  # Now find any creds that don't belong to a deployment
  foreach @cred in @creds do
    $cred_name = @cred.name
    $check_value = split($cred_name, "-")[1]
    if logic_not(contains?($deployment_hrefs, [$check_value]))
      rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["deleting credential, ", @cred.name])})
      @cred.destroy()
    end
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
