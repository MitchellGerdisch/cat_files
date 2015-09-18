# Returns the RightScale shard for the account the given CAT is launched in.
# It relies on the fact that when a CAT is launched, the resultant deployment description includes a link
# back to Self-Service. 
# This link is exploited to identify the shard.
# Of course, this is somewhat dangerous because if the deployment description is changed to remove that link, 
# this code will not work.
# Similarly, since the deployment description is also based on the CAT description, if the CAT author or publisher
# puts something like "selfservice-8" in it for some reason, this code will likely get confused.
# However, for the time being it's fine.
define find_shard(@deployment) return $shard_number do
  
  $deployment_description = @deployment.description
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "deployment description" , detail: $deployment_description})
  
  # initialize a value
  $shard_number = "UNKNOWN"
  foreach $word in split($deployment_description, "/") do
    if $word =~ "selfservice-" 
    #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found word:",$word]) , detail: ""}) 
      foreach $character in split($word, "") do
        if $character =~ /[0-9]/
          $shard_number = $character
          #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: join(["found shard:",$character]) , detail: ""}) 
        end
      end
    end
  end
end