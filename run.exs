Mix.install([
  {:req, "~> 0.4.5"},
  #{:req_microsoft_entra_oauth, github: "chgeuer/req_microsoft_entra_oauth", force: true}
  {:req_microsoft_entra_oauth, path: "."},
  {:joken, "~> 2.6"}, {:jason, "~> 1.4"}
])

scope = :arm
tenant_id = "chgeuerfte.onmicrosoft.com"
subscription_id = "724467b5-bee4-484b-bf13-d6a5505d2b51"

rg_name = "rg-demo231120c"
provider = "Microsoft.ManagedIdentity/userAssignedIdentities"
resource = "demo231120c"
api_version = "2023-01-31"

# ReqMicrosoftEntraDeviceOAuth.request_token(%{ tenant_id: tenant_id, scope: scope })

url =
  "https://management.azure.com/subscriptions/#{subscription_id}/resourceGroups/#{rg_name}/providers/#{provider}/#{resource}?api-version=#{api_version}"

entra_opts = [
  tenant_id: tenant_id, scope: scope,
  microsoft_entra_token_cache_fs_path: "C:\\Users\\chgeuer\\Desktop"
  ]

entra_opts
  |> ReqMicrosoftEntraDeviceOAuth.read_cached()
  |> Joken.peek_claims()
  |> (fn { :ok, claims } -> "Token issued by #{claims["iss"]} for user #{claims["unique_name"]} and audience #{claims["aud"]}" end).()
  |> IO.puts()

response =
  Req.new(http_errors: :raise)
  |> ReqMicrosoftEntraDeviceOAuth.attach(entra_opts)
  |> Req.get!(url: url)

IO.puts(inspect(response.body["properties"]))

url =
  "https://management.azure.com/subscriptions/#{subscription_id}/resourceGroups?api-version=2021-04-01"
response =
  Req.new(http_errors: :raise)
  |> ReqMicrosoftEntraDeviceOAuth.attach([
    tenant_id: tenant_id, scope: scope,
    microsoft_entra_token_cache_fs_path: "C:\\Users\\chgeuer\\Desktop"
    ])
  |> Req.get!(url: url)

resouce_groups = response.body["value"] |> Enum.map(fn rg -> %{ name: rg["name"], location: rg["location"] } end)
IO.puts(inspect(resouce_groups))
