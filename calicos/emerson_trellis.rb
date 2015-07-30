name "Launch Trellis"
rs_ca_ver 20131202
short_description "
Deploys the Trellis application (both frontend and backend servers).
"

################################
# User Inputs                  #
################################
parameter "param_location" do
  type "string"
  label "Cloud"
  category "User Inputs"
  allowed_values "AWS US-East"
  default "AWS US-East"
  description "The cloud to launch in. (The Trellis AMIs are only available in AWS US-East at this time.)"
end

parameter "param_performance" do
  type "string"
  label "System Performance Level"
  category "User Inputs"
  allowed_values "Basic", "Enhanced"
  default "Basic"
  description "The needed performance level."
end
  
################################
# Outputs returned to the user #
################################
output "output_fe_ip" do
  label "Frontend Server IP"
  category "Output"
end

output "output_be_ip" do
  label "Backend Server IP"
  category "Output"
end

################################
# Mappings                     #
################################
mapping "map_serverinfo" do {
  "Trellis Frontend" => {
    "servertemplate" => "Trellis-Frontend-RightScaleTest",
    "st_rev" => "2",
    "mci" => "Trellis-Frontend",
    "mci_rev" => "2"
  },
  "Trellis Backend" => {
    "servertemplate" => "Trellis-Backend-RightScaleTest",
    "st_rev" => "2",
    "mci" => "Trellis-Backend",
    "mci_rev" => "2"
  },
} end

mapping "map_performance" do {
  "Basic" => {
    "instance_type" => "m3.large",
  },
  "Enhanced" => {
    "instance_type" => "m3.2xlarge",
  }
} end

mapping "map_cloud" do {
  "AWS US-East" => {
    "region" => "us-east-1",
    "ssh_key" => "@ssh_key",
    "sec_group" => "@sec_group",
    "placement_group" => null,
  },
} end

################################
# Resource Declarations        #
################################

# Server Declarations
resource "frontend", type: "server" do
  name "Trellis Frontend"
  cloud map($map_cloud, $param_location, "region")
  instance_type map($map_performance, $param_performance, "instance_type")
  server_template_href find(map($map_serverinfo, "Trellis Frontend", "servertemplate"), revision: map($map_serverinfo, "Trellis Frontend", "st_rev"))
  multi_cloud_image_href find(map($map_serverinfo, "Trellis Frontend", "mci"), revision: map($map_serverinfo, "Trellis Frontend", "mci_rev"))
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  placement_group_href map($map_cloud, $param_location, "placement_group")
  security_group_hrefs map($map_cloud, $param_location, "sec_group") 
end

resource "backend", type: "server" do
  like @frontend
  name "Trellis Backend"
  server_template_href find(map($map_serverinfo, "Trellis Backend", "servertemplate"), revision: map($map_serverinfo, "Trellis Backend", "st_rev"))
  multi_cloud_image_href find(map($map_serverinfo, "Trellis Backend", "mci"), revision: map($map_serverinfo, "Trellis Backend", "mci_rev"))
end

# Security Group Definitions 
resource "sec_group", type: "security_group" do
  name join(["TrellisSecGroup-",last(split(@@deployment.href,"/"))])
  description "Trellis application security group."
  cloud map( $map_cloud, $param_location, "region" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name "Trellis SSH Rule"
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
  name join(["trellis_sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "region")
end


####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Concurrently launch the servers" 
  definition "launch_servers" 
  output_mappings do {
    $output_fe_ip => $frontend_ip,
    $output_be_ip => $backend_ip,
  } end
end

operation "start" do
  description "Start the servers"
  definition "start_servers"
  output_mappings do {
    $output_fe_ip => $frontend_ip,
    $output_be_ip => $backend_ip,
  } end
end

operation "stop" do
  description "Stop the servers"
  definition "stop_servers"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################
define launch_servers(@frontend, @backend, @ssh_key, @sec_group, @sec_group_rule_ssh)  return @frontend, @backend, @sec_group, @ssh_key, $frontend_ip, $backend_ip do 
    
  # Provision the resources
  provision(@ssh_key)
  
  # Provision the security group rules 
  provision(@sec_group_rule_ssh)
  
  # Launch the servers concurrently
  concurrent return  @frontend, @backend do 
    sub task_name:"Launch Frontend Server" do
      task_label("Launching Frontend Server")
      $fe_retries = 0 
      sub on_error: handle_retries($fe_retries) do
        $fe_retries = $fe_retries + 1
        provision(@frontend)
      end
    end
    sub task_name:"Launch Backend Server" do
      task_label("Launching Backend Server")
      $be_retries = 0 
      sub on_error: handle_retries($be_retries) do
        $be_retries = $be_retries + 1
        provision(@backend)
      end
    end
  end

  $frontend_ip = to_s(@frontend.current_instance().public_ip_addresses[0])
  $backend_ip = to_s(@backend.current_instance().public_ip_addresses[0])
end 

define start_servers(@frontend, @backend, @ssh_key, @sec_group, @sec_group_rule_ssh)  return @frontend, @backend, @sec_group, @ssh_key, $frontend_ip, $backend_ip do 
    
  # Launch the servers concurrently
  concurrent return  @frontend, @backend do 
    @frontend.current_instance().start() 
    @backend.current_instance().start() 
    sleep_until(@frontend.state == "operational" || @frontend.state == "stranded")
    sleep_until(@backend.state == "operational" || @backend.state == "stranded")
  end

  $frontend_ip = to_s(@frontend.current_instance().public_ip_addresses[0])
  $backend_ip = to_s(@backend.current_instance().public_ip_addresses[0])
end 

define stop_servers(@frontend, @backend) do 
    
  # Stop the servers concurrently
  concurrent return  @frontend, @backend do 
    @frontend.current_instance().stop() 
    @backend.current_instance().stop() 
    sleep_until(@frontend.state == "provisioned" && @backend.state == "provisioned")
  end

end 


# Helper functions
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  end
end