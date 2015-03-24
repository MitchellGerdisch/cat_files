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
# It automatically imports the ServerTemplate it needs.
# Also, if needed by the target cloud, the security group and/or ssh key is automatically created by the CAT.


# Required prolog
name 'Linux Server'
rs_ca_ver 20131202
short_description "![Linux](http://www.cd-webdesign.co.uk/images/logos/linux-logo.png)\n
Launches a Linux server"
long_description "Launches a Linux server."

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure" # skipping Google for now "Google"
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

################################
# Outputs returned to the user #
################################
output "ssh_link" do
  label "SSH Link"
  category "Output"
  description "Use this string along with your SSH key to access your server."
end

output "ssh_key_info" do
  label "Link to your SSH Key"
  category "Output"
  description "Use this link to download your SSH private key and use it to login to the server using provided \"SSH Link\"."
  default_value "https://my.rightscale.com/global/users/ssh#ssh"
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
  "vSphere (if available)" => {
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
  instance_type map($map_cloud, $param_location, "instance_type")
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"))
  ssh_key switch($needsSshKey, 'cat_sshkey', null)
#  security_groups switch($needsSecurityGroup, @sec_group, null)  # JIRA SS-1892
  security_group_hrefs map($map_cloud, $param_location, "sg")  # TEMPORARY UNTIL JIRA SS-1892 is solved
# NOTE: No placement group field is provided here. Instead placement groups are handled in the launch definition below.
  server_template find('Base ServerTemplate for Linux (RSB) (v13.5.11-LTS)', revision: 23)
end


####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "launch_server"
end

operation "enable" do
  description "Enable the server"
  definition "enable_server"
  # Update the links provided in the outputs.
  output_mappings do {
    $ssh_link => $server_ip_address,
  } end
end

operation "terminate" do
  description "Terminate the server and clean up"
  definition "terminate_server"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
# This does NOT install WordPress.
define launch_server(@linux_server, @sec_group, @sec_group_rule_ssh, $map_cloud, $param_location, $needsSshKey, $needsSecurityGroup, $needsPlacementGroup) return @linux_server, @sec_group do
  
    # Need the cloud name later on
    $cloud_name = map( $map_cloud, $param_location, "cloud" )

    # Find and import the server template - just in case it hasn't been imported to the account already
    @pub_st=rs.publications.index(filter: ["name==Base ServerTemplate for Linux (RSB) (v13.5.11-LTS)", "revision==23"])
    @pub_st.import()
    
    # Create the SSH key that will be used (if needed)
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
    
    # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
    if $needsSecurityGroup
      provision(@sec_group_rule_ssh)
    end

    # Provision the server
    provision(@linux_server)
   
end 

# Enabling is really just fixing the links to accommodate the Azure port mapping stuff.
define enable_server(@linux_server, $inAzure) return $server_ip_address do
  # If deployed in Azure one needs to provide the port mapping that Azure uses.
  if $inAzure
     @bindings = rs.clouds.get(href: @linux_server.current_instance().cloud().href).ip_address_bindings(filter: ["instance_href==" + @linux_server.current_instance().href])
     @binding = select(@bindings, {"private_port":22})
     $server_ip_address = join(["-p ", @binding.public_port, " rightscale@", to_s(@linux_server.current_instance().public_ip_addresses[0])])
  else
     $server_ip_address = join(["rightscale@", @linux_server.current_instance().public_ip_addresses[0]])
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

define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  else
    $_error_behavior = "skip"
  end
end
