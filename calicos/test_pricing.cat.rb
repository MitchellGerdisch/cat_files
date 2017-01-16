name "RS Pricing API Testing"
rs_ca_ver 20131202
short_description "some api testing"

parameter "param_api_url" do 
  category "User Inputs"
  label "API URL" 
  type "string" 
  default "https://my.rightscale.com/api/deployments"
end

parameter "param_api_version" do 
  category "User Inputs"
  label "API Version" 
  type "string" 
  default "1.5"
end

output "api_output" do
  label "API Output"
  category "Output"
  description "Output from API call"
end

operation "Make an API Call" do
  definition "run_api"
  output_mappings do {
    $api_output => $api_results
  }
  end
end


define run_api($param_api_url, $param_api_version) return $api_results do

  $response = http_get(    
    url: $param_api_url,
    headers: { 
      "X-Api-Version": $param_api_version, 
      "Content-Type": "application/json" 
    }
  )
   rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "API Call Response",
      detail: to_s($response)
    }
  )
  
  $api_results = $response
end