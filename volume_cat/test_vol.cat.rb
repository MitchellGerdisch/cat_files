name "Volume Dump"
rs_ca_ver 20161221
short_description "Mitch vol test"
import "pft/err_utilities"

resource "myvol", type: "volume" do
	name join(["MitchVol","-",last(split(@@deployment.href,"/"))])
	cloud_href "/api/clouds/3470"
	datacenter_href "placeholder"
	volume_type_href "/api/clouds/3470/volume_types/95B8ESTCJPFSO"
	size "5"
end

resource "myvol2", type: "volume" do
	name join(["MitchVol2","-",last(split(@@deployment.href,"/"))])
	cloud_href "/api/clouds/3470"
	datacenter_href "/api/clouds/3470/datacenters/52U5F00P8LDEP"
	volume_type_href "/api/clouds/3470/volume_types/95B8ESTCJPFSO"
	size "5"
end

operation "launch" do
	description "create volume"
	definition "create_vol"
end

operation "enable" do
	description "cause terminate"
	definition "preemptive_term"
end

operation "terminate" do
	description "terminate volume"
	definition "term_vol"
end

define create_vol(@myvol) return @myvol do
	$vol = to_object(@myvol)
	call err_utilities.log("vol object - 1 ", to_s($vol))
	$vol["fields"]["datacenter_href"] = "/api/clouds/3470/datacenters/52U5F00P8LDEP"
	call err_utilities.log("vol object - 2 ", to_s($vol))
	@vol = $vol
	call err_utilities.log("vol object - 3 ", to_s(to_object(@vol)))
	provision(@vol)
	@myvol=@vol
end

define preemptive_term() do
        call err_utilities.log("terminating", "")
	@@execution.terminate()
	call err_utilities.log("terminated", "")
end

define term_vol(@myvol) return @myvol do
        call err_utilities.log("vol terminate", to_s(@myvol))
	delete(@myvol)
end
