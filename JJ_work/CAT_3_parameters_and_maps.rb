# AWS RDS Reference: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
# There are some limitations related to SQL server edition and instance types and licensing.
# For this reason, the allowed parameters are limited to common denominators.

name "CAT #3 Parameter Test"
rs_ca_ver 20131202
short_description "Test the parameters"


parameter "param_cloud" do 
  category "Cloud options"
  label "Cloud Provider" 
  type "string" 
#  description "Cloud provider" 
  allowed_values "AWS", "Azure"
  default "AWS"
end

parameter "performance" do
  category "Application Performance Settings" 
  label "Performance Level" 
  type "string" 
#  description "Determines the instance type of the DB and App Servers." 
  allowed_values "low", "high"
  default "low"
end

parameter "array_min_size" do
  category "Application Scaling Settings"
  label "How many application servers to start with?"
  type "number"
#  description "Minimum number of servers in the application tier."
  default "1"
end
parameter "array_max_size" do
  category "Application Scaling Settings"
  label "Maximum number of application servers to allow?"
  type "number"
#  description "Maximum number of servers in the application tier."
  default "5"
end




########### THE ITEMS BELOW THIS LINE ARE FOR TESTING ONLY ###########
### Although having these outputs causes the parameters to be presented to the user, 
### For some reason the outputs are not displayed.
output "output_param_cloud" do 
  category "Cloud options"
  label "Cloud Provider" 
  description "Cloud provider" 
  default_value $param_cloud
end

output "output_performance" do
  category "Performance level" 
  label "Application Performance" 
  description "Determines the instance type of the DB and App Servers." 
  default_value $performance
end

output "output_array_min_size" do
  category "Application Scaling Parameters"
  label "How many application servers to start with?"
  description "Minimum number of servers in the application tier."
  default_value $array_min_size
end

output "output_array_max_size" do
  category "Application Scaling Parameters"
  label "Maximum number of application servers to allow?"
  description "Maximum number of servers in the application tier."
  default_value $array_max_size
end
