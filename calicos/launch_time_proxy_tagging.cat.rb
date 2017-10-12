#Copyright 2015 RightScale
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.


#RightScale Cloud Application Template (CAT)




# Required prolog
name 'Launch Time Proxy Tagging Example'
rs_ca_ver 20161221
short_description "Shows example of setting proxy tags on a server instead of relying on the tag on the MCI.
This is useful in cases where there are multiple networks being used with different proxies."

##################
# User inputs    #
##################



############################
# RESOURCE DEFINITIONS     #
############################

### Server Definition ###
resource "linux_server", type: "server" do
  name "proxy_tag_test"
  cloud "EC2 us-east-1"
  instance_type "t2.micro"
  server_template "RightLink 10.6.0 Linux Base"
end

### Operations ###
operation "launch" do 
  description "Launch the server"
  definition "launch_server"
end


### Definitions ###
define launch_server(@linux_server) do
  
  # Need to create the server resource so tags can be added to it.
  @linux_server = rs_cm.servers.create(server: to_object(@linux_server)["fields"])

  # Create and add the tags.
  # NOTE: This will overwrite any MCI proxy tags.
  $http_proxy_tag = "rs_agent:http_proxy=http://1.2.3.4:80"
  $http_proxy_user_tag = "rs_agent:http_proxy_user=cred:PROXY_USER"
  $http_proxy_password_tag = "rs_agent:http_proxy_password=cred:PROXY_PASSWORD"
  $tags = [$http_proxy_tag, $http_proxy_user_tag, $http_proxy_password_tag]
  rs_cm.tags.multi_add(resource_hrefs: [@linux_server.href], tags: $tags)

  # Now launch the server
#  provision(@linux_server)
  @linux_server.launch()
  
end

