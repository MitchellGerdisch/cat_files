name "Volume Attachment Testing"
rs_ca_ver 20161221
short_description "Volume Attachment Testing"
import "pft/err_utilities"


resource "myvol", type: "volume" do
	name join(["MyVol","-",last(split(@@deployment.href,"/"))])
	cloud_href "/api/clouds/1"
	datacenter_href "/api/clouds/1/datacenters/2BNDMBO72AVNP" # east-1a
	volume_type_href "/api/clouds/1/volume_types/1SNUA9UUF56D7" # gp2
	size "5"
end

resource "myvol_attachment", type: "volume_attachment" do
  name join(["MyVolAttach","-",last(split(@@deployment.href,"/"))])
  cloud_href "/api/clouds/1"
  server @myserver
  volume @myvol
  device "/dev/sdf"
end

resource "myserver", type: "server" do
  name join(['MyServer-',last(split(@@deployment.href,"/"))])
  cloud_href "/api/clouds/1"
  datacenter_href "/api/clouds/1/datacenters/2BNDMBO72AVNP" # east-1a
  server_template_href "/api/server_templates/396947003"
end

