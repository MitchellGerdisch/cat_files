# Uses an ARM template to launch an ARM scale set.
#
# RightScale Account Prerequisites:
#   ARM account: An ARM account needs to be connected to the RightScale account.
#   Service Principal: A service principal needs to exist for the given ARM subscription and the password for that service principal must be available.
#   The following CREDENTIALS need to be defined in the RightScale account. (Cloud Management: Design -> Credentials)
#     RS_ARM_DOMAIN_NAME: The domain name for the ARM account connected to the RightScale account. This will be the first part of the onmicrosoft.com AD domain name.
#     RS_ARM_APPLICATION_ID: The "APP ID" for the Service Principal being used.
#     RS_ARM_APPLICATION_PASSWORD: The password created for the Service Principal being used.
#     RS_ARM_SUBSCRIPTION_ID: The subscription ID for the ARM account connected to the given RightScale account. Can be found in Settings -> Clouds -> select an ARM cloud

# TO-DOs:
# Retrieve and show the scaling set VMs' NAT ports and IP addresses.
#   Need to grab the NAT info from the scaling set's load balancer which will have the resource group name.
# Support AWS and VMware launches
#   AWS: Use RS ServerArrays or AWS autoscaling groups.
#   VMware: Use RS ServerArrays


name 'Launch Linux ARM Scale Set'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/azure.png)

Launch Linux ARM scale set"
long_description "Uses an ARM template to launch an App scale set of Linux servers."


import "arm/api_common"
import "arm/api_template"
import "arm/linux/template", as: "template"
import "general/functions"

# User launch time inputs
parameter "param_environment" do
  category "User Inputs"
  label "Environment" 
  type "string" 
  description "Cloud Environment" 
  default "Azure"
  allowed_values "Azure", "AWS", "VMware"
end

parameter "param_scaleset_name" do
  category "User Inputs"
  label "Scale Set Name" 
  type "string" 
  description "Name of Scale Set." 
  allowed_pattern '^[a-zA-Z]+[a-zA-Z0-9]*$'
  constraint_description "Must start with a letter and then can be any combination of letters numerals."
end

parameter "param_instance_type" do
  category "User Inputs"
  label "Instance Type" 
  type "string" 
  description "Instance type to use for scale set VMs" 
  default "Standard_A1"
  allowed_values "Standard_A1", "Standard_A2"
end

parameter "param_ubuntu_version" do
  category "User Inputs"
  label "Ubuntu Version" 
  type "string" 
  description "Version of Unbuntu to use for scale set VMs." 
  default "14.04.4-LTS"
  allowed_values "15.10", "14.04.4-LTS"
end

parameter "param_instance_count" do
  category "User Inputs"
  label "Number of Instances" 
  type "number" 
  description "Initial number of instances in the Scale Set." 
  default 2
  min_value 1
  max_value 8
end

parameter "param_server_username" do
  category "User Inputs"
  label "Server Username" 
  type "string" 
  description "Username to configure on the scale set servers." 
  default "ubuntu"
  allowed_pattern '^[a-zA-Z]+[a-zA-Z0-9\_]*$'
  constraint_description "Must start with a letter and then can be any combination of letters, numerals or \"_\""
end

parameter "param_server_password" do
  category "User Inputs"
  label "Server Password" 
  type "string" 
  description "Password to configure on the scale set servers." 
  allowed_pattern '^(?:(?=.*[a-z])(?:(?=.*[A-Z])(?=.*[\d\W])|(?=.*\W)(?=.*\d))|(?=.*\W)(?=.*[A-Z])(?=.*\d)).{6,72}$'
  constraint_description "Must be 6-72 characters and have at least 3 of: uppercase, lowercase, numeral, special character."
  no_echo true
end

# Outputs

# Operations
operation "launch" do 
  description "Launch the deployment based on ARM template."
  definition "arm_deployment_launch"
  
end

