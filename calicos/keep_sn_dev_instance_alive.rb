# TO-DO 
# Use scheduled actions instead of a sleep? This would allow me to change the poke interval post launch.
# I also wonder if it would be friendlier to the SS system.

name "Keep ServiceNow Dev Instance Alive"
rs_ca_ver 20160622
short_description "This is run to keep the ServiceNow dev instance from going to sleep."

import "demo/err_utilities", as: "err"

parameter "param_check_interval" do 
  category "User Inputs"
  label "Number of minutes between pokes" 
  type "number" 
  default 30
end

mapping "map_servicenow_info" do {
  "items" => {
    "sn_instance_id" => "dev17048.service-now.com",
    "sn_user_cred" => "SERVICENOW_USER",
    "sn_password_cred" => "SERVICENOW_PASSWORD"
  },
}
end

operation "launch" do
  definition "launch"
  output_mappings do {
    $out_issue_link => $issue_url
  } end
end

output "out_issue_link" do
  label "Approval ticket"
end

define launch($map_servicenow_info, $param_check_interval) return $issue_url do

  $$USER = cred(map($map_servicenow_info, "items", "sn_user_cred"))
  $$PASSWORD = cred(map($map_servicenow_info, "items", "sn_password_cred"))
 
  sub task_label: "Creating ticket for checking" do
    call create_issue(map($map_servicenow_info, "items", "sn_instance_id"), "This ticket is for keeping the ServiceNow instance from hibernating") retrieve $issue_link
    call get_issue_url($issue_link, map($map_servicenow_info, "items", "sn_instance_id")) retrieve $issue_url
   

    # Wait forever - the hope is that checking the issue state will keep the dev instance alive
    while true do
      sleep($param_check_interval*60) # check every half-hour and see if that works.
      call get_issue_state($issue_link) retrieve $issue_state
    end

  end
end
 
define get_issue_url($issue_link, $sn_instance_id) return $issue_url do
  
  # Get the issue ID
  $issue_id = last(split($issue_link, "/"))
    
  $issue_url = "https://"+$sn_instance_id+"/nav_to.do?uri=incident.do?sys_id="+$issue_id

end

define get_issue_state($issue_link) return $issue_state do

  $response = http_get(
    url: $issue_link,
    headers: { "Content-Type": "application/json"},
    basic_auth: {
      "username": $$USER,
      "password": $$PASSWORD
    }
  )

  $body = $response["body"]

  $incident_state = $body["result"]["incident_state"]
    
  $issue_state = "Not Resolved"
    
  # State == 1 is the New state
  # For this demo CAT, we'll assume any state the user puts it in will be considered approved
  if $incident_state != "1"
   $issue_state = "Resolved"
  end

end

define create_issue($sn_instance_id, $summary) return $issue_link do

  $sn_api_url = "https://"+$sn_instance_id+"/api/now/table/incident"
  
  $response = http_post(
    url: $sn_api_url,
    body: { 
      short_description: $summary
    },
    headers: { "Content-Type": "application/json"},
    basic_auth: {
      "username": $$USER,
      "password": $$PASSWORD
    }
  )

  $issue_link = $response["headers"]["Location"]
    
  call err.log("Ticket link"+to_s($issue_link), "")


end


define send_slack($channel, $message)  do
  $slack_channel_hook = cred("SLACK_CAT-DEMO-BOT_Channel-hook")
  $response = http_post(
    url: $slack_channel_hook,
    body: { channel: $channel, text: $message} )
end
