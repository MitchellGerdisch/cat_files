# CAT that will fail to show error handling.
# The failure will be because the Google image pointed to by the 10.6.0 Linux Base ServerTemplate is deprecated.
#
# Prerequisites:
# Import the "RightLink 10.6.0 Linux Base" ServerTemplate


# Required prolog
name 'Provision Errorhandling Example'
rs_ca_ver 20161221
short_description "Shows error handling example."


output_set "output_server_ip_public" do
  label "Server IP"
  category "Output"
  description "IP address for the server."
  default_value @linux_server.public_ip_address
end

mapping "map_cloud" do {
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "pg" => null,
    "network" => null,
    "subnet" => null,
    "mci_mapping" => "Public",
  }
} end

resource "linux_server", type: "server" do
  name join(['linux-',last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "Google", "cloud")
  datacenter map($map_cloud, "Google", "zone")
  network find(map($map_cloud, "Google", "network"))
  subnets find(map($map_cloud, "Google", "subnet"))
  instance_type map($map_cloud, "Google", "instance_type")
  ssh_key_href map($map_cloud, "Google", "ssh_key")
  placement_group_href map($map_cloud, "Google", "pg")
  security_group_hrefs map($map_cloud, "Google", "sg")  
  server_template_href find("RightLink 10.6.0 Linux Base")
end

resource "sec_group", type: "security_group" do
  name join(["SecGrp-",last(split(@@deployment.href,"/"))])
  description "Server security group."
  cloud map( $map_cloud, "Google", "cloud" )
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name join(["SshRule-",last(split(@@deployment.href,"/"))])
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


####################
# OPERATIONS       #
####################
operation "launch" do 
  description "Launch the server"
  definition "launch_server"
end

##########################
# DEFINITIONS (i.e. RCL) #
##########################

# Import and set up what is needed for the server and then launch it.
define launch_server(@linux_server, @sec_group, @sec_group_rule_ssh) return @linux_server, @sec_group, @sec_group_rule_ssh do
  
  provision(@sec_group_rule_ssh)
  
  # Error handling documentation:
  # http://docs.rightscale.com/ss/reference/rcl/v2/index.html#attributes-and-error-handling
  
  $provision_attempts = 0
  sub on_error: handle_provision_error($provision_attempts) do
    $provision_attempts = $provision_attempts + 1
    provision(@linux_server)
  end


end

define handle_provision_error($provision_attempts) do
  $num_tries = 2
  call log("PROVISION - ERROR TYPE: "+$_error["type"], to_s($_error))
  if $provision_attempts < $num_tries
    $_error_behavior = "retry"
    sleep(60)
  end
end


# create an audit entry 
define log($summary, $details) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: $summary , detail: $details})
end


