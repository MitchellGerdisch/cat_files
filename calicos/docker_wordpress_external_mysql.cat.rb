# TO-DO
# Add resources for SSH key and SecGroup
# Add code to set the WORDPRESS env variable to point at the PUBLIC IP of the MySQL server


name 'WordPress Container with External DB Server'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png)

WordPress Container with External DB Server"

output "wordpress_url" do
  label "WordPress Link"
  category "Output"
end

resource 'wordpress_docker_server', type: 'server' do
  name 'Docker Wordpress'
  cloud 'EC2 us-east-1'
  ssh_key_href @ssh_key
  security_group_hrefs @sec_group
  server_template find('Docker Technology Demo', revision: 2)
  inputs do {
    'COLLECTD_SERVER' => 'env:RS_SKETCHY',
    'DOCKER_ENVIRONMENT' => 'text:wordpress:
  WORDPRESS_DB_HOST: TBD 
  WORDPRESS_DB_USER: wordpressdbuser
  WORDPRESS_DB_PASSWORD: wordpressdbpassword
  WORDPRESS_DB_NAME: app_test',
    'DOCKER_PROJECT' => 'text:rightscale',
    'DOCKER_SERVICES' => 'text:wordpress:
  image: wordpress
  ports:
    - 8080:80',
    'HOSTNAME' => 'env:RS_SERVER_NAME',
    'NTP_SERVERS' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'RS_INSTANCE_UUID' => 'env:RS_INSTANCE_UUID',
    'SWAP_FILE' => 'text:/mnt/ephemeral/swapfile',
    'SWAP_SIZE' => 'text:1',
  } end
end
resource 'db_server', type: 'server' do
  name 'DB Server'
  cloud 'EC2 us-east-1'
  instance_type 'm3.medium'
  multi_cloud_image find('RightImage_CentOS_6.6_x64_v14.2', revision: 24)
  ssh_key_href @ssh_key
  security_group_hrefs @sec_group
  server_template find('Database Manager for MySQL (v14.1.1)', revision: 56)
  inputs do {
    'ephemeral_lvm/logical_volume_name' => 'text:ephemeral0',
    'ephemeral_lvm/logical_volume_size' => 'text:100%VG',
    'ephemeral_lvm/mount_point' => 'text:/mnt/ephemeral',
    'ephemeral_lvm/stripe_size' => 'text:512',
    'ephemeral_lvm/volume_group_name' => 'text:vg-data',
    'rs-base/ntp/servers' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'rs-base/swap/size' => 'text:1',
    'rs-mysql/application_database_name' => 'text:app_test',
    'rs-mysql/application_password' => 'text:wordpressdbpassword',
    'rs-mysql/application_user_privileges' => 'array:["text:select","text:update","text:insert","text:create","text:delete","text:drop"]',
    'rs-mysql/application_username' => 'text:wordpressdbuser',
    'rs-mysql/backup/keep/dailies' => 'text:14',
    'rs-mysql/backup/keep/keep_last' => 'text:60',
    'rs-mysql/backup/keep/monthlies' => 'text:12',
    'rs-mysql/backup/keep/weeklies' => 'text:6',
    'rs-mysql/backup/keep/yearlies' => 'text:2',
    'rs-mysql/backup/lineage' => 'text:dockerdblineage',
    'rs-mysql/bind_network_interface' => 'text:private',
    'rs-mysql/device/count' => 'text:2',
    'rs-mysql/device/destroy_on_decommission' => 'text:false',
    'rs-mysql/device/detach_timeout' => 'text:300',
    'rs-mysql/device/mount_point' => 'text:/mnt/storage',
    'rs-mysql/device/nickname' => 'text:data_storage',
    'rs-mysql/device/volume_size' => 'text:10',
    'rs-mysql/import/dump_file' => 'text:app_test.sql',
    'rs-mysql/import/repository' => 'text:git://github.com/rightscale/examples.git',
    'rs-mysql/import/revision' => 'text:unified_php',
    'rs-mysql/schedule/enable' => 'text:false',
    'rs-mysql/server_root_password' => 'text:mysqlrootpassword',
    'rs-mysql/server_usage' => 'text:dedicated',
  } end
end

### Security Group Definitions ###
resource "sec_group", type: "security_group" do
  name join(["DockerServerSecGrp-",@@deployment.href])
  description "Docker Server deployment security group."
  cloud 'EC2 us-east-1'
end

resource "sec_group_rule_http", type: "security_group_rule" do
  name "Docker deployment HTTP Rule"
  description "Allow HTTP access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "8080",
    "end_port" => "8080"
  } end
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  like @sec_group_rule_http

  name "Docker deployment SSH Rule"
  description "Allow SSH access."
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end 

resource "sec_group_rule_mysql", type: "security_group_rule" do
  like @sec_group_rule_http

  name "Docker deployment SSH Rule"
  description "Allow MySQL access."
  protocol_details do {
    "start_port" => "3306",
    "end_port" => "3306"
  } end
end 


### SSH Key ###
resource "ssh_key", type: "ssh_key" do

  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud 'EC2 us-east-1'
end


# Operations
operation 'launch' do 
  description 'Launch the application' 
  definition 'generated_launch' 
  
  output_mappings do {
    $wordpress_url => $wordpress_link
  } end
end 

define generated_launch(@wordpress_docker_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql)  return @wordpress_docker_server, @db_server, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql, $wordpress_link do 
  
  provision(@ssh_key)
  provision(@sec_group_rule_http)
  provision(@sec_group_rule_mysql)
  provision(@sec_group_rule_ssh)

  concurrent return @db_server, @wordpress_docker_server do
    provision(@db_server)
    provision(@wordpress_docker_server)
  end
  
  # configure the docker wordpress environment variables to point at the DB server
  $db_host_ip = @db_server.current_instance().public_ip_addresses[0]
  $docker_env = "wordpress:\n   WORDPRESS_DB_HOST: " + $db_host_ip + "\n   WORDPRESS_DB_USER: wordpressdbuser\n   WORDPRESS_DB_PASSWORD: wordpressdbpassword\n   WORDPRESS_DB_NAME: app_test"
  $inp = {
    'DOCKER_ENVIRONMENT' => join(["text:", $docker_env])
  } 
  @wordpress_docker_server.current_instance().multi_update_inputs(inputs: $inp) 
  
  # Rerun docker stuff to launch wordpress
  $script_name = "APP docker services compose"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href
  @tasks = @wordpress_docker_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
    
  $script_name = "APP docker services up"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href
  @tasks = @wordpress_docker_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
    
  $wordpress_server_address = @wordpress_docker_server.current_instance().public_ip_addresses[0]
  $wordpress_link = join(["http://",$wordpress_server_address,":8080"])

end