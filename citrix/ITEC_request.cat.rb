# ITEC Resource Request CAT
# This CAT is really just a form that is filled out and used by the central IT team to fullfill on their private cloud.

name "ITEC Resource Request"
rs_ca_ver 20131202
short_description "ITEC Request Form"


parameter "param_bus_unit" do
  category "Request"
  type "string"
  label "Requester's Business Unit"
  allowed_values "Business Technology Solutions",
      "Citrix Online - Audio - Customer Ops",
      "Citrix Operations (COPS)",
      "Customer One",
      "Data Innovations Group",
      "Engineering Product Ops",
      "Global Security Organization",
      "Information Technologies",
      "WW Sales & Svc Ops",
      "Web Development & Technologies",
      "Workflow and Workspace Cloud"
  default "Business Technology Solutions"
end

output "output_bus_unit" do
  category "Request"
  label "Requestor's Business Unit"
  default_value $param_bus_unit
end

### Requester Name is  unnecessary since the cloud app display will show who launched it.
#parameter "param_requester_name" do
#  category "Request"
#  type "string"
#  label "Name"
#end
#
#output "output_requester_name" do
#  category "Request"
#  label "Name"
#  default_value $param_requester_name
#end

### The project name and description can be entered as the cloud app name and description when launching the cloud app.
#parameter "param_project_name" do
#  category "Request"
#  type "string"
#  label "Project Name"
#end
#
#output "output_project_name" do
#  category "Request"
#  label "Project Name"
#  default_value $param_project_name
#end
#
#parameter "param_project_description" do
#  category "Request"
#  type "string"
#  label "Project Name"
#end
#
#output "output_project_description" do
#  category "Request"
#  label "Project Description"
#  default_value $param_project_description
#end

parameter "param_duration" do
  category "Request"
  type "string"
  label "Duration (Months)"
  allowed_values "48", "36", "24", "12", "6"
end

output "output_duration" do
  category "Request"
  label "Duration (Months)"
  default_value $param_duration
end

parameter "param_accessibility" do
  category "Request"
  type "string"
  label "System Accessibility"
  allowed_values "---", "Internal Access Only", "External Access Only", "Internal and External Access"
end

output "output_accessibility" do
  category "Request"
  label "System Accessibility"
  default_value $param_accessibility
end

parameter "param_cloud_type" do
  category "Request"
  type "string"
  label "Cloud Type"
  allowed_values "---", "Private (ITEC)", "Public", "Hybrid", "Tradition (Data Center)"
end

output "output_cloud_type" do
  category "Request"
  label "Cloud Type"
  default_value $param_cloud_type
end

parameter "param_data_center" do
  category "Request"
  type "string"
  label "If Traditional (Data Center), Select Location"
  allowed_values " ", "Amsterdam", "Las Vegas, NV", "Miami, FL", "Santa Clara, CA", "Singapore"
  default " "
end

output "output_data_center" do
  category "Request"
  label "If Traditional (Data Center), Select Location"
  default_value $param_data_center
end

parameter "param_public_cloud" do
  category "Request"
  type "string"
  label "If Public Cloud, Select Provider"
  allowed_values "---", "Amazon (AWS)", "Microsoft (Azure)", "IBM (SoftLayer)", "Rackspace", "Other"
  default "---"
end

output "output_public_cloud" do
  category "Request"
  label "If Public Cloud, Select Provider"
  default_value $param_public_cloud
end

parameter "param_other_public_cloud_provider" do
  category "Request"
  type "string"
  label "If other Public Cloud Provider"
  default " "
end

output "output_other_public_cloud_provider" do
  category "Request"
  label "If other Public Cloud Provider"
  default_value $param_other_public_cloud_provider
end

parameter "param_operating_system" do
  category "Request"
  type "string"
  label "Operating System"
  allowed_values "---", "Windows 2K8 R2", "Windows 2K12 R2", "Centos", "Redhat", "Other"
end

output "output_operating_system" do
  category "Request"
  label "Operating System"
  default_value $param_operating_system
end

parameter "param_other_os" do
  category "Request"
  type "string"
  label "If other Operating System"
  default " "
end

output "output_other_os" do
  category "Request"
  label "If other Operating System"
  default_value $param_other_os
end

parameter "param_num_vms" do
  category "Request"
  type "number"
  label "Total Number of VMs"
end

output "output_num_vms" do
  category "Request"
  label "Total Number of VMs"
  default_value $param_num_vms
end

parameter "param_num_cpus" do
  category "Request"
  type "number"
  label "Total Number of CPUs"
end

output "output_num_cpus" do
  category "Request"
  label "Total Number of CPUs"
  default_value $param_num_cpus
end

parameter "param_memory" do
  category "Request"
  type "number"
  label "Total Virtual Memory (GB)"
end

output "output_memory" do
  category "Request"
  label "Total Virtual Memory (GB)"
  default_value $param_memory
end

parameter "param_storage" do
  category "Request"
  type "number"
  label "Total Storage (GB)"
end

output "output_storage" do
  category "Request"
  label "Total Storage (GB)"
  default_value $param_storage
end

parameter "param_addl_tech_specs" do
  category "Request"
  type "string"
  label "Additional Technical Specifications"
  default " "
end

output "output_addl_tech_specs" do
  category "Request"
  label "Additional Technical Specifications"
  default_value $param_addl_tech_specs
end

parameter "param_funding_source" do
  category "Request"
  type "string"
  label "Funding Source"
  allowed_values "---", "Capital", "Expense", "Swap"
end

output "output_funding_source" do
  category "Request"
  label "Funding Source"
  default_value $param_funding_source
end

parameter "param_cost_center" do
  category "Request"
  type "string"
  label "WBS#/Cost Center#"
end

output "output_cost_center" do
  category "Request"
  label "WBS#/Cost Center#"
  default_value $param_cost_center
end


### There's no Date type for the "When provisioned" question - can use the Cloud App scheduling to set this info

### There's no way to attach a file to a CAT launch
