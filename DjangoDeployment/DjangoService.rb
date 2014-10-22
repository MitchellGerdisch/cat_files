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

# OVERVIEW:
# Deploys a simple two-tier Django-MySQL stack.
# No DNS needs to be set up - it passes the information around based on real-time IP assignments.
#
# PREREQUISITES:
#   Imported Server Templates:
#     Database Manager for MySQL 5.5 (v13.5.10-LTS), revision: 32
#     Django App Server (v13.5.5-LTS)
#   S3 Storage Setup
#     Create a bucket and update the mapping below if necessary.
#     Store the database backup and application files:
#       Database backup file on S3 - as per 3-tier tutorial using the provided http://support.rightscale.com/@api/deki/files/6241/app_test-201109010029.gz
#       Application file on S3 - as per tutorial using the provided http://support.rightscale.com/@api/deki/files/6299/phptest.tgz
#   SSH Key - see mapping for proper names or to change accordingly or just set one called "default"
#   Security Group that is pretty wide open that covers all the VMs - see mapping for name.
#     ports: 80, 8000, 3306
#   The usual set of credentials as per the tutorial which are likely already available in the account.
#     WINDOWS_ADMIN_PASSWORD - Password used by user, Administrator to login to the windows VMs.
#     SQL_APPLICATION_USER - SQL database user with login privileges to the specified user database.
#     SQL_APPLICATION_PASSWORD - Password for the SQL database user with login privileges to the specified user database.
#     DBADMIN_PASSWORD - The password to encrypt the master key when it's created or decrypt it when opening an existing master key.
#
# DEMO NOTES:
# WORK IN PROGRESS  Scaling:
#     Run scaler script ... ONCE ITS READY AND WORKING....


name 'Django Demo Stack'
rs_ca_ver 20131202
short_description 'Builds a simple Django stack consisting of a single Django App server.'

##############
# PARAMETERS #
##############

# User can select a geographical location for the server which will then pick a cloud and zone based on the mapping below.
# User can also select size parameter which is mapped to a given instance type/flavor for the selected cloud.

parameter "param_cloud" do 
  category "Deployment Options"
  label "Location" 
  type "string" 
  description "Cloud to deploy to." 
  allowed_values "AWS-US-East"
  default "AWS-US-East"
end

##############
# MAPPINGS   #
##############



mapping "map_cloud" do {
  "AWS-US-East" => {
    "provider" => "AWS",
    "cloud" => "us-east-1",
    "security_group" => 'default',
    "ssh_key" => "default",
  },
}
end


##############
# CONDITIONS #
##############
# NONE #


##############
# OUTPUTS    #
##############

output 'django_service' do
  label "Django Service" 
  category "Connect"
  default_value join(["http://", @django_server.public_ip_address])
  description "Access to the Django service."
end




##############
# RESOURCES  #
##############

#resource 'db_1', type: 'server' do
#  name 'Database'
#  cloud map( $map_cloud, $param_cloud, 'cloud' )
#  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
#  subnets map( $map_cloud, $param_cloud, 'subnet' )
#  instance_type map( $map_cloud, $param_cloud,map( $profiles, $performance, 'db_instance_type'))
#  server_template find("Database Manager for MySQL 5.5 (v13.5.10-LTS)", revision: 32)
#  security_groups map( $map_cloud, $param_cloud, 'security_group' )
#  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
#  inputs do {
#    'db/backup/lineage' => join(['text:selfservice-demo-lineage-',@@deployment.href]),
#    'db/dns/master/fqdn' => 'env:Database:PRIVATE_IP',
#    'db/dns/master/id' => 'cred:DB_THROWAWAY_HOSTNAME_ID',
#    'db/dump/container' => 'text:three-tier-scaling',
#    'db/dump/database_name' => 'text:app_test',
#    'db/dump/prefix' => 'text:app_test',
#    'db/dump/storage_account_id' => 'cred:AWS_ACCESS_KEY_ID',
#    'db/dump/storage_account_secret' => 'cred:AWS_SECRET_ACCESS_KEY',
#    'db/init_slave_at_boot' => 'text:false',
#    'db/replication/network_interface' => 'text:private',
#    'sys_dns/choice' => 'text:DNSMadeEasy',
#    'sys_dns/password' => 'cred:DNS_PASSWORD',
#    'sys_dns/user' => 'cred:DNS_USER',
#    'sys_firewall/enabled' => 'text:unmanaged',
#    } end
#end

