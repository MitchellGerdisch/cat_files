name "CFT launched server with RL"
rs_ca_ver 20161221
short_description  "CFT launched server with RL enablement applied afterwards"

import "plugins/rs_aws_cft"
import "pft/err_utilities", as: "debug"
import "aws_rightlink_enablement", as: "rl_enable"

### SSH key declarations ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud "EC2 us-east-1"
end

resource "stack", type: "rs_aws_cft.stack" do
  stack_name join(["cft-", last(split(@@deployment.href, "/"))])
  template_url "https://s3-us-west-2.amazonaws.com/cloudformation-templates-us-west-2/EC2InstanceWithSecurityGroupSample.template"
  description "CFT Test"
  parameter_1_name "KeyName"
  parameter_1_value @ssh_key.name
end


operation "enable" do
  definition "post_launch"
end

define post_launch(@stack) do
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
  call rl_enable.rightlink_enable(@instance, "RightLink 10.6.0 Linux Base") 
  
end

