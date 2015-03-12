#
# Name: HAProxy + RL10 Hello World Webservers
# 
# Description:
# Builds an HAproxy LB and a server array consisting of a set of hello world web servers.
# The hello world web servers are based on RL10.
#
# Prerequisites:
#   Load Balancer:
#     HAProxy servertemplate must be imported into the account.
#   Application Tier:
#     A modified version of the RL10 Base Linux Server servertemplate needs to be set up in the account as follows:
#       Add this rightscript to the end of the boot sequence: https://github.com/MitchellGerdisch/rightscripts/raw/master/rl10_app_server_tagging_rs-api
#       Add this rightscript after the previous rightscript in the boot sequence: 
#### NOT DONE YET .... ####


name 'LoadBalancerTest'
rs_ca_ver 20131202
short_description 'LoadBalancerTest'

# Resource definitions are based on Deployment Exporter described here:
# http://support.rightscale.com/12-Guides/Self-Service/30_Designers_Guide/05_Cloud_Application_Template_(CAT)_Design_Concepts
resource 'haproxy_server', type: 'server' do
  name 'haproxy'
  cloud 'HP Cloud'
  instance_type 'standard.small'
  security_groups 'default'
  server_template find('Load Balancer with HAProxy (v13.5.11-LTS) HP Cloud', revision: 0)
  inputs do {
    'block_device/ephemeral/file_system_type' => 'text:xfs',
    'block_device/ephemeral/vg_data_percentage' => 'text:100',
    'lb/health_check_uri' => 'text:/',
    'lb/pools' => 'text:default',
    'lb/session_stickiness' => 'text:false',
    'lb/stats_uri' => 'text:/haproxy-status',
    'lb_haproxy/abortonclose' => 'text:off',
    'lb_haproxy/algorithm' => 'text:roundrobin',
    'lb_haproxy/httpclose' => 'text:on',
    'lb_haproxy/timeout_client' => 'text:60000',
    'lb_haproxy/timeout_server' => 'text:60000',
    'logging/protocol' => 'text:udp',
    'rightscale/security_updates' => 'text:disable',
    'rightscale/timezone' => 'text:UTC',
    'sys/reconverge/interval' => 'text:5',
    'sys/swap_file' => 'text:/mnt/ephemeral/swapfile',
    'sys/swap_size' => 'text:0.5',
    'sys_firewall/enabled' => 'text:enabled',
    'sys_firewall/rule/enable' => 'text:enable',
    'sys_firewall/rule/ip_address' => 'text:any',
    'sys_firewall/rule/protocol' => 'text:tcp',
    'sys_ntp/servers' => 'text:time.rightscale.com, ec2-us-east.time.rightscale.com, ec2-us-west.time.rightscale.com',
    'web_apache/allow_override' => 'text:None',
    'web_apache/application_name' => 'text:myapp',
    'web_apache/ssl_enable' => 'text:false',
  } end
end

resource 'haproxy_public_ip_binding', type: 'ip_address_binding' do
  name 'haproxy_public_ip_address'
  cloud 'HP Cloud'
  instance @haproxy_server
  public_ip_address_href "/api/clouds/2327/ip_addresses/EHEPKQ0HVOPQT"
end

resource 'server_array_1', type: 'server_array' do
  name 'web'
  cloud 'HP Cloud'
  image 'dockerfig'
  instance_type 'standard.small'
  security_groups 'default'
  server_template find('Ubuntu 14.04 with App Server Tagging', revision: 0)
  inputs do {
    'APP_SERVER_LISTEN_IP' => 'env:PRIVATE_IP',
    'CRED' => 'text:NULL',
    'LB_POOLS' => 'text:default',
    'LB_PORT' => 'text:80',
    'RLBIN' => 'text:/usr/local/bin/rightlinklite',
    'SERVER_UUID' => 'env:RS_INSTANCE_UUID',
    'VAR' => 'text:default_string',
  } end
  state 'enabled'
  array_type 'alert'
  elasticity_params do {
    'bounds' => {
      'min_count'            => 1,
      'max_count'            => 3
    },
    'pacing' => {
      'resize_calm_time'     => 5,
      'resize_down_by'       => 1,
      'resize_up_by'         => 1
    },
    'alert_specific_params' => {
      'decision_threshold'   => 51,
      'voters_tag_predicate' => 'web'
    }
  } end
end
