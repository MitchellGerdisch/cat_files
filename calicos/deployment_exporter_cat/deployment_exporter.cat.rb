# This CAT creates a CAT based on a running deployment.
#
# TO-DOs: Account for raw instances in the deployment. Currently only handling servers and server_arrays.


name "Deployment Exporter"
rs_ca_ver 20160622
short_description "Creates a CAT from a running deployment."
long_description "Creates a CAT from a running deployment in this RightScale account. So this CAT is kind of a meta-CAT.""

parameter "param_deployment_href" do 
  category "Inputs"
  label "Deployment HREF" 
  type "string" 
  description "The  HREF of the deployment you want to export into a CAT. It can be found on the Info tab for the deployment."
  default_value "/api/deployments/"
  allowed_pattern "/^\/api\/deployments\/[0-9]*$/"
end

  
define deployment_cat() do

  # create a deployment resource for the deployment to export
  @export_deployment = rs_cm.get(href: $param_deployment_href)
  
  # Start building the string that is the CAT file with the required fields metadata
  $$cat = "name " + @export_deployment.name + "\nrs_ca_ver 20160622\nshort_description Exported CAT"

  @servers = @export_deployment.servers()
  @server_arrays = @export_deployment.server_arrays()
  @deployment_inputs = @export_deployment.inputs()
  
end





