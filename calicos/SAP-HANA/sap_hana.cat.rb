#
# REFERENCES:
#   CFT this CAT is based on: http://docs.aws.amazon.com/quickstart/latest/sap-hana/welcome.html
#     
# PREREQUISITES
#   SAP MCI that points at: ami-cef80ed8
#     This is a marketplace SUSE-based SAP-HANA AMI (ami-cef80ed8)
#     There is a RH version as well, but this CAT is being developed for a customer that uses the SUSE-based version.
#   SAP ST that points at the MCI.
#     Base on RL10 Base Linux ST
#     ST Boot Sequence Modified:
#       Remove NTP (not SUSE compatible code and not really needed)
#       Remove RedHat Subscription Register
#       Remove Setup Automatic Upgrade
#       

name "SAP-HANA CAT"
rs_ca_ver 20161221
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/SAP-Hana-Logo.png) 

Launch a SAP-HANA system."
long_description "Currently focused on master SAP-Hana node. Later revisions will support launching multiple workers."

import "sap_hana/security_groups"
import "sap_hana/mappings"
import "pft/parameters"

parameter "param_location" do 
  like $parameters.param_location
  allowed_values "AWS", "AzureRM"  # ARM SAP image is RHEL based image and in ARM RHEL doesn't have cloud-init so install-at-boot doesn't work
  default "AWS"
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
end

parameter "param_numservers" do
  like $parameters.param_numservers
  label "Number of Worker Nodes"
end

resource 'saphana_master', type: 'server' do
  name join(["hana_master-", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  network map($map_cloud, $param_location, "network")
  subnets map($map_cloud, $param_location, "subnets")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  server_template find('SAP-Hana Master Node', revision: 0)
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  inputs do {
    'MONITORING_METHOD' => 'text:rightlink',
  } end
end

resource "saphana_workers", type: "server", copies: $param_numservers do
  like @saphana_master
  name join(['hanaworker-',last(split(@@deployment.href,"/")), "-", copy_index()])
  server_template find('SAP-Hana Worker Node', revision: 0)
  inputs do {
    'MONITORING_METHOD' => 'text:rightlink',
  } end
end

### SSH key declarations ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
end

mapping "map_cloud" do 
  like $mappings.map_cloud
end

mapping "map_instancetype" do 
  like $mappings.map_instancetype
end

resource "sec_group", type: "security_group" do
  like @security_groups.sec_group
end

resource "sec_group_rule_all_inbound_tcp", type: "security_group_rule" do
  like @security_groups.sec_group_rule_all_inbound_tcp
end

resource "sec_group_rule_udp111", type: "security_group_rule" do
  like @security_groups.sec_group_rule_udp111
end

resource "sec_group_rule_udp2049", type: "security_group_rule" do
  like @security_groups.sec_group_rule_udp2049
end

resource "sec_group_rule_udp400x", type: "security_group_rule" do
  like @security_groups.sec_group_rule_udp400x
end


