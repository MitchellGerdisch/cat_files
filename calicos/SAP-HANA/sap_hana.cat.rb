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
short_description "![logo](https://www.sap-sdk.dk/images/partner/sap-norge-as.jpg) 

Launch a SAP-HANA system."
long_description "Currently focused on master SAP-Hana node. Later revisions will support launching multiple workers."

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "network" => "sap_vpc",
    "subnets" => "sap_subnet"
  }
}
end

resource 'saphana_master', type: 'server' do
  name join(["hana_master_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
  network map($map_cloud, "AWS", "network")
  subnets map($map_cloud, "AWS", "subnets")
  security_groups @sec_group
  ssh_key @ssh_key
  server_template find('SAP-Hana RL10 Enablement - WIP', revision: 0)
  inputs do {
    'MONITORING_METHOD' => 'text:rightlink',
  } end
end

resource "sec_group", type: "security_group" do
  name join(["HanaSecGrp-",last(split(@@deployment.href,"/"))])
  description "SAP Hana Securiy Group security group."
  cloud map($map_cloud, "AWS", "cloud")
  network map($map_cloud, "AWS", "network")
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  name join(["SshRule-",last(split(@@deployment.href,"/"))])
  description "Allow SSH access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end

### SSH key declarations ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
end


