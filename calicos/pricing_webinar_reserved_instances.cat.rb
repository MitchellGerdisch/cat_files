# CAT for a pricing webinar
# Focus: Reserved Instances
#
# Functional Description
# User selects general geographic region (e.g. US or Europe)
# CAT checks for reserved instances in that region and if it finds some that are available, it launches into the given datacenter.
# Launches just a single Linux box at this time.
#
# Design
#   Use Pricing API to find any reserved instances for the given account.
#     curl -sG https://pricing.rightscale.com/api/prices -H X-Api-Version:1.0 -H Content-Type:application/json -b cookies.txt -d filter='{"cloud_href":["/api/clouds/6"],"account_href":["/api/accounts/30601"],"purchase_option_type":["reserved_instance"]}'
#   For each datacenter in which you have reserved instances, 
#     Use CA API to find any running instances of the given type in that datacenter and see if there is any RI capacity available.
#   Launch in the data center with the least number of the given type since that will have the best chance of using RI in the future (theoretically)
#   
# Inputs
#   Geographical region
#   CPU/RAM requirements?
# 
# Outputs
#   Number of RIs found and type and where
#     Might be difficult to make this variable - so may have to hard-code the regions/datacenters
#   Selected region and datacenter and type
#
# CAVEATS
#   RIs are actually managed at the consolidated billing level but this CAT will assume the given RS account is not consolidated with any other.

# Required prolog
name 'Efficient Reserved Instance Usage'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/reserved-sign1.jpg)

Finds any available Reserved Instances and launches into datacenter with most headroom."

###########
# Mappings
###########
# Mapping and abstraction of cloud-related items.
mapping "map_cloud" do {
  "AWS" => {
    "cloud_provider" => "Amazon Web Services",
    "cloud_type" => "amazon",
    "zone" => null, # We don't care which az AWS decides to use.
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key",
    "pg" => null,
    "mci_mapping" => "Public"
  }
} end

mapping "map_st" do {
  "linux_server" => {
    "name" => "Base ServerTemplate for Linux (RSB) (v14.1.1)",
    "rev" => "18"
  }
} end

mapping "map_mci" do {
  "Public" => { # all other clouds
    "Ubuntu_mci" => "RightImage_Ubuntu_14.04_x64_v14.2_HVM_EBS",
    "Ubuntu_mci_rev" => "6"
  }
} end

############################
# OUTPUTS                  #
############################
output "output_region" do
  label "Region" 
  category "Reserved Instance Info"
end

output "output_datacenter" do
  label "Datacenter" 
  category "Reserved Instance Info"
end

output "output_instance_type" do
  label "Instance Type" 
  category "Reserved Instance Info"
end

output "output_num_res_instances" do
  label "Number of Reserved Instances" 
  category "Reserved Instance Info"
end

output "output_num_running_instances" do
  label "Number of Running Instances" 
  category "Reserved Instance Info"
end

############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###
resource "linux_server", type: "server" do
  name 'Linux Server'
  network @vpc_network
  subnets @vpc_subnet
  ssh_key_href @ssh_key
  security_group_hrefs @sec_group
  server_template_href find(map($map_st, "linux_server", "name"), revision: map($map_st, "linux_server", "rev"))
  multi_cloud_image_href find(map($map_mci, "Public", "Ubuntu_mci"), revision: map($map_mci, "Public", "Ubuntu_mci_rev"))
  inputs do {
    "SECURITY_UPDATES" => "text:enable" # Enable security updates
  } end
end

### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  name join(["sg_", last(split(@@deployment.href,"/"))])
  description "Linux Server security group."
  network @vpc_network
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

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
end

### Network Definitions ###
resource "vpc_network", type: "network" do
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cidr_block "192.168.164.0/24"
end

resource "vpc_subnet", type: "subnet" do
  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  network_href @vpc_network
  cidr_block "192.168.164.0/28"
end

resource "vpc_igw", type: "network_gateway" do
  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  type "internet"
  network @vpc_network
end

resource "vpc_route_table", type: "route_table" do
  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
  network @vpc_network
end

# This route is needed to allow the server to be able to talk back to RightScale.
# For a production environment you would probably want to limit the outbound route to just RightScale CIDRs and required ports.
# But for a demo CAT, this is fine. :)
resource "vpc_route", type: "route" do
  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
  destination_cidr_block "0.0.0.0/0" 
  next_hop_network_gateway @vpc_igw
  route_table @vpc_route_table
end

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
  description "Launch the app." 
  definition "launch_servers" 
  output_mappings do {
    $output_region => $chosen_region_name,
    $output_datacenter => $chosen_datacenter_name,
    $output_instance_type => $chosen_instance_type_name,  
    $output_num_res_instances => $number_res_instances,
    $output_num_running_instances => $number_running_instances
  } end
end

