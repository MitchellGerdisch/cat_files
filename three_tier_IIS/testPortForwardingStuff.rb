#
#The MIT License (MIT)
#
#Copyright (c) 2014 Bruno Ciscato, Ryan O'Leary, Mitch Gerdisch
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

# Deploys a simplex dev stack for consisting of LB, scalable (based on CPU load) IIS app server and MS SQL server.
#
# No DNS needs to be set up - it passes the information around based on real-time IP assignments.
#
# PREREQUISITES:
#   Imported Server Templates:
#     Load Balancer with HAProxy (v13.5.5-LTS), revision: 18 
#     Database Manager for Microsoft SQL Server (13.5.1-LTS), revision: 5
#     Microsoft IIS App Server (v13.5.0-LTS), revision: 3
#       Cloned and alerts configured for scaling - needed until I can figure out how to do it in CAT for the array itself.
#       Name it: Microsoft IIS App Server (v13.5.0-LTS) scaling
#       Modify it:
#         Create Alerts:
#           Grow Alert:
#             Name: Grow
#             Condition: If cpu-idle < 30
#             Vote to Grow with Tag: Tier 2 - IIS App Server
#           Shrink Alert:
#             Name: Shrink
#             Condition: If cpu-idle > 50
#             Vote to Shrink with Tag: Tier 2 - IIS App Server
#   Links to the given script calls down below in the enable operation need to be modified for the given account (I believe)
#   S3 Storage Setup
#     Create a bucket and update the mapping if necessary.
#     Store the database backup and application files:
#       Database backup file on S3 - as per tutorial using the provided DotNetNuke.bak file found here:
#           http://support.rightscale.com/@api/deki/files/6208/DotNetNuke.bak
#       Application file on S3 - as per tutorial using the provided DotNetNuke.zip file found here:
#           http://support.rightscale.com/@api/deki/files/6292/DotNetNuke.zip
#   SSH Key - see mapping for proper names or to change accordingly.
#   Security Group that is pretty wide open that covers all the VMs - see mapping for name.
#     ports: 80, 8000, 1433, 3389
#   The usual set of credentials as per the tutorial which are likely already available in the account.
#     WINDOWS_ADMIN_PASSWORD - Password used by user, Administrator to login to the windows VMs.
#     SQL_APPLICATION_USER - SQL database user with login privileges to the specified user database.
#     SQL_APPLICATION_PASSWORD - Password for the SQL database user with login privileges to the specified user database.
#     DBADMIN_PASSWORD - The password to encrypt the master key when it's created or decrypt it when opening an existing master key.
#
# DEMO NOTES:
#   Scaling:
#     Login to the App instance and download http://download.sysinternals.com/files/CPUSTRES.zip
#     Unzip file and run CPUSTRES.exe
#     Enable two threads at maximum and that should load the CPU and cause scaling.


name "IIS-SQL Dev Stack - port forwarding test"
rs_ca_ver 20131202
short_description "![Windows](http://www.cscopestudios.com/images/winhosting.jpg)
Builds an HAproxy-IIS-MS_SQL 3-tier website architecture in the cloud using RightScale\'s ServerTemplates and a Cloud Application Template."

##############
# PARAMETERS #
##############

parameter "param_location" do 
  category "Deployment Options"
  label "Cloud" 
  type "string" 
  description "Cloud to deploy in." 
  allowed_values "AWS-Australia", "AWS-Brazil", "AWS-Japan", "AWS-USA", "Azure-Netherlands", "Azure-Singapore", "Azure-USA"
  default "AWS-USA"
end

parameter "param_performance" do 
  category "Deployment Options"
  label "Performance profile" 
  type "string" 
  description "Compute and RAM" 
  allowed_values "low", "medium", "high"
  default "low"
end

parameter "param_data_file" do 
  category "S3 info"
  label "DB initial file" 
  type "string" 
  description "Initial file to use for DB" 
  allowed_pattern "[a-z0-9][a-z0-9-_.]*"
  default "DotNetNuke.bak"
end

parameter "array_min_size" do
  category "Application Server Array"
  label "Array Minimum Size"
  type "number"
  description "Minimum number of servers in the array"
  default "1"
end

