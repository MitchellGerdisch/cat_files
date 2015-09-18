# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $account_number do
  $cloud_accounts = to_object(first(rs.cloud_accounts.get()))
  @info = first(rs.cloud_accounts.get())
  $info_links = @info.links
  $rs_account_info = select($info_links, { "rel": "account" })[0]
  $rs_account_href = $rs_account_info["href"]  
    
  $rs_account_number = last(split($rs_account_href. "/"))
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "rs_account_number" , detail: to_s($rs_account_number)})
end
  
  
  
