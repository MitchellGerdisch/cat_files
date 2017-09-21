name 'Output Tester'
rs_ca_ver 20161221
short_description  "testing stuff"

import "pft/err_utilities"

parameter 'user_input' do
  category "Stack Deployment"
  type "string"
  label "Application Stack"
  description "Select an application stack to launch on the Rancher Cluster."
  default "launch_input"
end

output "rancher_ui_link" do
  category "Rancher UI Access"
  label "Rancher UI Link"
  description "Click to access the Rancher UI.(NOTE: username/passsword = \"rightscale\")"
end

output "rancher_infra_link" do
  category "Rancher UI Access"
  label "Rancher Infrastructure Page"
  description "Click to see the Rancher Cluster infrastructure."
end

operation 'launch' do 
  description 'Launch the application' 
  definition 'launch_cluster' 
  output_mappings do {
    $rancher_ui_link => $rancher_ui_uri,
    $rancher_infra_link => $rancher_infra_uri,
  } end
end 

operation 'launch_app_stack' do
  label 'Launch an Application Stack'
  description "Launch an application stack"
  definition "deploy_stack"
  output_mappings do {
    $rancher_ui_link => $rancher_ui_uri,
    $rancher_infra_link => $rancher_infra_uri,
  } end
end

define launch_cluster($user_input)  return $rancher_ui_uri, $rancher_infra_uri  do 
  
  @execution_extended_data = @@execution.get(view:"extended")
  @execution_outputs = 
  $rancher_ui_uri = "http://fake_ui_uri/"+$user_input
  $rancher_infra_uri = "http://more_stuff/"+$user_input+"/infrastuff"
  call err_utilities.log("launch_cluster: @@execution", to_s(@@execution.get(view:"extended").outputs))
end

define deploy_stack($user_input)  return $rancher_ui_uri, $rancher_infra_uri  do 
  call err_utilities.log("deploy_stack before: @@execution", to_s(@@execution.outputs))

  $rancher_ui_uri = "http://fake_ui_uri/"+$user_input
  $rancher_infra_uri = "http://more_stuff/"+$user_input+"/infrastuff"
  call err_utilities.log("deploy_stack after: @@execution", to_s(@@execution.outputs))
end



