defmodule EAnyPanel.NpmClient do
  @moduledoc """
  Minimal client for the Nginx Proxy Manager (NPM) REST API.
  Reads proxy hosts, certificates and other NPM resources so the panel can
  mirror the NPM interface inside e-any panel.
  """

  require Logger

  @base_url Application.compile_env(:e_any_panel, __MODULE__, base_url: "http://core-nginx:81")[
              :base_url
            ]

  defp token do
    Application.get_env(:e_any_panel, __MODULE__, [])[:token] ||
      System.get_env("NPM_API_TOKEN")
  end

  @doc """
  Returns a list of proxy hosts with NPM-style metadata:
  [%{id, domain, forward_url, ssl, access, enabled, created_on, block_exploits}]
  """
  def list_proxy_hosts do
    url = "#{@base_url}/api/nginx/proxy-hosts"

    case request(:get, url) do
      {:ok, 200, body} ->
        body
        |> Jason.decode!()
        |> Enum.map(fn host ->
          domains = host["domain_names"] || []
          cert_id = host["certificate_id"] || 0

          %{
            id: host["id"],
            domain: Enum.join(domains, ", "),
            forward_url: "http://#{host["forward_host"]}:#{host["forward_port"]}",
            ssl: if(cert_id != 0, do: "Let's Encrypt", else: "HTTP Only"),
            access: "Public",
            enabled: host["enabled"] != false,
            created_on: host["created_on"],
            block_exploits: host["block_exploits"] == true
          }
        end)

      {:ok, status, body} ->
        Logger.warning("NPM proxy-hosts API returned #{status}: #{inspect(body)}")
        []

      {:error, reason} ->
        Logger.warning("NPM API request failed: #{inspect(reason)}")
        []
    end
  rescue
    _ -> []
  end

  @doc "Returns NPM certificates list (id, domain_names, expires_on)."
  def list_certificates do
    case request(:get, "#{@base_url}/api/nginx/certificates") do
      {:ok, 200, body} ->
        body
        |> Jason.decode!()
        |> Enum.map(fn cert ->
          %{
            id: cert["id"],
            domain: Enum.join(cert["domain_names"] || [], ", "),
            expires_on: cert["expires_on"]
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  @doc "Returns NPM users list (id, email, name, is_disabled)."
  def list_users do
    case request(:get, "#{@base_url}/api/users") do
      {:ok, 200, body} ->
        body
        |> Jason.decode!()
        |> Enum.map(fn u ->
          %{
            id: u["id"],
            email: u["email"],
            name: u["name"] || u["nickname"],
            disabled: u["is_disabled"] == true
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  @doc "Returns NPM access lists (id, name, clients count)."
  def list_access_lists do
    case request(:get, "#{@base_url}/api/nginx/access-lists") do
      {:ok, 200, body} ->
        body
        |> Jason.decode!()
        |> Enum.map(fn a ->
          %{
            id: a["id"],
            name: a["name"],
            clients: length(a["clients"] || [])
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  @doc "Returns NPM audit logs (recent actions)."
  def list_audit_logs do
    case request(:get, "#{@base_url}/api/audit-logs?itemsPerPage=50") do
      {:ok, 200, body} ->
        body
        |> Map.get("data", body)
        |> Enum.map(fn l ->
          %{
            id: l["id"],
            time: l["time"],
            object: l["object"],
            action: l["action"],
            actor: l["actor"]
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  # --- internal ---------------------------------------------------------
  defp request(method, url) do
    headers = [{"Authorization", "Bearer #{token()}"}]
    req = Finch.build(method, url, headers)

    case Finch.request(req, Finch) do
      {:ok, %{status: status, body: body}} -> {:ok, status, body}
      {:error, reason} -> {:error, reason}
    end
  end
end
