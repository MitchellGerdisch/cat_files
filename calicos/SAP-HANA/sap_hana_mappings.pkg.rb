name "SAP-HANA PKG - Mappings"
rs_ca_ver 20161221
short_description "Mappings for SAP-HANA"

package "sap_hana/mappings"

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "network" => "sap_vpc",
    "subnets" => "sap_subnet",
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key"
  },
  "AzureRM" => {   
    "cloud" => "AzureRM East US",
    "network" => "pft_arm_network",
    "subnets" => "default",
    "sg" => '@sec_group',  
    "ssh_key" => null
  }
}
end

mapping "map_instancetype" do {
  "Standard Performance" => {
    "AWS" => "t2.large",
    "Azure" => "D1",
    "AzureRM" => "D1",
    "Google" => "n1-standard-1",
    "VMware" => "small",
  },
  "High Performance" => {
    "AWS" => "r3.2xlarge",
    "Azure" => "D2",
    "AzureRM" => "D1",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end