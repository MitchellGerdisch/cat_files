#
#The MIT License (MIT)
#
#Copyright (c) 2014 BMitch Gerdisch
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
# A simple CAT file for a single Linux server.
# Used to play with ideas and approaches.
#
# User picks geographical location and performance level (CPU/RAM).
# CAT maps the location to a cloud AWS, Azure, Rackspace.
# CAT maps performance level to an instance type in the given cloud
# CAT deploys the RightImage_Ubuntu_12.04_x64_v13.5 [rev 33] image based on the above.
#   This image is a multicloud image for AWS, Azure and RackSpace.

name 'User Selectable Location and Performance - Ubuntu Linux Server'
rs_ca_ver 20131202
short_description '![Ubuntu](http://design.ubuntu.com/wp-content/uploads/logo-ubuntu_st_no%C2%AE-white_orange-hex-140x140.png)
Builds single Ubuntu instance of selected performance level in selected geographic location'


##############
# PARAMETERS #
##############

# User can select a geographical location for the server which will then pick a cloud and zone based on the mapping below.
# User can also select size parameter which is mapped to a given instance type/flavor for the selected cloud.

parameter "param_location" do 
  category "Deployment Options"
  label "Location" 
  type "string" 
  description "Geographical location for the server." 
  allowed_values "Australia", "Brazil", "Japan", "Netherlands", "Singapore", "USA", "Saturn"
  default "USA"
end

parameter "param_performance" do 
  category "Deployment Options"
  label "Performance profile" 
  type "string" 
  description "Compute and RAM" 
  allowed_values "low", "medium", "high"
  default "low"
end




##############
# MAPPINGS   #
##############


mapping "map_instance_type" do {
  "AWS" => {
    "low" => "c3.large",  # 2 CPUs x 3.75GB
    "medium" => "c3.xlarge", # 4 CPUs x 7GB
    "high" => "c3.2xlarge", # 8 CPUs x 15GB
  },
  "RS" => {
    # These choices are driven by what is configured for RS London cloud in RS.
    "low" => "4GB Standard Instance", # 2 CPUs x 4GB
    "medium" => "8GB Standard Instance", # 4CPUs  x 8GB
    "high" => "15GB Standard Instance", # 6 CPUs x 15GB
  },
  "Azure" => {
    "low" => "medium", # 2 CPUs x 3.5GB
    "medium" => "large", # 4 CPUs x 7GB
    "high" => "extra large", # 8CPUs x 15GB
  },
}
end

mapping "map_cloud" do {
  "Australia" => {
    "provider" => "AWS",
    "cloud" => "ap-southeast-2",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Brazil" => {
    "provider" => "AWS",
    "cloud" => "sa-east-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Netherlands" => {
    "provider" => "Azure",
    "cloud" => "Azure West Europe",
    "security_group" => null,
    "ssh_key" => null,
  },
  "Japan" => {
    "provider" => "AWS",
    "cloud" => "ap-northeast-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Singapore" => {
    "provider" => "Azure",
    "cloud" => "Azure Southeast Asia",
    "security_group" => null,
    "ssh_key" => null,
  },
  "USA" => {
    "provider" => "AWS",
    "cloud" => "us-east-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
  "Saturn" => {   # For testing purposes
    "provider" => "Azure",
    "cloud" => "Azure East US",
    "security_group" => null,
    "ssh_key" => null,
  },
}
end


##############
# CONDITIONS #
##############
# NONE #


##############
# OUTPUTS    #
##############

output 'ip_address' do
  label "Server IP Address" 
  category "Server Info"
  default_value @your_server.public_ip_address
  description "IP address of server."
end
 
output 'cloud' do
  label "Cloud" 
  category "Server Info"
  default_value @your_server.cloud
  description "Cloud used for the server deployment."
end

output 'instance_type' do
  label "Server specs"
  category "Server Info"
  default_value join([ $param_performance, ' (', @your_server.instance_type, ')'])
  description "The selected server performance level and related cloud instance_type"
end

##############
# RESOURCES  #
##############

resource 'your_server', type: 'server' do
  name 'Your Server'
  cloud map($map_cloud, $param_location, 'cloud')
  instance_type map( $map_instance_type, map( $map_cloud, $param_location,'provider'), $param_performance)
  server_template find('Base ServerTemplate for Linux (v13.5.5-LTS)', revision: 21)
  multi_cloud_image_href '/api/multi_cloud_images/373980003'
  security_groups map( $map_cloud, $param_location, 'security_group' )
  ssh_key map( $map_cloud, $param_location, 'ssh_key' )
end

##############
# Operations #
##############
# NONE AT THIS TIME

####################
# Helper functions #
####################
# Helper definition, runs a recipe on given server, waits until recipe completes or fails
# Raises an error in case of failure
define run_recipe(@target, $recipe_name) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: {})
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

# Helper definition, runs a script on all instances in the array.
# waits until script completes or fails
# Raises an error in case of failure
define multi_run_script(@target, $right_script_href) do
  @task = @target.multi_run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

define log($message) do
  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
end