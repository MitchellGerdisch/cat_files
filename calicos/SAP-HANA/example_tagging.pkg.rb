name "SAP-HANA PKG - Business Tags"
rs_ca_ver 20161221
short_description "Example Business Tags for SAP-HANA"

package "sap_hana/tagging"

parameter "param_bo" do 
  category "Deployment Options"
  label "Business Owner (First Name, Last Name)" 
  type "string" 
  allowed_pattern '(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=])'
  default "Google"
end


parameter "param_password" do 
  category "User Inputs"
  label "Windows Password" 
  description "Minimum at least 8 characters and must contain at least one of each of the following: 
  Uppercase characters, Lowercase characters, Digits 0-9, Non alphanumeric characters [@#\$%^&+=]." 
  type "string" 
  min_length 8
  max_length 32
  # This enforces a stricter windows password complexity in that all 4 elements are required as opposed to just 3.
  allowed_pattern '(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=])'
  no_echo "true"
end
BUSINESSOWNER= ‘FIRST NAME, LAST NAME’
BILLINGCODE= ‘XYS123’
NAME= ‘SERVERNAME’
ENVIRONMENT= PRD | NPD | SBX | SYS | DEV | TEST |UAT | STAGE | LOAD | QA
PROJECTNAME= ‘PROJECT NAME’


define tagger($resource_array, $param_bo, $param_bc, $param_env, $param_proj)  do
  
    # Tag the servers with the selected project cost center ID.
    $tags=["MEMBERFIRM=US", "COUNTRY=US", "FUNCTION=CON", "SUBFUNCTION=DCP", "BUSINESSOWNER="+$param_bo, "BILLINGCODE="+$param_bc,
      "ENVIRONMENT="+$param_env, "PROJECTNAME="+$param_proj]
    rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
    
end 





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