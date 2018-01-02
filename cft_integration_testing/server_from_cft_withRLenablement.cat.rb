name "CFT launched server with RL"
rs_ca_ver 20161221
short_description  "CFT launched server with RL enablement applied afterwards"

import "plugins/rs_aws_cft"
import "pft/err_utilities", as: "debug"
import "aws_rightlink_enablement" as "rl_enable"

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
  
  call debug.log("$instance_id: "+$instance_id+"; $instance_address: "+$instance_address, "")
  
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
  @instance = @cloud.instances(filter: ["resource_uid=="+$instance_id])

  # Now go off and turn it into a RightScale managed server
  call rl_enable.rightlink_enable(@instance) 
  
  $instance_address = @instance.public_ip_addresses[0]
end

# Orchestrate RightLink enablement of the instance.
# Once enabled, it is a "server."
define rightlink_enable(@cloud, $instance_id) return @server do
  # Find the instance
  
  # Stop the instance
  call debug.log("stopping instance", to_s(to_object(@instance)))
  @instance.stop()
  
  # Once the instance is stopped it gets a new HREF ("next instance"), 
  # so look for the instand check the state until stopped (i.e. provisioned)
  $stopped = false
  while !$stopped do 
    # sleep a bit
    sleep(15)
    # Find the instance
    @instance = @cloud.instances(filter: ["resource_uid=="+$instance_id])
    call debug.log("checking if instance has stopped", to_s(to_object(@instance)))
    # Is it stopped?
    if @instance.state == "provisioned"
      $stopped = true
    end
  end
    
  # Now install userdata that runs RL enablement code
  call install_rl_installscript(@instance, "RightLink 10.6.0 Linux Base", "BornCFT_AdoptedRS")
  
  # Once the user-data is set, start the instance so RL enablement will be run
  call debug.log("starting instance", to_s(to_object(@instance)))
  @instance.start()
  sleep_until(@instance.state == "operational")
  
  # Wait until the instance has it's parent link to find the related server object.
  sub on_error: retry do
    @server = @instance.parent()
  end
  call debug.log("instance's parent server", to_s(to_object(@server)))
end

# Uses EC2 ModifyInstanceAttribute API to install user data that runs RL enablement script
define install_rl_installscript(@instance, $server_template, $servername) do
  
  $instance_id = @instance.resource_uid # needed for the API URL

  # generate the user-data that runs the RL enablement script.
  call build_rl_enablement_userdata($server_template, $servername) retrieve $user_data
    
  # base64 encode the user-data since AWS requires that 
  $user_data_base64 = to_base64($user_data)  
  # Remove the newlines that to_base64() puts in the result
  $user_data_base64 = gsub($user_data_base64, "
","")
  # Replace any = with html code %3D so the URL is valid.
  $user_data_base64 = gsub($user_data_base64, /=/, "%3D")
  
  call debug.log("encoded userdata", $user_data_base64)

  # Go tell AWS to update the user-data for the instance
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
    
   call debug.log("AWS API response", to_s($response))
end

define build_rl_enablement_userdata($server_template_name, $server_name) return $user_data do
  
  # If you look at the RightScale docs, you'll see this line has a sudo before bash, but it's not used here.
  # Since cloud-init runs as root and since the sudo in there may throw the "tty" error, it's really not needed.
  $rl_enablement_cmd = 'curl -s https://rightlink.rightscale.com/rll/10/rightlink.enable.sh | bash -s -- -k "'+cred("RS_REFRESH_TOKEN")+'" -t "'+$server_template_name+'" -n "'+$server_name+'" -d "'+@@deployment.name+'" -c "amazon"'

  # This sets things up so the script runs on start.
  # Note that the RL enablement script is given a name that should ensure it runs first.
  # This is important if there are other scripts already on the server.
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
Content-Disposition: attachment; filename="aaa_rlenable.sh"

#!/bin/bash
'+$rl_enablement_cmd+'
--//'
  

end

