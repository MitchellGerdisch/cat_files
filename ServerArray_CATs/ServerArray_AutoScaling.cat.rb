#Copyright 2015 RightScale
#x
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.


#RightScale Cloud Application Template (CAT)

# DESCRIPTION
# Used as a test bed for serverarrays in CATs.
# Reuses PFT assets.
# Uses a customer ServerTemplate with a scaling alert set up in it.

# Required prolog
name 'AutoScaling ServerArray Example'
rs_ca_ver 20161221
short_description "Stand up serverarray configured for autoscaling."
long_description "Test bed and example of how to declare a serverarray in CAT that supports autoscaling."

import "pft/parameters"
import "pft/mappings"
import "pft/resources", as: "common_resources"
import "pft/linux_server_declarations"
import "pft/conditions"
import "pft/cloud_utilities", as: "cloud"
import "pft/account_utilities", as: "account"
import "pft/err_utilities", as: "debug"
import "pft/permissions"
import "pft/mci"
import "pft/mci/linux_mappings", as: "linux_mappings"
 
##################
# Permissions    #
##################
permission "pft_general_permissions" do
  like $permissions.pft_general_permissions
end

##################
# User inputs    #
##################
parameter "param_location" do
  like $parameters.param_location
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
end

parameter "param_numservers" do
  like $parameters.param_numservers
end

parameter "param_costcenter" do 
  like $parameters.param_costcenter
end

################################
# Outputs returned to the user #
################################
#output_set "output_server_ips" do
#  label @linux_servers.name
#  category "IP Addresses"
#end

#output "vmware_note" do
#  condition $invSphere
#  label "Deployment Note"
#  category "Note"
#  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible. If you need access to the CloudApp, please contact your RightScale rep for network access."
#end

##############
# MAPPINGS   #
##############
mapping "map_cloud" do 
  like $mappings.map_cloud
end

mapping "map_instancetype" do 
  like $mappings.map_instancetype
end

mapping "map_config" do 
  like $linux_server_declarations.map_config
end

mapping "map_image_name_root" do 
 like $linux_mappings.map_image_name_root
end


############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###
resource "my_serverarray", type: "server_array" do
  name join(['linux-',last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  network find(map($map_cloud, $param_location, "network"))
  subnets find(map($map_cloud, $param_location, "subnet"))
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "pg")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  server_template_href find("Basic ServerArray ST", revision: 0) #map($map_config, "st", "name"), revision: map($map_config, "st", "rev"))
  multi_cloud_image_href find(map($map_config, "mci", "name"), revision: map($map_config, "mci", "rev"))
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => 1,
      "max_count"            => 4
    },
    "pacing" => {
      "resize_calm_time"     => 3, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 40,
      "voters_tag_predicate" => "default_vote_tag"
    }
  } end
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  condition $needsSecurityGroup
  like @common_resources.sec_group
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  condition $needsSecurityGroup
  like @common_resources.sec_group_rule_ssh
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  condition $needsSshKey
  like @common_resources.ssh_key
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  condition $needsPlacementGroup
  like @common_resources.placement_group
end 


##################
# CONDITIONS     #
##################

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  like $conditions.needsSshKey
end

condition "needsSecurityGroup" do
  like $conditions.needsSecurityGroup
end

condition "needsPlacementGroup" do
  like $conditions.needsPlacementGroup
end

condition "invSphere" do
  like $conditions.invSphere
end

condition "notInVsphere" do
  logic_not($invSphere)
end

condition "inAzure" do
  like $conditions.inAzure
end 

condition "inAzureRM" do
  like $conditions.inAzureRM
end 

####################
# OPERATIONS       #
####################
#operation "launch" do 
#  description "Launch the server"
#  definition "launcher"
#end
#
#operation "enable" do
#  description "Get information once the app has been launched"
#  definition "enable"
#end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
define launcher(@my_serverarray) return @my_serverarray do
  

     
end

define enable($param_costcenter) do
  
    # Tag the servers with the selected project cost center ID.
    $tags=[join(["costcenter:id=",$param_costcenter])]
    rs_cm.tags.multi_add(resource_hrefs: @@deployment.server_arrays().current_instances().href[], tags: $tags)
    

end 