operation "terminate" do 
  description "Clean up"
  definition "terminate"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
define launch_servers(@linux_server, @ssh_key, @sec_group, @sec_group_rule_ssh, @vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, $map_st) return @linux_server, @sec_group, @ssh_key, @vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, $chosen_region_name, $chosen_datacenter_name, $chosen_instance_type_name, $number_res_instances, $number_running_instances do

  # Find and import the server template - just in case it hasn't been imported to the account already
  call importServerTemplate($map_st)
  
  # Use the pricing API to get some numbers
  
  # For now we are using the single account we are in.
  # Reserved instances accounting at AWS actually crosses all accounts in an consolidated billing account.
  # So accounting for multiple accounts would be needed and why the parameter to the find_reserved_instances() takes an array.
  call find_account_number() retrieve $rs_account_number
  call find_reserved_instances([$rs_account_number]) retrieve $res_instances
#  call audit_log("reserved instances hash", to_s($res_instances))
  
  # Now see what if anything is out there running using the found reserved instance types
  $where_to_launch = {}
  $running_reserved_delta = 100000
  foreach $res_instance in $res_instances do
    
    # Gather up info from the pricing API call
    $instance_type_name = $res_instance["priceable_resource"]["name"]
    $cloud_href = $res_instance["purchase_option"]["cloud_href"]
    $datacenter_name = $res_instance["purchase_option"]["datacenter_name"]
    $num_reserved_instances = $res_instance["purchase_option"]["instance_count"]
    
    # Use CM API to get some additional info
    @cloud = rs.clouds.get(href: $cloud_href)
    $datacenter_href = @cloud.datacenters(filter: [join(["name==",$datacenter_name])]).href
    $instance_type_href = @cloud.instance_types(filter: [join(["name==",$instance_type_name])]).href

    # See how many instances of the given type are currently running in the given data center
    call how_many_running_instances_of_type(@cloud, $instance_type_href, $datacenter_href) retrieve $num_running_instances_of_type
    call audit_log(join(["number of running instances of type: ", to_s($num_running_instances_of_type)]),"")

    # The data center with the smallest delta between running and reserved instance 
    # (i.e. the most headroom of reserved instances) wins
    if ($num_running_instances_of_type - $num_reserved_instances) < $running_reserved_delta
      $running_reserved_delta = $num_running_instances_of_type - $num_reserved_instances
      $where_to_launch["cloud_name"] = @cloud.name
      $where_to_launch["cloud_href"] = $cloud_href
      $where_to_launch["datacenter_name"] = $datacenter_name
      $where_to_launch["datacenter_href"] = $datacenter_href
      $where_to_launch["instance_type_name"] = $instance_type_name
      $where_to_launch["instance_type_href"] = $instance_type_href
      $where_to_launch["num_reserved_instances"] = $num_reserved_instances
      $where_to_launch["num_running_instances_of_type"] = $num_running_instances_of_type
    end
  end
  
  call audit_log("where to launch hash", to_s($where_to_launch))
    
  
  
  # Provision the resources 
    
  # modify resources with the selected cloud
  $resource_hash = to_object(@vpc_network)
  $resource_hash["fields"]["cloud_href"] = $where_to_launch["cloud_href"]
  @vpc_network = $resource_hash
  
  $resource_hash = to_object(@vpc_subnet)
  $resource_hash["fields"]["cloud_href"] = $where_to_launch["cloud_href"]
  $resource_hash["fields"]["datacenter_href"] = $where_to_launch["datacenter_href"]
  @vpc_subnet = $resource_hash
  
  $resource_hash = to_object(@vpc_igw)
  $resource_hash["fields"]["cloud_href"] = $where_to_launch["cloud_href"]
  @vpc_igw = $resource_hash
  
  $resource_hash = to_object(@vpc_route_table)
  $resource_hash["fields"]["cloud_href"] = $where_to_launch["cloud_href"]
  @vpc_route_table = $resource_hash
  
  $resource_hash = to_object(@ssh_key)
  $resource_hash["fields"]["cloud_href"] = $where_to_launch["cloud_href"]
  @ssh_key = $resource_hash
  
  $resource_hash = to_object(@sec_group)
  $resource_hash["fields"]["cloud_href"] = $where_to_launch["cloud_href"]
  @sec_group = $resource_hash   
  
  $server_hash = to_object(@linux_server)
  $server_hash["fields"]["cloud_href"] = $where_to_launch["cloud_href"]
  $server_hash["fields"]["datacenter_href"] = $where_to_launch["datacenter_href"]
  $server_hash["fields"]["instance_type_href"] = $where_to_launch["instance_type_href"]
  @linux_server = $server_hash  

  
  provision(@vpc_network)
  
  concurrent return @vpc_subnet, @vpc_igw, @vpc_route_table  do
    provision(@vpc_subnet)
    provision(@vpc_igw)
    provision(@vpc_route_table)    
  end
  
  concurrent return @vpc_route, @sec_group, @sec_group_rule_ssh, @ssh_key do
    provision(@vpc_route)
    # The provision of the rule will automatically provision the group so it needs to be returned outside 
    # of this concurrent operation but not explicitly provisioned.
    provision(@sec_group_rule_ssh)
    provision(@ssh_key)
  end
  
  # configure the network to use the route table
  @vpc_network.update(network: {route_table_href: to_s(@vpc_route_table.href)})

  # Launch the server
  provision(@linux_server)

  $chosen_region_name = $where_to_launch["cloud_name"]
  $chosen_datacenter_name = $where_to_launch["datacenter_name"]
  $chosen_instance_type_name = $where_to_launch["instance_type_name"]
  $number_res_instances = to_s($where_to_launch["num_reserved_instances"])
  $number_running_instances = to_s($where_to_launch["num_running_instances_of_type"])

