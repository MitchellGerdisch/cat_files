# Uses an ARM template to launch a web app service + SQL server stack.
# 
# RightScale Account Prerequisites:
#   ARM account: An ARM account needs to be connected to the RightScale account.
#   Service Principal: A service principal needs to exist for the given ARM subscription and the password for that service principal must be available.
#   The following CREDENTIALS need to be defined in the RightScale account. (Cloud Management: Design -> Credentials)
#     ARM_DOMAIN_NAME: The domain name for the ARM account connected to the RightScale account. This will be the first part of the onmicrosoft.com AD domain name.
#     ARM_PFT_APPLICATION_ID: The "APP ID" for the Service Principal being used.
#     ARM_PFT_APPLICATION_PASSWORD: The password created for the Service Principal being used.
#     ARM_PFT_SUBSCRIPTION_ID: The subscription ID for the ARM account connected to the given RightScale account. Can be found in Settings -> Clouds -> select an ARM cloud

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

output "output_website_link" do
  label "Web App Service Link"
  category "Application Information"
  description "Link to the web site app service."
end

output "output_resource_group" do
  label "Resource Group"
  category "Deployment Information"
  description "The ARM resource group in which the application was deployed."
end

output "output_db_server_name" do
  label "SQL DB Server"
  category "Deployment Information"
  description "The SQL DB server name."
end

output "output_db_name" do
  label "SQL DB Name"
  category "Deployment Information"
  description "The SQL database name."
end

# Operations
operation "launch" do 
  description "Launch the deployment based on ARM template."
  definition "arm_deployment_launch"
  
  output_mappings do {
    $output_resource_group => $resource_group, 
    $output_website_link => join(["http://",$website_name, ".azurewebsites.net"]),
    $output_db_server_name => join([$db_server_name, ".database.windows.net"]),
    $output_db_name => $db_name,
  } end
end

operation "terminate" do 
  description "Terminate the deployment"
  definition "arm_deployment_terminate"
end

define arm_deployment_launch($param_chargecode, $param_resource_group) return $resource_group, $website_name, $db_server_name, $db_name, $subscription_id do
    
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
  call arm_template.launch_arm_template($resource_group, $arm_deployment_name, $access_token) retrieve $website_name, $db_server_name, $db_name
  
  call arm_common.get_subscription_id() retrieve $subscription_id

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