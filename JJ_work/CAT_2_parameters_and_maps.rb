# AWS RDS Reference: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
# There are some limitations related to SQL server edition and instance types and licensing.
# For this reason, the allowed parameters are limited to common denominators.

name "CAT #2 Parameter Test"
rs_ca_ver 20131202
short_description "Test the parameters"


parameter "db_rds_name" do
  type "string"
  label "Database Name"
  category "Database Tier"
end

parameter "db_engine" do
  type "string"
  label "SQL Server Edition"
  allowed_values "SQL Server Standard Edition", "SQL Server Enterprise Edition" 
  category "Database Tier"
  default "SQL Server Standard Edition"
end

parameter "db_license_model" do
  type "string"
  label "Licensing"
  allowed_values "License included", "Bring your own license"
  category "Database Tier"
  default "License included"
end

parameter "db_instance_class" do
  type "string"
  label "Server Performance level"
  allowed_values "Low performance", "Standard performance", "High performance"
  category "Database Tier"
  default "Standard performance"
end

parameter "db_storage_class" do
  type "string"
  label "Storage Performance level"
  allowed_values "Low performance", "Standard performance", "Provisioned IOPS (expert use)"
  category "Database Tier"
  default "Standard performance"
end

parameter "db_storage_iops" do
  type "number"
  label "Provisioned IOPS setting (expert use)"
  category "Database Tier"
end

parameter "db_allocated_storage" do
  type "number"
  label "Allocated storage (GB)"
  category "Database Tier"
  default "200"
end

parameter "db_az_option" do
  type "string"
  label "High availability"
  category "Database Tier"
  allowed_values "Disabled", "Enabled"
  default "Disabled"
end


# Maps the user selected parameters to AWS inputs
mapping "parameter_maps" do {
	"db_engine" => {
		"SQL Server Web Edition" => "sqlserver-web",
		"SQL Server Standard Edition" => "sqlserver-se",
		"SQL Server Express Edition" => "sqlserver-ex",
		"SQL Server Enterprise Edition" => "sqlserver-ee",
	},
	"db_license_model" => {
		"License included" => "license-included",
		"Bring your own license" => "bring-your-own-license",
	},
	"db_instance_class" => {
		"Low performance" => "db.m3.medium",
		"Standard performance" => "db.r3.large",
		"High performance" => "db.r3.xlarge",
	},
 	"db_az_option" => {
 		"Enabled" => "multi-az",
 		"Disabled" => "no-multi=az",
 	},
  "db_storage_class" => {
    "Low performance" => "standard",
    "Standard performance" => "gp2",
    "Provisioned IOPS (expert use)" => "io1"
  }
}
end

########### THE ITEMS BELOW THIS LINE ARE FOR TESTING ONLY ###########
### Although having these outputs causes the parameters to be presented to the user, 
### For some reason the outputs are not displayed.
output "output_db_rds_name" do
  label "Database Name"
  category "Database Tier"
  default_value $db_rds_name
  description "Provided DB name"
end

output "output_db_engine" do
  label "SQL Server Edition"
  category "Database Tier"
  default_value $db_engine
  description "Selected SQL server edition"
end

output "output_db_license_model" do
  label "Licensing"
  category "Database Tier"
  default_value $db_license_model
  description "Selected licensing model"
end

output "output_db_instance_class" do
  label "Performance"
  category "Database Tier"
  default_value $db_instance_class
  description "Selected performance level"
end

output "output_db_storage_class" do
  label "Storage Performance level"
  category "Database Tier"
  default_value $db_storage_class
  description "Selected storage performance level" 
end

output "output_db_storage_iops" do
  label "Provisioned IOPS setting (expert use)"
  category "Database Tier"
  default_value $db_storage_iops
  description "Selected storage IOPS"
end

output "output_db_allocated_storage" do
  label "Allocated storage (GB)"
  category "Database Tier"
  default_value $db_allocated_storage
  description "Amount of storage space"
end

output "output_db_az_option" do
  label "High availability"
  category "Database Tier"
  default_value $db_az_option
  description "Selected availability"
end