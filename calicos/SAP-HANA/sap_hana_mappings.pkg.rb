name "SAP-HANA PKG - Mappings"
rs_ca_ver 20161221
short_description "Security Group configuration for SAP-HANA"

package "sap_hana/mappings"

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "network" => "sap_vpc",
    "subnets" => "sap_subnet"
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