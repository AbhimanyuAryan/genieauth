#TODO: Fix this code to remove HTTP.jl JSON.jl DotEnv
#TODO: put it inside GenieAuthentication with structure
using HTTP
using JSON
using URIs
using DotEnv
using Genie, Genie.Router, Genie.Renderer

# Load environment variables
DotEnv.config()

function generate_query_string(params::Dict{String,String})
    return join(["$k=$(HTTP.escapeuri(v))" for (k, v) in params], '&')
end

route("/") do
    return """
        <a href="/auth/google">Authenticate with Google</a>
    """
end

route("/auth/google") do
    authUrl = "https://accounts.google.com/o/oauth2/v2/auth"
    params = Dict(
        "client_id" => ENV["GOOGLE_CLIENT_ID"],
        "redirect_uri" => ENV["REDIRECT_URI"],
        "response_type" => "code",
        "scope" => "https://www.googleapis.com/auth/userinfo.profile",
        "access_type" => "offline",
        "include_granted_scopes" => "true",
        "state" => "pass-through value"
    )
    query_string = generate_query_string(params)

    Genie.Renderer.redirect(authUrl * "?" * query_string)
end

route("/auth/google/callback") do
    authUrl = "https://oauth2.googleapis.com/token"
    code = Genie.params(:code, nothing)

    headers = ["Content-Type" => "application/x-www-form-urlencoded"]

    data = Dict(
        "code" => code,
        "client_id" => ENV["GOOGLE_CLIENT_ID"],
        "client_secret" => ENV["GOOGLE_CLIENT_SECRET"],
        "redirect_uri" => ENV["REDIRECT_URI"],
        "grant_type" => "authorization_code"
    )

    try
        query_string = generate_query_string(data)
        response = HTTP.post(authUrl, headers, query_string)
        access_token = JSON.parse(String(response.body))["access_token"]
        
        user_obj = HTTP.get(
            "https://www.googleapis.com/oauth2/v1/userinfo", 
            ["Authorization" => "Bearer $access_token"]
        )
        user_info = JSON.parse(String(user_obj.body))
    
        Genie.Renderer.redirect("/pass")
    catch ex
        @info ex
        Genie.Renderer.redirect("/fail")
    end
end

route("/pass") do
    return "pass"
end

route("/fail") do
    return "fail"
end

up(8080, async=false)