end
  
define terminate(@vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @linux_server, @sec_group, @sec_group_rule_ssh, @ssh_key) do
  
  # destroy the server
  delete(@linux_server)
  
  # switch back in the default route table so that auto-terminate doesn't hit a dependency issue when cleaning up.
  # Another approach would have been to not create and associate a new route table but instead find the default route table
  # and add the outbound 0.0.0.0/0 route to it.
  
  @other_route_table = @vpc_route_table #  initializing the variable
  # Find the route tables associated with our network. 
  # There should be two: the one we created above and the default one that is created for new networks.
  @route_tables=rs.route_tables.get(filter: [join(["network_href==",to_s(@vpc_network.href)])])
  foreach @route_table in @route_tables do
    if @route_table.href != @vpc_route_table.href
      # We found the default route table
      @other_route_table = @route_table
    end
  end
  # Update the network to use the default route table 
  @vpc_network.update(network: {route_table_href: to_s(@other_route_table.href)})
  
  # The rest of the resources will be cleaned up by auto-terminate
end 


# Imports the server templates found in the given map.
# It assumes a "name" and "rev" mapping
define importServerTemplate($stmap) do
  foreach $st in keys($stmap) do
    $server_template_name = map($stmap, $st, "name")
    $server_template_rev = map($stmap, $st, "rev")
    @pub_st=rs.publications.index(filter: ["name=="+$server_template_name, "revision=="+$server_template_rev])
    @pub_st.import()
  end
end


# Calculate the cost of using the different clouds found in the $map_cloud mapping
define find_reserved_instances($rs_accounts) return $res_instances do
    
  $res_instances = []
    
  $account_href_filter = []
  foreach $account_num in $rs_accounts do
    $account_href_filter << "/api/accounts/"+to_s($account_num)
  end
  
   # pricing filters
   $filter = {
     account_href: $account_href_filter,
     resource_type: ["instance"],
   purchase_option_type: ["reserved_instance"],
   platform: ["Linux/UNIX"]
    }
      
   call audit_log(join(["pricing filter: "]), to_s($filter))
           
   # Get an array of price hashes for the given filters
   $response = http_request(
     verb: "get",
   host: "pricing.rightscale.com",
   https: true,
   href: "/api/prices",
   headers: { "X_API_VERSION": "1.0", "Content-Type": "application/json" },
   query_strings: {
     filter: to_json($filter) # For Praxis-based APIs (e.g. the pricing API) one needs to to_json() the query string values to avoid URL encoding of the null value in the filter.
       }
     )
   
   $res_instances = $response["body"]
     
end

define how_many_running_instances_of_type(@cloud, $instance_type_href, $datacenter_href) return $num_running_instances_of_type do
  # initialize my count
  $num_running_instances_of_type = 0

  # Get a list of all instances running in the given datacenter
  @running_instances = @cloud.instances(view: "extended", filter: [join(["datacenter_href==",$datacenter_href])])
  
  # Go through each instance and find any of the same instance_type as that passed in
  foreach @running_instance in @running_instances do
    $running_instance_type_href = @running_instance.instance_type().href
    if  $running_instance_type_href == $instance_type_href
      $num_running_instances_of_type = $num_running_instances_of_type + 1
    end
  end
end

### HELPER FUNCTIONS ###
define audit_log($summary, $details) do
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: $summary,
      detail: $details
    }
  )
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $rs_account_number do
  $cloud_accounts = to_object(first(rs.cloud_accounts.get()))
  @info = first(rs.cloud_accounts.get())
  $info_links = @info.links
  $rs_account_info = select($info_links, { "rel": "account" })[0]
  $rs_account_href = $rs_account_info["href"]  
    
  $rs_account_number = last(split($rs_account_href, "/"))
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "rs_account_number" , detail: to_s($rs_account_number)})
end
