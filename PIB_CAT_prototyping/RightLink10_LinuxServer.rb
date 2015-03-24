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
name 'RightLink 10 - Linux Server'
rs_ca_ver 20131202
short_description "![Linux](http://www.cd-webdesign.co.uk/images/logos/linux-logo.png)\n
Launches a RightLink 10 enabled Linux server"
long_description "Launches a Linux server using the RightLink 10 agent."

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS" # Only AWS is supported by the off-the-shelf ServerTemplate at this time.
  default "AWS"
end

parameter "param_servertype" do
  category "User Inputs"
  label "Linux Server Type"
  type "list"
  description "Type of Linux server to launch"
  allowed_values "RHEL 6.5",
    "RHEL 7",
    "Debian 7.7",
    "Ubuntu 12.04",
    "Ubuntu 14.04"
  default "Ubuntu 14.04"
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
    "cloud" => "EC2 us-east-1",
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
  "CentOS 7" => {  # CURRENTLY NOT OFFERED AS AN OPTION SINCE IT REQUIRES ACCEPTING TERMS AND CONDITIONS AT AMAZON
    "mci" => "RL10.0.rc2 CentOS 7"
  },
  "RHEL 6.5" => {
    "mci" => "RL10.0.rc2 RHEL 6.5"
  },
  "RHEL 7" => {
    "mci" => "RL10.0.rc2 RHEL 7"
  },
  "Debian 7.7" => {
    "mci" => "RL10.0.rc2 Debian 7.7"
  },
  "Ubuntu 12.04" => {
    "mci" => "RL10.0.rc2 Ubuntu 12.04"
  },
  "Ubuntu 14.04" => {
    "mci" => "RL10.0.rc2 Ubuntu 14.04 LTS"
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
  server_template find('RL10.0.rc2 Linux Base', revision: 3)
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

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
# This does NOT install WordPress.
define launch_server(@linux_server, @sec_group, @sec_group_rule_ssh, $map_cloud, $param_location, $needsSshKey, $needsSecurityGroup, $needsPlacementGroup) return @linux_server do
  
    # Need the cloud name later on
    $cloud_name = map( $map_cloud, $param_location, "cloud" )

    # Find and import the server template - just in case it hasn't been imported to the account already
    @pub_st=rs.publications.index(filter: ["name==RL10.0.rc2 Linux Base", "revision==3"])
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
    
    # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
    if $needsSecurityGroup
      provision(@sec_group_rule_ssh)
    end

    # Provision the server
    provision(@linux_server)
   
end 

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