resource 'django_server', type: 'server' do
  name 'Django App Server'
  cloud map( $map_cloud, $param_cloud, 'cloud' )
  datacenter map( $map_cloud, $param_cloud, 'datacenter' )
  subnets map( $map_cloud, $param_cloud, 'subnet' )
  instance_type 'm1.medium'
  server_template find('Django App Server (v13.5.5-LTS) apidemo')
  security_groups map( $map_cloud, $param_cloud, 'security_group' )
  ssh_key map( $map_cloud, $param_cloud, 'ssh_key' )
#  inputs do {
#    'app/database_name' => 'app_test',
#    'db/dns/master/fqdn' => 'env:Database:PRIVATE_IP',
#    'db/provider_type' => 'text:db_mysql_5.5',
#    'repo/default/provider' => 'text:s3',
#    'repo/default/repository' => $param_s3_bucket,
#    'repo/default/prefix' => 'text:phptest',
#    'repo/default/account' => 'cred:AWS_ACCESS_KEY_ID',
#    'repo/default/credential' => 'cred:AWS_SECRET_ACCESS_KEY',
#  } end
end


##############
# Operations #
##############

# executes automatically
operation "launch" do
  description "Launches all the servers concurrently"
  definition "launch_concurrent"
end

# executes automatically
operation "enable" do
  description "Do enabling stuff."
  definition "enable_application"
end 


##############
# Definitions#
##############

#
# Launch operation
#

define launch_concurrent(@django_server) return @django_server do
    task_label("Launch servers concurrently")

    # Since we want to launch these in concurrent tasks, we need to use global resources
    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
    #   to that task. Since we want to modify these particular resources, we copy them
    #   into global scope and copy them back at the end
    
    @@launch_django_server = @django_server

    # Do just the DB and LB concurrently.
    # It may be the case that the DB server needs to be operational before the App server will work properly.
    # There's a known issue in DotNetNuke where it'll throw the under construction page if the DB server we restarted after the app server connected.
    concurrent do
      sub task_name:"Launch Django Server" do
        task_label("Django Server")
        $django_retries = 0 
        sub on_error: handle_provision_error($django_retries) do
          $django_retries = $django_retries + 1
          provision(@@launch_django_server)
        end
      end
    end

    # Copy the globally-scoped resources back into the SS-scoped resources that we're returning
    @django_server = @@launch_django_server

end

define handle_provision_error($count) do
  call log("Handling provision error: " + $_error["message"])
  if $count < 5 
    $_error_behavior = 'retry'
  end
end
#
# Enable operation
#

define enable_application(@django_server) do
  task_label("Enable services.")


end
 
#
# Import DB operation
#

define import_db_dump(@db_1) do
  task_label("Import the DB dump")
  call run_recipe(@db_1, "db::do_dump_import")  
end

# Helper definition, runs a recipe on given server, waits until recipe completes or fails
# Raises an error in case of failure
define run_recipe(@target, $recipe_name) do
  @task = @target.current_instance().run_executable(recipe_name: $recipe_name, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $recipe_name
  end
end

# Helper definition, runs a script on given server, waits until script completes or fails
# Raises an error in case of failure
define run_script(@target, $right_script_href) do
  @task = @target.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

# Helper definition, runs a script on all instances in the array.
# waits until script completes or fails
# Raises an error in case of failure
define multi_run_script(@target, $right_script_href) do
  @task = @target.multi_run_executable(right_script_href: $right_script_href, inputs: {})
  sleep_until(@task.summary =~ "^(completed|failed)")
  if @task.summary =~ "failed"
    raise "Failed to run " + $right_script_href
  end
end

define log($message) do
  rs.audit_entries.create(audit_entry: {auditee_href: @@deployment.href, summary: $message})
end