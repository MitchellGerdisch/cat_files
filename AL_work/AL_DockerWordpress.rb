#
#The MIT License (MIT)
#
#Copyright (c) 2014 by Richard Shade and Mitch Gerdisch
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.


#RightScale Cloud Application Template (CAT)

# DESCRIPTION
# Deploys a Docker server and automatically installs WordPress.
# 
# PREREQUISITES
#   vSphere environment needs to have 

name 'Docker WordPress'
rs_ca_ver 20131202
short_description '![logo] (https://s3.amazonaws.com/selfservice-logos/docker.png) ![logo] (https://s3.amazonaws.com/selfservice-logos/wordpress-logo-stacked-rgb.png)'
long_description '![logo] (https://s3.amazonaws.com/selfservice-logos/docker.png) ![logo] (https://s3.amazonaws.com/selfservice-logos/wordpress-logo-stacked-rgb.png)'


resource 'dockerwp_server', type: 'server' do
  name 'Docker WordPress'
  cloud 'EC2 us-east-1'
  ssh_key 'adam.alexander'
  subnets find(resource_uid: 'subnet-7eb8e638', network_href: '/api/networks/E3118NLDQQGGH')
  security_groups 'httpandssh'
  instance_type 'c3.large'
  server_template find('Docker ServerTemplate for Linux (v14.1.0)')
  inputs do {
    'ephemeral_lvm/filesystem' => 'text:ext4',
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
  } end
end

operation 'launch' do 
  description 'Launch the application' 
  definition 'generated_launch' 
end

output "host" do
  label "hostname"
  category "Output"
  description "Hostname"
  default_value join(["http://",@dockerwp_server.private_ip_address])
end

define run_recipe(@target, $recipe_name, $recipe_inputs) do
  $attempts = 0
  sub  on_error:handle_retries($attempts) do
    $attempts = $attempts + 1
    @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: $recipe_inputs)
    sleep_until(@task.summary =~ "^(completed|failed)")
    if @task.summary =~ "failed"
      raise "Failed to run " + $recipe_name
    end
   end
end

define generated_launch(@dockerwp_server) return @dockerwp_server do
    provision(@dockerwp_server)
    call run_recipe(@dockerwp_server, "rsc_docker::wordpress", {})
end 