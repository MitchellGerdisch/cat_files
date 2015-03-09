name 'Elastic IP Test'
rs_ca_ver 20131202
short_description 'Elastic IP Test'

# Resource definitions are based on Deployment Exporter described here:
# http://support.rightscale.com/12-Guides/Self-Service/30_Designers_Guide/05_Cloud_Application_Template_(CAT)_Design_Concepts
resource 'lb', type: 'server' do
  name 'lb'
  cloud 'us-west-1'
  instance_type 'm1.small'
  security_groups 'default'
  ssh_key 'default'
  server_template find('Base ServerTemplate for Linux (RSB) (v14.1.0)')
end

#resource 'lb_ip_binding', type: 'ip_address_binding' do
#  name 'lb_public_ip_address'
#  cloud 'us-west-1'
#  instance @haproxy_server.current_instance()
#  public_ip_address_href "/api/clouds/3/ip_addresses/F3OMFRU76CBO5"
#end

### Operations ###

## executes automatically
#operation "launch" do
#  description "Launches all the servers concurrently"
#  definition "launch_concurrent"
#end
#
#
#### Definitions ###
#define launch_concurrent(@lb) return @lb do
#    task_label("Launch servers concurrently")
#
#    # Since we want to launch these in concurrent tasks, we need to use global resources
#    #  Tasks (like a "sub" of a concurrent block) get a copy of the resource scoped only
#    #   to that task. Since we want to modify these particular resources, we copy them
#    #   into global scope and copy them back at the end
#    
#    @@launch_lb = @lb
#
#    concurrent do
#      sub task_name:"Launch Load Balancer" do
#        task_label("Launching Load Balancer")
#        $lb_retries = 0 
#        sub on_error: handle_provision_error($lb_retries) do
#          $lb_retries = $lb_retries + 1
#          provision(@@launch_lb)
#        end
#      end      
#    end
#  end

define bind_ip(@lb) return @lb do   
    @ip_address_binding = 
      { "namespace": "rs",
        "type":      "ip_address_bindings",
        "fields":    { 
          "instance_href": to_json(@lb.current_instance()), 
          "public_ip_address_href": to_json("/api/clouds/3/ip_addresses/F3OMFRU76CBO5")
        } 
      }
end