parameter "array_max_size" do
  category "Application Server Array"
  label "Array Maximum Size"
  type "number"
  description "Maximum number of servers in the array"
  default "5"
end


##############
# MAPPINGS   #
##############

mapping "map_instance_type" do {
  "AWS" => {
    "low" => "c3.large",  
    "medium" => "c3.xlarge", # 4 CPUs x 7GB
    "high" => "c3.2xlarge", # 8 CPUs x 15GB
  },
  "RS" => {
    # These choices are driven by what is configured for RS London cloud in RS.
    "low" => "4GB Standard Instance", # 2 CPUs x 4GB
    "medium" => "8GB Standard Instance", # 4CPUs  x 8GB
    "high" => "15GB Standard Instance", # 6 CPUs x 15GB
  },
  "Azure" => {
    "low" => "medium", # 2 CPUs x 3.5GB
    "medium" => "large", # 4 CPUs x 7GB
    "high" => "extra large", # 8CPUs x 15GB
  },
}
end

mapping "map_cloud" do {
  "AWS-Australia" => {
    "provider" => "AWS",
    "cloud" => "ap-southeast-2",
  },
  "AWS-Brazil" => {
    "provider" => "AWS",
    "cloud" => "sa-east-1",
  },
  "Azure-Netherlands" => {
    "provider" => "Azure",
    "cloud" => "Azure West Europe",
  },
  "AWS-Japan" => {
    "provider" => "AWS",
    "cloud" => "ap-northeast-1",
  },
  "Azure-Singapore" => {
    "provider" => "Azure",
    "cloud" => "Azure Southeast Asia",
  },
  "AWS-USA" => {
    "provider" => "AWS",
    "cloud" => "us-west-1",
  },
  "Azure-USA" => {   
    "provider" => "Azure",
    "cloud" => "Azure East US",
  },
}
end

# TO-DO: Get account info from the environment and use the mapping accordingly.
# REAL TO-DO: Once API support is avaiable in CATs, create the security groups, etc in real-time.
# map($map_current_account, 'current_account_name', 'current_account')
# _CSE Sandbox is replacd by the Ant build file with the applicable account name based on build target.
mapping "map_current_account" do {
  "current_account_name" => {
    "current_account" => "Hybrid Cloud",
  },
}
end

mapping "map_account" do {
  "CSE Sandbox" => {
    "security_group" => "CE_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "consumers-energy",
    "restore_db_script_href" => "524831004",
    "create_db_login_script_href" => "524829004",
    "restart_iis_script_href" => "524965004",
  },
  "Hybrid Cloud" => {
    "security_group" => "IIS_3tier_default_SecGrp",
    "ssh_key" => "default",
    "s3_bucket" => "iis-3tier",
    "restore_db_script_href" => "493424003",
    "create_db_login_script_href" => "493420003",
    "restart_iis_script_href" => "527791003",
  },
}
end


##############
# CONDITIONS #
##############

# Checks if being deployed in AWS.
# This is used to decide whether or not to pass an SSH key and security group when creating the servers.
condition "inAWS" do
  equals?(map($map_cloud, $param_location,"provider"), "AWS")
end


##############
# OUTPUTS    #
##############

output "end2end_test" do
  label "End to End Test" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address])
  description "Verifies access through LB #1 to App server and App server access to the DB server."
end

output "haproxy_status" do
  label "Load Balancer Status Page" 
  category "Connect"
  default_value join(["http://", @lb_1.public_ip_address, "/haproxy-status"])
  description "Accesses Load Balancer status page"
end

#output "port_forward" do
#  label "port forwarding info" 
#  category "Connect"
#  default_value join([ "private port: ", @lb_1.public_ip_address.private_port, "; public port: ", @lb_1.public_ip_address.public_port ])
#  description "Port info"
#end

##############
# RESOURCES  #
##############

resource "lb_1", type: "server" do
  name "Tier 1 - LB 1"
  cloud map( $map_cloud, $param_location, "cloud" )
  instance_type  map( $map_instance_type, map( $map_cloud, $param_location,"provider"), $param_performance)
  server_template find("Load Balancer with HAProxy (v13.5.5-LTS)", revision: 18)
  inputs do {
    "lb/session_stickiness" => "text:false",   
  } end
end

