name "CFT launched server with RL"
rs_ca_ver 20161221
short_description  "CFT launched server with RL enablement applied afterwards"

import "plugins/rs_aws_cft"

import "pft/err_utilities"

output "output_ip_address" do
  label "IP Address"
end

output "ssh_key" do
  label "SSH Key"
  default_value @ssh_key.name
end

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
  output_mappings do {
    $output_ip_address => $instance_address
  } end
end

define post_launch(@stack) return $instance_address do
  call err_utilities.log("output values", to_s(@stack.OutputValue))
  
  # Find the instance attributes
  $outputs_index = 0
  $instance_id = ""
  $instance_address = ""
  $outputkeys = @stack.OutputKey
  $outputvalues = @stack.OutputValue
  foreach $outputkey in @stack.OutputKey do
    if $outputkey == "InstanceId"
      $instance_id = $outputvalues[$outputs_index]
    elsif $outputkey == "PublicIP"
      $instance_address = $outputvalues[$outputs_index]
    end
    $outputs_index = $outputs_index + 1
  end
  
  call err_utilities.log("$instance_id: "+$instance_id+"; $instance_address: "+$instance_address, "")
  
  # Now to orchestrate things to RL enable the instance
  # Process:
  #    Stop the instance
  #    Use EC2 ModifyInstanceAttribute API to install user-data that runs RL enablement script.
  #    Start the instance - it should now be a server
  #    Move the server to the CAT's deployment
  #    Stop it and remove the user-data and the start it again?
  
  # In this case I know we are in EC2 US-East-1 which means /api/clouds/1.
  # Todo: abstract this to find the right cloud based on information from the stack.
  @cloud = rs_cm.get(href: "/api/clouds/1")
  

  # Now go off and turn it into a RightScale managed server
  call rightlink_enable(@cloud, $instance_id) retrieve @server
  
  
end

define rightlink_enable(@cloud, $instance_id) return @server do
  # Find the instance
  @instance = @cloud.instances(filter: ["resource_uid=="+$instance_id])
  
  # Stop the instance
  call err_utilities.log("stopping instance", to_s(to_object(@instance)))
  @instance.stop()
  
  # Once the instance is stopped it gets a new HREF ("next instance"), 
  # so look for the instand check the state until stopped (i.e. provisioned)
  $stopped = false
  while !$stopped do 
    # sleep a bit
    sleep(15)
    # Find the instance
    @instance = @cloud.instances(filter: ["resource_uid=="+$instance_id])
    call err_utilities.log("checking if instance has stopped", to_s(to_object(@instance)))
    # Is it stopped?
    if @instance.state == "provisioned"
      $stopped = true
    end
  end
    
  # Now install userdata that runs RL enablement code
  call install_rl_installscript(@instance, "RightLink 10.6.0 Linux Base", "BornCFT_AdoptedRS")
  
  call err_utilities.log("starting instance", to_s(to_object(@instance)))
  @instance.start()
  sleep_until(@instance.state == "operational")
  
  @server = @instance.parent()
  call err_utilities.log("instance's parent server", to_s(to_object(@server)))
end

# Uses EC2 ModifyInstanceAttribute API to install user data that runs RL enablement
define install_rl_installscript(@instance, $server_template, $servername) do
  
  $instance_id = @instance.resource_uid

  call build_rl_enablement_userdata($server_template, $servername) retrieve $user_data
    
  # base64 encode the user-data since AWS requires that 
  $user_data_base64 = to_base64($user_data)  
  # Remove the newlines that to_base64() puts in the result
  $user_data_base64 = gsub($user_data_base64, "
","")
  # Replace any = with html code %3D so the URL is valid.
  $user_data_base64 = gsub($user_data_base64, /=/, "%3D")
  
  call err_utilities.log("encoded userdata", $user_data_base64)

  $url = "https://ec2.amazonaws.com/?Action=ModifyInstanceAttribute&InstanceId="+$instance_id+"&UserData.Value="+$user_data_base64+"&Version=2014-02-01"
  $signature = {
    "type":"aws",
    "access_key": cred("AWS_ACCESS_KEY_ID"),
    "secret_key": cred("AWS_SECRET_ACCESS_KEY")
    }
  $response = http_post(
    url: $url,
    signature: $signature
    )
    
   call err_utilities.log("AWS API response", to_s($response))
end

define build_rl_enablement_userdata($server_template_name, $server_name) return $user_data do
  
  $rl_enablement_cmd = 'curl -s https://rightlink.rightscale.com/rll/10/rightlink.enable.sh | sudo bash -s -- -k "'+cred("RS_REFRESH_TOKEN")+'" -t "'+$server_template_name+'" -n "'+$server_name+'" -d "'+@@deployment.name+'" -c "amazon"'

  # This sets things up so the script runs on start.
  $user_data = 'Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0
  
--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash
'+$rl_enablement_cmd+'
--//'
  

end

