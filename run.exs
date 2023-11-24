Mix.install([
  {:req, "~> 0.4.5"},
  #{:req_microsoft_entra_oauth, github: "chgeuer/req_microsoftentra_oauth", force: true}
  {:req_microsoft_entra_oauth, path: "."}
])

tenant_id = "....onmicrosoft.com"
subscription_id = "..."
rg_name = "rg-demo231120c"
provider = "Microsoft.ManagedIdentity/userAssignedIdentities"
resource = "demo231120c"
api_version = "2023-01-31"
scope = :arm

# ReqMicrosoftEntraDeviceOAuth.request_token(%{ tenant_id: tenant_id, scope: scope })

url =
  "https://management.azure.com/subscriptions/#{subscription_id}/resourceGroups/#{rg_name}/providers/#{provider}/#{resource}?api-version=#{api_version}"

response =
  Req.new(http_errors: :raise)
  |> ReqMicrosoftEntraDeviceOAuth.attach([
    tenant_id: tenant_id, scope: scope,
    microsoft_entra_token_cache_fs_path: "C:\\Users\\chgeuer\\Desktop"
    ])
  |> Req.get!(url: url)

IO.puts(inspect(response.body["properties"]))
