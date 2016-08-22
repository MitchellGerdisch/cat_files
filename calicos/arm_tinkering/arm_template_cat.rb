# Uses an ARM template to launch the stack.
#
# TO-DO Handle ARM templates stored in Azure storage instead of passing the template in-line.
# TO-DO Support launching the template into an existing resource group. This requires that on termination only those resources launched by the template are removed.
# TO-DO Add parameters to allow the user to specify the values for the serviceplan.
# TO-DO Add post-launch action to modify the appservice service plan


name 'Launch ARM Template'
rs_ca_ver 20160622
short_description 'Launch ARM template'
long_description "Uses an ARM template to launch an App Service web site with a SQL DB service backend."


import "plugin/arm_common"
import "plugin/arm_template"
import "common/functions"

# User launch time inputs
parameter "param_resource_group" do
  category "User Inputs"
  label "Resource Group" 
  type "string" 
  description "Name of the Resource Group to use or create if it doesn't exist.
  If set to \"default\", the cloud application's deployment name will be used." 
  default "default"
  allowed_pattern '^[a-zA-Z]+[a-zA-Z0-9\-\_]*$'
  constraint_description "Must start with a letter and then can be any combination of letters, numerals or \"-\" or \"_\""
end

parameter "param_chargecode" do 
  category "User Inputs"
  label "Cost Center" 
  type "string" 
  description "Cost center." 
  allowed_values "Development", "QA", "Production"
  default "Development"
end

# Outputs
# TBD

# Operations
operation "launch" do 
  description "Launch the deployment based on ARM template."
  definition "arm_deployment_launch"
end

operation "terminate" do 
  description "Terminate the deployment"
  definition "arm_deployment_terminate"
end

define arm_deployment_launch($param_site_name, $param_chargecode, $param_resource_group) do
    
  # Get the properly formatted or specified info needed for the launch
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
  
  $tags_hash = { "costcenter": $param_chargecode }
      
  # Get an access token
  call arm_common.get_access_token() retrieve $access_token
  
  # Create the resource group in which to place the deployment
  # if it already exists, no harm no foul
  $param_location = "South Central US"
  call arm_common.create_resource_group($param_location, $resource_group, $tags_hash, $access_token)
  
  # launch the ARM template
  call arm_template.launch_arm_template($resource_group, $arm_deployment_name, $param_site_name, $access_token)

end


define arm_deployment_terminate() do
  
  $param_resource_group = "default"
  
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
    
  # Get an access token
  call arm_common.get_access_token() retrieve $access_token

  # At this time, since the template is launched in its own resource group, we'll just delete the resource group on termination
  call arm_common.delete_resource_group($resource_group, $access_token)

end


define get_launch_info($param_resource_group) return $arm_deployment_name, $resource_group do
  # Use the created deployment name with out spaces
  $arm_deployment_name = gsub(@@deployment.name, " ", "")
  
  if equals?($param_resource_group, "default")
    $resource_group = $arm_deployment_name
  else
    $resource_group = $param_resource_group
  end
end