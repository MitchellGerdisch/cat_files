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
# Deploys a Docker server and automatically installs WordPress.
# It automatically imports the ServerTemplate it needs.
# Also, if needed by the target cloud, the security group and/or ssh key is automatically created by the CAT.

# 
# PREREQUISITES
#   For vSphere Support: 
#     A vSphere environment needs to have been set up and registered with the RightScale account being used for the POC.
#     The environment must be registered as "POC vSphere" to match the cloud mapping used in the code below.
#   

# Required prolog
name 'Docker WordPress'
rs_ca_ver 20131202
short_description '![logo] (https://s3.amazonaws.com/selfservice-logos/docker.png) ![logo] (https://s3.amazonaws.com/selfservice-logos/wordpress-logo-stacked-rgb.png)'
long_description '![logo] (https://s3.amazonaws.com/selfservice-logos/docker.png) ![logo] (https://s3.amazonaws.com/selfservice-logos/wordpress-logo-stacked-rgb.png)'

##################
# User inputs    #
##################
parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  # CURRENTLY Azure is not supported by the ServerTemplate used in this CAT and so is not presented as an option at this time.
  # vSphere is only available if POC includes the vSphere add-on
  allowed_values "AWS", "Google", "vSphere (if available)" 
  default "AWS"
end


################################
# Outputs returned to the user #
################################
output "host" do
  label "hostname"
  category "Output"
  description "Link to the WordPress server."
  default_value join(["http://",@docker_wordpress_server.public_ip_address])
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
    "mci_name" => "RightImage_CentOS_6.5_x64_v14.1",
  },
  "Azure" => {   
    "cloud_provider" => "Azure", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "medium",
    "sg" => null, # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
    "mci_name" => null, # This ServerTemplate does not (currently) support Azure.
  },
  "Google" => {
    "cloud_provider" => "Google", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
    "mci_name" => "RightImage_CentOS_6.5_x64_v14.1",
  },
  "vSphere (if available)" => {
    "cloud_provider" => "vSphere", # provides a standard name for the provider to be used elsewhere in the CAT
    "cloud" => "POC vSphere",
    "zone" => "Gerdisch-Basement-Zone-1", # DEBUG TESTnull,  
    "instance_type" => "small",
    "sg" => null, # TEMPORARY UNTIL switch() works for security group - see JIRA SS-1892
    "mci_name" => "RightImage_CentOS_6.5_x64_v14.1_vSphere",   # Need to find the MCI for vSphere environments.
  }
}
end


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

############################
# RESOURCE DEFINITIONS     #
############################

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  name join(["DockerWordpressSecGrp-",@@deployment.href])
  description "Docker-Wordpress deployment security group."
  cloud map( $map_cloud, $param_location, "cloud" )
end

resource "sec_group_rule_http", type: "security_group_rule" do
  name "Docker-Wordpress deployment HTTP Rule"
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

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "Docker-Wordpress deployment SSH Rule"
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
resource "docker_wordpress_server", type: "server" do
  name 'Docker WordPress'
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  instance_type map($map_cloud, $param_location, "instance_type")
  multi_cloud_image find(map($map_cloud, $param_location, "mci_name"))
  ssh_key switch($needsSshKey, 'dwp_sshkey', null)
#  security_groups switch($needsSecurityGroup, @sec_group, null)  # JIRA SS-1892
  security_group_hrefs map($map_cloud, $param_location, "sg")  # TEMPORARY UNTIL JIRA SS-1892 is solved
  server_template find('Docker ServerTemplate for Linux (v14.1.0)')
  inputs do {
    'ephemeral_lvm/filesystem' => 'text:ext4',
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
  } end
end

### DEBUG - HARDCODED FROM EXPORT ####
#resource 'docker_wordpress_server', type: 'server' do
#  name 'Docker ServerTemplate for Linux (v14.1.0)'
#  cloud 'POC vSphere'
#  datacenter 'Gerdisch-Basement-Zone-1'
#  instance_type 'small'
#  multi_cloud_image find('RightImage_CentOS_6.5_x64_v14.1_vSphere', revision: 7)
#  ssh_key 'dwp_sshkey'
#  server_template find('Docker ServerTemplate for Linux (v14.1.0)', revision: 2)
#  inputs do {
#    'ephemeral_lvm/filesystem' => 'text:ext4',
#    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
#    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
#    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
#    'ephemeral_lvm/stripe_size' => 'text:512',
#    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
#    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
#    'rs-base/swap/size' => 'text:1',
#  } end
#end


####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "launch_server"
end

operation "enable" do
  description "Install and enable WordPress"
  definition "enable_application"
end


##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
# This does NOT install WordPress.
define launch_server(@docker_wordpress_server, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, $map_cloud, $param_location, $needsSshKey, $needsSecurityGroup) return @docker_wordpress_server do
  
    # Find and import the server template - just in case it hasn't been imported to the account already
    @pub_st=rs.publications.index(filter: ["name==Docker ServerTemplate for Linux (v14.1.0)", "revision==2"])
    @pub_st.import()
    
    $cloud_name = map( $map_cloud, $param_location, "cloud" )
    
    # Create the SSH key that will be used (if needed)
    if $needsSshKey
      $ssh_key_name="dwp_sshkey"
      @key=rs.clouds.get(filter: [join(["name==",$cloud_name])]).ssh_keys(filter: [join(["resource_uid==",$ssh_key_name])])
      if empty?(@key)
          rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Did not find SSH key, ", $ssh_key_name, ". So creating it now."])})
          rs.clouds.get(filter: [join(["name==",$cloud_name])]).ssh_keys().create({"name" : $ssh_key_name})
      else
          rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["SSH key, ", $ssh_key_name, " already exists."])})
      end
    else
      rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: join(["Allegedly no SSH key is needed for cloud, ", $cloud_name])})
    end
    
    # Provision the security group rules if applicable. (The security group itself is created when the server is provisioned.)
    if $needsSecurityGroup
      provision(@sec_group_rule_http)
      provision(@sec_group_rule_ssh)
    end

    # Provision the server
    provision(@docker_wordpress_server)


end 

# Install and enable WordPress
define enable_application(@docker_wordpress_server) do
  # Install wordpress in a docker container
  call run_recipe(@docker_wordpress_server, "rsc_docker::wordpress", {})
end


### Helper Functions ###
define run_recipe(@target, $recipe_name, $recipe_inputs) do
  $attempts = 0
  sub  on_error:handle_retries($attempts) do
    $attempts = $attempts + 1
    @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
    sleep_until(@task.summary =~ "^(completed|failed)")
    if @task.summary =~ "failed"
      raise "Failed to run " + $recipe_name
    end
   end
end