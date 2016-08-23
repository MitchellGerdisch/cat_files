# Launches an IaaS server and a PaaS SQL service in ARM.


name 'IaaS and PaaS ARM CAT'
rs_ca_ver 20160622
short_description "Launches Linux IaaS server and SQL PaaS Service"

import "common/functions"
import "plugin/arm_common"
import "plugin/arm_sql"


# User launch time inputs
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in."  # Picked some at random, any list is possible.
  allowed_values "South Central US", "East US 2", "Central US", "North Central US"
  default "South Central US"
end

parameter "param_costcenter" do 
  category "User Inputs"
  label "Cost Center" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
end

# Outputs
output "ssh_link" do
  label "Linux Server SSH"
  category "Output"
  description "Use this string to access your server."
end

output "output_sqlserver" do
  label "SQL Server"
  category "Output"
  description "SQL Server access."
end

### Network Definitions ###
resource "arm_network", type: "network" do
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud $param_location
  cidr_block "192.168.164.0/24"
end

### Server Definition ###
resource "server", type: "server" do
  name join(['Linux Server-',last(split(@@deployment.href,"/"))])
  cloud $param_location
  network @arm_network
  subnets find("default", network_href: @arm_network)
  instance_type "D1"
  server_template_href find("RightLink 10.5.1 Linux Base", revision: 69)
  multi_cloud_image_href find("Ubuntu_14.04_x64", revision: 49)
end

# Operations
operation "launch" do 
  description "Launch the stack"
  definition "pre_auto_launch"
end

operation "enable" do
  description "Get information once the app has been launched"
  definition "enable"
  
  # Update the links provided in the outputs.
  output_mappings do {
    $ssh_link => $server_ip_address,
    $output_sqlserver => $sqldb
  } end
end

operation "terminate" do 
  description "Terminate the stack"
  definition "terminate"
end


define pre_auto_launch($param_location, $param_costcenter)  do
  
  # Check if the selected cloud is supported in this account.
  # It raises an error if not which stops execution at that point.
  call functions.checkCloudSupport($param_location, $param_location)
  
  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)
  
end


define enable($param_location, $param_costcenter) return $server_ip_address, $sqldb do
  
  # Some finishing work on the server.
  call tag_it($param_costcenter)
  
  call functions.get_server_ssh_link(false, false, true) retrieve $server_ip_address
  
  ### Build the SQL service ###
  # TO-DO: Use Cloud Service Plugins
  
  # Get an access token
  call arm_api.get_access_token() retrieve $access_token

  # Create the SQL server in the resource group that was created for the server launch
  $resource_group_name = gsub(@@deployment.name, " ", "")
  # We'll use the deployment ID as a way of identifying the resources
  call functions.getDeploymentId() retrieve $deployment_id 
  $sqlsrvr_name = "sqlsrvr-"+$deployment_id
  $sqldb_name = "sqldb-"+$deployment_id
  
  # Tag the sql service in ARM with the same costcenter tag
  $tags_hash = { "costcenter": $param_costcenter }
    
  # First need to create the sql server - that's how ARM rolls.
  call arm_api.create_sql_server($access_token, $resource_group_name, $sqlsrvr_name, $param_location, $tags_hash) retrieve $sqlserver

  # Create the SQL DB on the SQL server
  call arm_sql.create_sql_db($access_token, $resource_group_name, $sqlsrvr_name, $sqldb_name, $param_location, $tags_hash) retrieve $sqldb

  
end


define terminate(@server) do
  
  call functions.getDeploymentId() retrieve $deployment_id 
  $sqlsrvr_name = "sqlsrvr-"+$deployment_id
  $sqldb_name = "sqldb-"+$deployment_id
  $resource_group_name = gsub(@@deployment.name, " ", "")
  
  # Get an access token
  call arm_api.get_access_token() retrieve $access_token
   
  # Terminate the SQL DB on the SQL server
  call arm_sql.terminate_sql_db($access_token, $resource_group_name, $sqlsrvr_name, $sqldb_name)

  # Terminate the SQL server
  call arm_sql.terminate_sql_server($access_token, $resource_group_name, $sqlsrvr_name)

  delete(@server)

end

define tag_it($param_costcenter) do
    # Tag the servers with the selected project cost center ID.
    $tags=[join(["costcenter:id=",$param_costcenter])]
    rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
end

