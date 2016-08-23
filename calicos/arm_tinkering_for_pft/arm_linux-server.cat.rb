# DESCRIPTION
# Deploys a basic Ubuntu Linux server in ARM


# Required prolog
name 'ARM Linux Server'
rs_ca_ver 20131202
short_description "![Linux](https://s3.amazonaws.com/rs-pft/cat-logos/linux_logo.png)\n
Get a Linux Server VM in any of our supported public or private clouds"
long_description "Launches a Linux server.\n
\n
Clouds Supported: <B>AWS, Azure, AzureRM, Google, VMware</B>"

##################
# User inputs    #
##################
parameter "param_location" do 
  category "User Inputs"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS", "Azure", "AzureRM", "Google", "VMware"
  default "Google"
end

#parameter "param_servertype" do
#  category "User Inputs"
#  label "Linux Server Type"
#  type "list"
#  description "Type of Linux server to launch"
#  allowed_values "CentOS", 
#    "Ubuntu"
#  default "Ubuntu"
#end

parameter "param_instancetype" do
  category "User Inputs"
  label "Server Performance Level"
  type "list"
  description "Server performance level"
  allowed_values "standard performance",
    "high performance"
  default "standard performance"
end

parameter "param_costcenter" do 
  category "User Inputs"
  label "Cost Center" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
end

################################
# Outputs returned to the user #
################################
output "ssh_link" do
  label "SSH Link"
  category "Output"
  description "Use this string to access your server."
end

output "vmware_note" do
  condition $invSphere
  label "Deployment Note"
  category "Output"
  default_value "Your CloudApp was deployed in a VMware environment on a private network and so is not directly accessible. If you need access to the CloudApp, please contact your RightScale rep for network access."
end

#output "ssh_key_info" do
#  condition $inAzure
#  label "Link to your SSH Key"
#  category "Output"
#  description "Use this link to download your SSH private key and use it to login to the server using provided \"SSH Link\"."
#  default_value "https://my.rightscale.com/global/users/ssh#ssh"
#end


##############
# MAPPINGS   #
##############
mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "zone" => null, # We don't care which az AWS decides to use.
    "instance_type" => "m3.medium",
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "st_mapping" => "v14",
    "mci_mapping" => "Public",
    "network" => null,
    "subnets" => null
  },
  "Azure" => {   
    "cloud" => "Azure East US",
    "zone" => null,
    "instance_type" => "D1",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => "@placement_group",
    "st_mapping" => "v14",
    "mci_mapping" => "Public",
    "network" => null,
    "subnets" => null
  },
  "AzureRM" => {   
    "cloud" => "AzureRM East US",
    "zone" => null,
    "instance_type" => "D1",
    "sg" => null, 
    "ssh_key" => null,
    "pg" => null,
    "st_mapping" => "rl10",
    "mci_mapping" => "rl10",
    "network" => "@arm_network",
    "subnets" => "default"
  },
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "st_mapping" => "v14",
    "mci_mapping" => "Public",
    "network" => null,
    "subnets" => null
  },
  "VMware" => {
    "cloud" => "VMware Private Cloud",
    "zone" => "VMware_Zone_1", # launches in vSphere require a zone being specified  
    "instance_type" => "large",
    "sg" => null, 
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "st_mapping" => "v14",
    "mci_mapping" => "VMware",
    "network" => null,
    "subnets" => null
  }
}
end

mapping "map_instancetype" do {
  "standard performance" => {
    "AWS" => "m3.medium",
    "Azure" => "D1",
    "AzureRM" => "D1",
    "Google" => "n1-standard-1",
    "VMware" => "small",
  },
  "high performance" => {
    "AWS" => "m3.large",
    "Azure" => "D2",
    "AzureRM" => "D2",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end

mapping "map_st" do {
  "rl10" => {
    "name" => "RightLink 10.5.1 Linux Base",
    "rev" => "69",
  },
} end

mapping "map_mci" do {
  "rl10" => { # all other clouds
    "Ubuntu_mci" => "Ubuntu_14.04_x64",
    "Ubuntu_mci_rev" => "49"
  }
} end







##################
# Permissions    #
##################
permission "import_servertemplates" do
  actions   "rs.import"
  resources "rs.publications"
end

####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "pre_auto_launch"
end

operation "enable" do
  description "Get information once the app has been launched"
  definition "enable"
  
  # Update the links provided in the outputs.
  output_mappings do {
    $ssh_link => $server_ip_address,
  } end
end

# For ARM, we want to explicitly terminate the server before the networks are cleaned up
operation "terminate" do 
  description "Terminate the server"
  definition "arm_terminate"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
define pre_auto_launch($param_location, $map_st) do

    # Check if the selected cloud is supported in this account.
    # Since different PIB scenarios include different clouds, this check is needed.
    # It raises an error if not which stops execution at that point.
    call functions.checkCloudSupport($param_location, $param_location)
    
    # Find and import the server template - just in case it hasn't been imported to the account already
    call importServerTemplate($map_st)

end

define enable($param_costcenter) return $server_ip_address do
  
  call tag_it($param_costcenter)
  
  call functions.get_server_ssh_link(false, false, true) retrieve $server_ip_address
  
end

# In ARM I want to delete the server before auto-terminate tries to delete the networks and stuff.
define arm_terminate(@linux_server) do
  delete(@linux_server)
end

  
define tag_it($param_costcenter) do
    # Tag the servers with the selected project cost center ID.
    $tags=[join(["costcenter:id=",$param_costcenter])]
    rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
end