operation "terminate" do 
  description "Terminate the deployment"
  definition "arm_deployment_terminate"
end

define arm_deployment_launch($param_environment, $param_instance_type, $param_ubuntu_version, $param_scaleset_name, $param_instance_count, $param_server_username, $param_server_password) do
  $param_resource_group = "default"
  # Get the properly formatted or specified info needed for the launch
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
  
  # Get an access token
  call api_common.get_access_token() retrieve $access_token
  
  # Create the resource group in which to place the deployment
  # if it already exists, no harm no foul
  $param_location = "South Central US"
  call api_common.create_resource_group($param_location, $resource_group, $tags_hash, $access_token)
  
  $refresh_token = "7227970e65fbb300da99e7d3653015f1e67fe491"
  $uca_name = "UCA AzureRM"
  $servertemplate_href = "/api/server_templates/391055003"  
  $deployment_href = @@deployment.href
  
  # Currently I'm using in-line template in the request. For one I couldn't get it to work with the stored template approach and didn't want to spend too much time figuring out why.
  # Also, this does let me tinker a bit with the values based on user inputs.
  # However, the right answer is to store the main body of the template somewhere and link to it (i.e. use templateLink in the body) and only use in-line specification for the parameters 
  call template.build_arm_template_launch_body($refresh_token, $uca_name, $servertemplate_href, $deployment_href, $param_instance_type, $param_ubuntu_version, $param_scaleset_name, $param_instance_count, $param_server_username, $param_server_password) retrieve $arm_template_launch_body

  # launch the ARM template
  call api_template.launch_arm_template($arm_template_launch_body, $resource_group, $arm_deployment_name, $access_token)
  
  # At this point we wait for the given number of servers to be operational and terminate the rest since
  # there may be servers that were launched by ARM before scaling back that tried to RL enable.

  
  # Delete the extras
  call cleanup_servers($param_instance_count)

end


define arm_deployment_terminate() do
  
  # Terminate the servers in the deployment before telling ARM to terminate the stuff.
  call cleanup_servers(0)  # we don't want any servers left
  
  $param_resource_group = "default"
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
    
  # Get an access token
  call api_common.get_access_token() retrieve $access_token

  # At this time, since the template is launched in its own resource group, we'll just delete the resource group on termination
  call api_common.delete_resource_group($resource_group, $access_token)

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


# Remove any extra servers that may have come into existence due to ARM launching more instances than needed.
define cleanup_servers($target_instance_count) do
   
  # Might have to wait a bit for the servers to reach a "keeper" state.
  # So loop through looking until enough keepers are found.
  @servers_to_remove = rs_cm.servers.empty()  # initialize
  $num_keepers_found = 0
  while $num_keepers_found < to_n($target_instance_count) do
    @all_servers = @@deployment.servers()
    @servers_to_remove = @all_servers  # start by assuming we'll remove all
    $num_keepers_found = 0
    foreach @server in @all_servers do
      if @server.state == "operational" || @server.state == "stranded"
        if contains?(@servers_to_remove, @server) # get it out of there
          @servers_to_remove = @servers_to_remove - @server
          $num_keepers_found = $num_keepers_found + 1
        end
      end
    end
  end
  
  # Terminate and delete the unwanted servers
  @operational_servers = select(@servers_to_remove, {state: "operational"})
  @stranded_servers = select(@servers_to_remove, {state: "stranded"})
  @provisioned_servers = select(@servers_to_remove, {state: "provisioned"})
  @booting_servers = select(@servers_to_remove, {state: "booting"})
  @terminatable_servers = @operational_servers + @stranded_servers + @provisioned_servers + @booting_servers
  sub on_error: skip do  # skip on_error since sometimes it gets mad about stuff that will not matter in a minute when the server is destroyed.
    @terminatable_servers.current_instance().terminate()
  end
  
  sleep_until(all?(@servers_to_remove.state[], "inactive"))

  @servers_to_remove.destroy()

end
