name "Custom Provisioner - Vol Attach"
rs_ca_ver 20161221
short_description "Custom Provision Testing"
import "pft/err_utilities"


resource "myserver", type: "server_array", provision: "my_provisioner" do
  name join(['MyServer-',last(split(@@deployment.href,"/"))])
  cloud_href "/api/clouds/1"
  datacenter_href "/api/clouds/1/datacenters/2BNDMBO72AVNP" # east-1a
  server_template_href "/api/server_templates/409780003"
  state "disabled"
  array_type "alert"
  elasticity_params do {
    "bounds" => {
      "min_count"            => 1,
      "max_count"            => 5 # Limited to 5 to avoid deploying too many servers.
    },
    "pacing" => {
      "resize_calm_time"     => 5,
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => join(['App-',last(split(@@deployment.href,"/"))])
    }
  } end
end

define my_provisioner(@declaration) return @server_array do
  $declaration = to_object(@declaration)
  $declaration = $declaration["fields"]
  $cloud_href =  $declaration["cloud_href"]  # Get the cloud href for the SA
    
  # Create SA but don't enable it yet.
  @server_array = rs_cm.server_arrays.create($declaration)
  # Get the created SA
  @server_array = @server_array.get()
  
  # Initialize a cloud resource for the SA's cloud
  @cloud = rs_cm.get(href: $cloud_href)
  # Create a recurring_volume_attachment in that cloud associated with the SA 
  @cloud.recurring_volume_attachments().create(recurring_volume_attachment: {
    device: "/dev/sdf",
    runnable_href: @server_array.href,
    storage_href: "/api/clouds/1/volume_snapshots/8U70QV5NPT7QV"
  })
 
  @server_array.update(server_array: {
      state: "enabled"
  })
end


