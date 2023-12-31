defmodule ReqMicrosoftEntraDeviceOAuth do
  require Logger

  @supported_options [:microsoft_entra_token_cache_fs_path, :tenant_id, :scope]

  @entra_endpoint "https://login.microsoftonline.com"

  @client_id "04b07795-8ddb-461a-bbee-02f9e1bf7b46"

  @default_tenant_id "common"
  @default_scope "https://management.azure.com/.default"

  @moduledoc """
  `Req` plugin for Microsoft Entra ID device flow authentication.
  """

  @doc """
  Runs the plugin.

  ## Examples

      req =
        Req.new(http_errors: :raise)
        |> ReqMicrosoftEntraDeviceOAuth.attach(
          tenant_id: "contoso.onmicrosoft.com",
          scope: :keyvault)

      Req.get!(req, url: "https://api.github.com/user").body
  """
  def attach(request, opts \\ []) do
    opts =
      opts
      |> enrich_scope()
      |> enrich_tenant_id()

    request
    |> Req.Request.register_options(@supported_options)
    |> Req.Request.merge_options(opts)
    |> Req.Request.append_request_steps(req_microsoft_entra_device_oauth: &auth/1)
  end

  defp enrich_scope(opts) do
    scope =
      case Keyword.get(opts, :scope, @default_scope) do
        :arm -> "https://management.azure.com/.default"
        :storage -> "https://storage.azure.com/.default"
        :keyvault -> "https://vault.azure.net/.default"
        :graph -> "https://graph.microsoft.com/.default"
        x when is_atom(x) -> raise "unknown scope: #{inspect(x)}"
        x -> x
      end

    Keyword.put(opts, :scope, scope)
  end

  defp enrich_tenant_id(opts) do
    tenant_id = Keyword.get(opts, :tenant_id, @default_tenant_id)

    Keyword.put(opts, :tenant_id, tenant_id)
  end

  defp auth(request) do
    opts = request.options
    token = read_cached(opts) || request_token(opts)
    Req.Request.put_header(request, "Authorization", "Bearer #{token}")
  end

  defp read_memory_cache do
    :persistent_term.get({__MODULE__, :token}, nil)
  end

  defp write_memory_cache(token) do
    :persistent_term.put({__MODULE__, :token}, token)

    token
  end

  defp read_fs_cache(opts) do
    case File.read(token_fs_path(opts)) do
      {:ok, token} ->
        :persistent_term.put({__MODULE__, :token}, token)
        token

      {:error, :enoent} ->
        nil
    end
  end

  defp token_fs_path(opts) do
    Path.join([
      opts[:microsoft_entra_token_cache_fs_path] || :filename.basedir(:user_config, "req_microsoft_entra_oauth"),
      opts[:tenant_id],
      "devicetoken"
    ])
  end

  def read_cached(opts) do
    read_memory_cache() || read_fs_cache(opts)
  end

  defp write_fs_cache(token, opts) do
    path = token_fs_path(opts)
    Logger.debug(["writing ", path])
    File.mkdir_p!(Path.dirname(path))
    File.touch!(path)
    File.chmod!(path, 0o600)
    File.write!(path, token)
    token
  end

  def request_token(%{ tenant_id: tenant_id, scope: scope } = opts) do
    device_code_url = "#{@entra_endpoint}/#{tenant_id}/oauth2/v2.0/devicecode"
    result = Req.post!(device_code_url, form: [client_id: @client_id, scope: scope]).body

    device_code = result["device_code"]
    user_code = result["user_code"]
    sleep_duration_ms = 1000 * result["interval"]
    verification_uri = result["verification_uri"]
    _expires_in = result["expires_in"]
    _message = result["message"]

    IO.puts([
      "paste this user code:\n\n  ",
      user_code,
      "\n\nat:\n\n  ",
      verification_uri,
      "\n"
    ])

    if Mix.shell().yes?("open browser window?") do
      browser_open(verification_uri)
    end

    token_url = "#{@entra_endpoint}/#{tenant_id}/oauth2/v2.0/token"
    params = [
      client_id: @client_id,
      device_code: device_code,
      grant_type: "urn:ietf:params:oauth:grant-type:device_code"
    ]

    token = poll_token_using_devicecode(token_url, params, sleep_duration_ms)
    write_memory_cache(token)
    write_fs_cache(token, opts)
    token
  end

  defp browser_open(url) do
    {_, 0} =
      case :os.type() do
        {:win32, _} -> System.cmd("cmd", ["/c", "start", url])
        {:unix, :darwin} -> System.cmd("open", [url])
        {:unix, _} -> System.cmd("xdg-open", [url])
      end
  end

  defp poll_token_using_devicecode(token_url, params, sleep_duration_ms) do
    result =
      Req.post!(token_url, form: params).body

    if result["error"] do
      Logger.info(["response: ", result["error"]])
      Process.sleep(sleep_duration_ms)
      poll_token_using_devicecode(token_url, params, sleep_duration_ms)
    else
      Logger.info("response: success")
      result["access_token"]
    end
  end
end
