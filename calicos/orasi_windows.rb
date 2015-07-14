name "Order Up Some Windows Servers"
rs_ca_ver 20131202
short_description "
Deploys 1 or more Windows Servers in Azure.
"


parameter "cloud" do
  type "string"
  label "Cloud"
  category "User Inputs"
  allowed_values "Azure East US", "Azure West US"
  default "Azure East US"
  description "The cloud to launch in"
end

parameter "param_servertype" do
  category "User Inputs"
  label "Windows Server Type"
  type "list"
  allowed_values "Windows 2008R2 Base Server",
  "Windows 2008R2 IIS Server",
  "Windows 2008R2 Server with SQL 2008",
  "Windows 2008R2 Server with SQL 2012",
  "Windows 2012 Base Server",
  "Windows 2012 IIS Server",
  "Windows 2012 Server with SQL 2012"
  default "Windows 2008R2 Base Server"
end

parameter "num_servers" do
  type "string"
  label "Number of Servers"
  category "User Inputs"
  default "2"
  allowed_pattern "^([1-9]|10)$"
  constraint_description "Must be a value between 1-10"
end

parameter "param_username" do 
  category "User Inputs"
  label "Windows Username" 
#  description "Username (will be created)."
  type "string" 
  no_echo "false"
end

parameter "param_password" do 
  category "User Inputs"
  label "Windows Password" 
  description "Minimum at least 8 characters and must contain at least one of each of the following: 
  Uppercase characters, Lowercase characters, Digits 0-9, Non alphanumeric characters [@#\$%^&+=]." 
  type "string" 
  min_length 8
  max_length 32
  # This enforces a stricter windows password complexity in that all 4 elements are required as opposed to just 3.
  allowed_pattern '(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=])'
  no_echo "true"
end

#mappings
mapping "map_mci" do {
  "Windows 2008R2 Base Server" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_v13.5.0-LTS",
    "mci_rev" => "2"
  },
  "Windows 2008R2 IIS Server" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_iis7.5_v13.5.0-LTS",
    "mci_rev" => "2"
  },
  "Windows 2008R2 Server with SQL 2012" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_sqlsvr2012_v13.5.0-LTS",
    "mci_rev" => "2"
  },
  "Windows 2008R2 Server with SQL 2008" => {
    "mci" => "RightImage_Windows_2008R2_SP1_x64_sqlsvr2k8r2_v13.5.0-LTS",
    "mci_rev" => "2"
  },
  "Windows 2012 IIS Server" => {
    "mci" => "RightImage_Windows_2012_x64_iis8_v13.5.0-LTS",
    "mci_rev" => "2"
  },
  "Windows 2012 Server with SQL 2012" => {
    "mci" => "RightImage_Windows_2012_x64_sqlsvr2012_v13.5.0-LTS",
    "mci_rev" => "2"
  },
  "Windows 2012 Base Server" => {
    "mci" => "RightImage_Windows_2012_x64_v13.5.0-LTS",
    "mci_rev" => "2"
  },
} end

#output
#generate outputs
[*1..10].each do |n|
  output "server_ip_#{n}" do
    label "Server #{n} RDP Address"
    category "General"
    description "IP for the Server"
  end
end

### resources
resource "windows_servers", type: "server_array" do
  name "Windows Servers"
  cloud $cloud
  instance_type "medium" 
  placement_group "rightscaledemoorasi2"
  multi_cloud_image find(map($map_mci, $param_servertype, "mci"))
  # NOTE: No placement group field is provided here. Instead placement groups are handled in the launch definition below.
  server_template find('Base ServerTemplate for Windows (v13.5.0-LTS)', revision: 3)
  inputs do {
    "ADMIN_ACCOUNT_NAME" => join(["text:",$param_username]),
    "ADMIN_PASSWORD" => join(["cred:CAT_WINDOWS_ADMIN_PASSWORD-",@@deployment.href]), # this credential gets created below using the user-provided password.
    "FIREWALL_OPEN_PORTS_TCP" => "text:3389",
    "SYS_WINDOWS_TZINFO" => "text:Pacific Standard Time",  
  } end
  state "enabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => $num_servers,
      "max_count"            => $num_servers
    },
    "pacing" => {
      "resize_calm_time"     => 1, 
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => "Windows Servers"
    }
  } end
end

### operations
operation "launch" do
  definition "create_servers"
  description "Launch the server(s)"
  hash = {}
  
  [*1..10].each do |n|
    hash[eval("$server_ip_#{n}")] = switch(get(n-1,$server_ips),  get(0,get(n-1,$server_ips)), "")
  end
  
  output_mappings do
    hash
  end
end

operation "terminate" do
  definition "terminate_servers"
  description "Terminate the server(s)"
end

### definitions
define create_servers(@windows_servers, $param_password) return @windows_servers,$server_ips do
  
  # Create the Admin Password credential used for the server based on the user-entered password.
  $credname = join(["CAT_WINDOWS_ADMIN_PASSWORD-",@@deployment.href])
  @task=rs.credentials.create({"name":$credname, "value": $param_password})
 
  provision(@windows_servers)
  @windows_servers.update(server_array: { state: "enabled"})

  # Get the RDP bind ports
  $bindings_array = []  # This will be an array of single-element arrays since that's what the output mapping code expects.
  foreach @windows_server in @windows_servers.current_instances() do
    @bindings = rs.clouds.get(href: @windows_server.cloud().href).ip_address_bindings(filter: ["instance_href==" + @windows_server.href])
    @binding = select(@bindings, {"private_port":3389})
    $binding_public_port = @binding.public_port
    $binding_array = []
    $binding_array << join([to_s(@windows_server.public_ip_addresses[0]), ":", $binding_public_port])
    $bindings_array << $binding_array
  end
  
  $server_ips = $bindings_array
  
end

define terminate_servers(@windows_servers) do
  
  # Delete the cred we created for the user-provided password
  $credname = join(["CAT_WINDOWS_ADMIN_PASSWORD-",@@deployment.href])
  @cred=rs.credentials.get(filter: [join(["name==",$credname])])
  @cred.destroy()
  
  # Terminate the server
  @windows_servers.update(server_array: { state: "disabled"})
  delete(@windows_servers)
end

define run_rightscript_by_name(@target, $script_name) do
  @script = rs.right_scripts.index(latest_only: true, filter: ["name==" + $script_name])
  @task = @target.multi_run_executable(right_script_href: @script.href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end
