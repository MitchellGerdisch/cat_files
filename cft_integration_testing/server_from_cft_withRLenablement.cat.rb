# Simple example of launching an instance via CFT and then RightLink enabling the launched instance.
# 
# REQUIRES a credential named "PFT_RS_REFRESH_TOKEN" in the account that contains a RightScale refresh token with
# permissions to RL enable a server.

name "CFT launched server with RL"
rs_ca_ver 20161221
short_description  "CFT launched server with RL enablement applied afterwards"

import "plugins/rs_aws_cft"
import "pft/err_utilities", as: "debug"
import "rl_enable/aws", as: "rl_enable"

output "output_server_public_ip" do
  label "Server Public IP Address"
end

output "output_server_private_ip" do
  label "Server Private IP Address"
end

mapping "map_server_type" do {
  "Linux" => {
    "cft" => "https://s3.amazonaws.com/rs-hybrid-demo-cfts/EC2InstanceWithSecurityGroupNonVPC.template",
#    "cft" => "https://s3-us-west-2.amazonaws.com/cloudformation-templates-us-west-2/EC2InstanceWithSecurityGroupSample.template",
    "st" => "RightLink 10.6.0 Linux Base"
  }
} end

### SSH key declarations ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud "EC2 us-east-1"
end

resource "stack", type: "rs_aws_cft.stack" do
  stack_name join(["cft-", last(split(@@deployment.href, "/"))])
  template_url map($map_server_type, "Linux", "cft")
  description "CFT Test"
  parameter_1_name "KeyName"
  parameter_1_value @ssh_key.name
end


operation "enable" do
  definition "post_launch"
  output_mappings do {
    $output_server_public_ip => $server_public_ip,
    $output_server_private_ip => $server_private_ip
  } end
end

operation "terminate" do
  definition "terminator"
end

operation "stop" do
  definition "stopper"
end

operation "start" do
  definition "starter"
end

define post_launch(@stack, $map_server_type) return $server_public_ip, $server_private_ip do
  call debug.log("output values", to_s(@stack.OutputValue))
  
  # Find the instance attributes
  $outputs_index = 0
  $instance_id = ""
  $instance_address = ""
  $outputkeys = @stack.OutputKey
  $outputvalues = @stack.OutputValue
  foreach $outputkey in @stack.OutputKey do
    if $outputkey == "InstanceId"
      $instance_id = $outputvalues[$outputs_index]
    end
    $outputs_index = $outputs_index + 1
  end
  
  call debug.log("$instance_id: "+$instance_id, "")
  
  # In this case I know we are in EC2 US-East-1 which means /api/clouds/1.
  # Todo: abstract this to find the right cloud based on information from the stack.
  @cloud = rs_cm.get(href: "/api/clouds/1")
  @instance = @cloud.instances(filter: ["resource_uid=="+$instance_id])
    
  # Wait until we actually see the instance
  while size(@instance) == 0 do
    sleep(10)
    @instance = @cloud.instances(filter: ["resource_uid=="+$instance_id])
  end

  call debug.log("@instance", to_s(to_object(@instance)))

  # Now go off and turn it into a RightScale managed server
  call rl_enable.rightlink_enable(@instance, map($map_server_type, "Linux", "st"), "PFT_RS_REFRESH_TOKEN") 
    
  @server = rs_cm.servers.get(filter: ["deployment_href=="+@@deployment.href])
  $server_public_ip = @server.current_instance().public_ip_addresses[0]
  $server_private_ip = @server.current_instance().private_ip_addresses[0]

  # Stop the CAT after 5 minutes.
  $time = now() + 300
  rs_ss.scheduled_actions.create(
    execution_id: @@execution.id,
    action: "stop",
    first_occurrence: $time
  )
  
end

define terminator() do
  # Concurrently terminate all the servers
  concurrent foreach @server in @@deployment.servers() do
    delete(@server)
  end
end

define stopper() do
  @instances = @@deployment.servers().current_instance()
  call rl_enable.stop_instances(@instances) retrieve @stopped_instances
end

define starter() do
  @instances = @@deployment.servers().current_instance()
  call rl_enable.start_instances(@instances) 
  
  # Stop the CAT after 5 minutes.
  $time = now() + 300
  rs_ss.scheduled_actions.create(
    execution_id: @@execution.id,
    action: "stop",
    first_occurrence: $time
  )
end

