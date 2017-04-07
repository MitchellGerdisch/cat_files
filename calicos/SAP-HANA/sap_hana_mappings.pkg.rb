name "SAP-HANA PKG - Security Groups"
rs_ca_ver 20161221
short_description "Security Group configuration for SAP-HANA"

package "sap-hana/mappings"

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "network" => "sap_vpc",
    "subnets" => "sap_subnet"
  }
}
end