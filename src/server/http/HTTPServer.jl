"""
    HTTPServer

HTTP/REST API server for JuliaHub server-side platform.
Provides RESTful endpoints for all server functionality.
"""
module HTTPServer

using HTTP
using JSON
using Dates
using UUIDs

export start_http_server, stop_http_server
export Route, Router, add_route!, handle_request
export HTTPRequest, HTTPResponse
export Middleware, use_middleware!
export json_response, error_response, success_response

# ============================================================================
# Types
# ============================================================================

"""
    HTTPRequest

Wrapper for HTTP request with parsed data.
"""
struct HTTPRequest
    method::String
    path::String
    headers::Dict{String, String}
    query::Dict{String, String}
    params::Dict{String, String}
    body::Union{Dict{String, Any}, Nothing}
    raw::HTTP.Request
    user_id::Union{String, Nothing}
    session_id::Union{String, Nothing}
end

"""
    HTTPResponse

HTTP response structure.
"""
struct HTTPResponse
    status::Int
    headers::Dict{String, String}
    body::String
end

"""
    Route

A single API route definition.
"""
struct Route
    method::String
    path::String
    handler::Function
    middleware::Vector{Function}
    auth_required::Bool
    permissions::Vector{String}
    description::String
end

"""
    Router

HTTP router that manages routes and middleware.
"""
mutable struct Router
    routes::Vector{Route}
    middleware::Vector{Function}
    prefix::String
    
    function Router(; prefix::String="")
        new(Route[], Function[], prefix)
    end
end

"""
    Middleware

Middleware function type alias.
"""
const Middleware = Function

# ============================================================================
# Global State
# ============================================================================

const MAIN_ROUTER = Router()
const HTTP_SERVER = Ref{Union{Nothing, HTTP.Server}}(nothing)
const SERVER_TASK = Ref{Union{Nothing, Task}}(nothing)

# ============================================================================
# Response Helpers
# ============================================================================

"""
    json_response(data::Any; status::Int=200, headers::Dict{String, String}=Dict{String, String}()) -> HTTPResponse

Create a JSON response.
"""
function json_response(data::Any; status::Int=200, headers::Dict{String, String}=Dict{String, String}())
    headers["Content-Type"] = "application/json"
    body = JSON.json(data)
    return HTTPResponse(status, headers, body)
end

"""
    error_response(message::String, status::Int=400; code::String="error") -> HTTPResponse

Create an error response.
"""
function error_response(message::String, status::Int=400; code::String="error")
    return json_response(Dict(
        "error" => true,
        "code" => code,
        "message" => message,
        "timestamp" => string(now())
    ); status=status)
end

"""
    success_response(data::Any=nothing; message::String="Success") -> HTTPResponse

Create a success response.
"""
function success_response(data::Any=nothing; message::String="Success")
    response_data = Dict(
        "success" => true,
        "message" => message,
        "timestamp" => string(now())
    )
    
    if !isnothing(data)
        response_data["data"] = data
    end
    
    return json_response(response_data)
end

# ============================================================================
# Request Parsing
# ============================================================================

"""
    parse_request(request::HTTP.Request, params::Dict{String, String}=Dict{String, String}()) -> HTTPRequest

Parse an HTTP request into HTTPRequest structure.
"""
function parse_request(request::HTTP.Request, params::Dict{String, String}=Dict{String, String}())
    # Parse headers
    headers = Dict{String, String}()
    for header in request.headers
        headers[lowercase(first(header))] = last(header)
    end
    
    # Parse query parameters
    query = Dict{String, String}()
    uri = HTTP.URI(request.target)
    if !isempty(uri.query)
        for param in split(uri.query, "&")
            if contains(param, "=")
                key, value = split(param, "="; limit=2)
                query[HTTP.unescapeuri(key)] = HTTP.unescapeuri(value)
            end
        end
    end
    
    # Parse body
    body = nothing
    if !isempty(request.body) && get(headers, "content-type", "") == "application/json"
        try
            body = JSON.parse(String(request.body))
        catch
            # Invalid JSON, leave body as nothing
        end
    end
    
    # Extract user info from headers (set by auth middleware)
    user_id = get(headers, "x-user-id", nothing)
    session_id = get(headers, "x-session-id", nothing)
    
    return HTTPRequest(
        request.method,
        string(uri.path),
        headers,
        query,
        params,
        body,
        request,
        user_id,
        session_id
    )
end

# ============================================================================
# Router Functions
# ============================================================================

"""
    add_route!(router::Router, method::String, path::String, handler::Function;
               middleware::Vector{Function}=Function[],
               auth_required::Bool=false,
               permissions::Vector{String}=String[],
               description::String="")

Add a route to the router.
"""
function add_route!(router::Router, method::String, path::String, handler::Function;
                   middleware::Vector{Function}=Function[],
                   auth_required::Bool=false,
                   permissions::Vector{String}=String[],
                   description::String="")
    full_path = router.prefix * path
    route = Route(method, full_path, handler, middleware, auth_required, permissions, description)
    push!(router.routes, route)
    return route
end

"""
    use_middleware!(router::Router, middleware::Function)

Add global middleware to the router.
"""
function use_middleware!(router::Router, middleware::Function)
    push!(router.middleware, middleware)
end

# Convenience methods for common HTTP methods
function get!(router::Router, path::String, handler::Function; kwargs...)
    add_route!(router, "GET", path, handler; kwargs...)
end

function post!(router::Router, path::String, handler::Function; kwargs...)
    add_route!(router, "POST", path, handler; kwargs...)
end

function put!(router::Router, path::String, handler::Function; kwargs...)
    add_route!(router, "PUT", path, handler; kwargs...)
end

function patch!(router::Router, path::String, handler::Function; kwargs...)
    add_route!(router, "PATCH", path, handler; kwargs...)
end

function delete!(router::Router, path::String, handler::Function; kwargs...)
    add_route!(router, "DELETE", path, handler; kwargs...)
end

"""
    match_route(router::Router, method::String, path::String) -> Union{Tuple{Route, Dict{String, String}}, Nothing}

Find a matching route for the given method and path.
"""
function match_route(router::Router, method::String, path::String)
    for route in router.routes
        if route.method == method
            params = match_path(route.path, path)
            if !isnothing(params)
                return (route, params)
            end
        end
    end
    return nothing
end

"""
    match_path(pattern::String, path::String) -> Union{Dict{String, String}, Nothing}

Match a path against a pattern with path parameters.
"""
function match_path(pattern::String, path::String)
    pattern_parts = split(pattern, "/"; keepempty=false)
    path_parts = split(path, "/"; keepempty=false)
    
    if length(pattern_parts) != length(path_parts)
        return nothing
    end
    
    params = Dict{String, String}()
    
    for (pattern_part, path_part) in zip(pattern_parts, path_parts)
        if startswith(pattern_part, ":")
            # Path parameter
            param_name = pattern_part[2:end]
            params[param_name] = path_part
        elseif pattern_part != path_part
            return nothing
        end
    end
    
    return params
end

# ============================================================================
# Middleware
# ============================================================================

"""
    cors_middleware(req::HTTPRequest, next::Function) -> HTTPResponse

CORS middleware for cross-origin requests.
"""
function cors_middleware(req::HTTPRequest, next::Function)
    response = next(req)
    
    # Add CORS headers
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-API-Key"
    
    return response
end

"""
    logging_middleware(req::HTTPRequest, next::Function) -> HTTPResponse

Logging middleware for request/response logging.
"""
function logging_middleware(req::HTTPRequest, next::Function)
    start_time = now()
    
    @info "HTTP Request" method=req.method path=req.path
    
    response = next(req)
    
    duration = now() - start_time
    
    @info "HTTP Response" method=req.method path=req.path status=response.status duration=duration
    
    return response
end

"""
    error_handling_middleware(req::HTTPRequest, next::Function) -> HTTPResponse

Error handling middleware.
"""
function error_handling_middleware(req::HTTPRequest, next::Function)
    try
        return next(req)
    catch e
        @error "Request error" exception=e
        
        if e isa HTTP.ExceptionRequest.StatusError
            return error_response(string(e), e.status)
        else
            return error_response("Internal server error: $(string(e))", 500; code="internal_error")
        end
    end
end

"""
    auth_middleware(req::HTTPRequest, next::Function) -> HTTPResponse

Authentication middleware.
"""
function auth_middleware(req::HTTPRequest, next::Function)
    # Check for Authorization header
    auth_header = get(req.headers, "authorization", "")
    api_key_header = get(req.headers, "x-api-key", "")
    
    if startswith(auth_header, "Bearer ")
        # JWT token authentication
        token = auth_header[8:end]
        # Token validation would happen here
        # For now, just pass through
    elseif !isempty(api_key_header)
        # API key authentication
        # API key validation would happen here
    end
    
    return next(req)
end

"""
    rate_limiting_middleware(req::HTTPRequest, next::Function) -> HTTPResponse

Rate limiting middleware.
"""
const RATE_LIMIT_STORE = Dict{String, Tuple{Int, DateTime}}()
const RATE_LIMIT_MAX = 100
const RATE_LIMIT_WINDOW = Minute(1)

function rate_limiting_middleware(req::HTTPRequest, next::Function)
    # Get client identifier (IP or user ID)
    client_id = get(req.headers, "x-forwarded-for", get(req.headers, "x-user-id", "anonymous"))
    
    current_time = now()
    
    if haskey(RATE_LIMIT_STORE, client_id)
        count, window_start = RATE_LIMIT_STORE[client_id]
        
        if current_time - window_start < RATE_LIMIT_WINDOW
            if count >= RATE_LIMIT_MAX
                return HTTPResponse(
                    429,
                    Dict("Content-Type" => "application/json", "Retry-After" => "60"),
                    JSON.json(Dict("error" => true, "message" => "Rate limit exceeded"))
                )
            end
            RATE_LIMIT_STORE[client_id] = (count + 1, window_start)
        else
            RATE_LIMIT_STORE[client_id] = (1, current_time)
        end
    else
        RATE_LIMIT_STORE[client_id] = (1, current_time)
    end
    
    return next(req)
end

# ============================================================================
# Request Handler
# ============================================================================

"""
    handle_request(router::Router, request::HTTP.Request) -> HTTP.Response

Handle an HTTP request using the router.
"""
function handle_request(router::Router, request::HTTP.Request)
    # Handle OPTIONS requests for CORS
    if request.method == "OPTIONS"
        return HTTP.Response(
            204,
            [
                "Access-Control-Allow-Origin" => "*",
                "Access-Control-Allow-Methods" => "GET, POST, PUT, PATCH, DELETE, OPTIONS",
                "Access-Control-Allow-Headers" => "Content-Type, Authorization, X-API-Key"
            ]
        )
    end
    
    # Parse URI
    uri = HTTP.URI(request.target)
    path = string(uri.path)
    
    # Find matching route
    result = match_route(router, request.method, path)
    
    if isnothing(result)
        # No matching route
        response = error_response("Not found: $(request.method) $path", 404; code="not_found")
        return HTTP.Response(response.status, collect(response.headers), response.body)
    end
    
    route, params = result
    
    # Parse request
    parsed_request = parse_request(request, params)
    
    # Build middleware chain
    middleware_chain = vcat(router.middleware, route.middleware)
    
    # Create handler chain
    function run_handler(req::HTTPRequest)
        try
            return route.handler(req)
        catch e
            @error "Handler error" exception=e
            return error_response("Internal server error", 500)
        end
    end
    
    # Apply middleware in reverse order
    handler = run_handler
    for mw in reverse(middleware_chain)
        let current_handler = handler, current_mw = mw
            handler = (req) -> current_mw(req, current_handler)
        end
    end
    
    # Execute handler chain
    response = handler(parsed_request)
    
    # Convert to HTTP.Response
    return HTTP.Response(response.status, collect(response.headers), response.body)
end

# ============================================================================
# Server Management
# ============================================================================

"""
    start_http_server(; host::String="0.0.0.0", port::Int=8080, router::Router=MAIN_ROUTER)

Start the HTTP server.
"""
function start_http_server(; host::String="0.0.0.0", port::Int=8080, router::Router=MAIN_ROUTER)
    if !isnothing(HTTP_SERVER[])
        @warn "HTTP server already running"
        return HTTP_SERVER[]
    end
    
    # Add default middleware
    if isempty(router.middleware)
        use_middleware!(router, error_handling_middleware)
        use_middleware!(router, logging_middleware)
        use_middleware!(router, cors_middleware)
        use_middleware!(router, auth_middleware)
    end
    
    @info "Starting HTTP server" host port
    
    SERVER_TASK[] = @async begin
        HTTP.serve(host, port) do request
            handle_request(router, request)
        end
    end
    
    HTTP_SERVER[] = true  # Mark as running
    
    @info "HTTP server started successfully"
    
    return HTTP_SERVER[]
end

"""
    stop_http_server()

Stop the HTTP server.
"""
function stop_http_server()
    if isnothing(HTTP_SERVER[])
        @warn "HTTP server is not running"
        return false
    end
    
    @info "Stopping HTTP server"
    
    # Note: In a real implementation, we would need to properly close the server
    HTTP_SERVER[] = nothing
    SERVER_TASK[] = nothing
    
    @info "HTTP server stopped"
    
    return true
end

"""
    get_router() -> Router

Get the main router instance.
"""
function get_router()
    return MAIN_ROUTER
end

"""
    reset_router!()

Reset the main router (for testing).
"""
function reset_router!()
    empty!(MAIN_ROUTER.routes)
    empty!(MAIN_ROUTER.middleware)
    empty!(RATE_LIMIT_STORE)
end

# ============================================================================
# OpenAPI Documentation Generation
# ============================================================================

"""
    generate_openapi(router::Router; title::String="JuliaHub API", version::String="1.0.0") -> Dict

Generate OpenAPI specification from router.
"""
function generate_openapi(router::Router; title::String="JuliaHub API", version::String="1.0.0")
    paths = Dict{String, Any}()
    
    for route in router.routes
        path_key = replace(route.path, r":(\w+)" => "{\\1}")
        
        if !haskey(paths, path_key)
            paths[path_key] = Dict{String, Any}()
        end
        
        method_key = lowercase(route.method)
        paths[path_key][method_key] = Dict(
            "summary" => route.description,
            "security" => route.auth_required ? [Dict("bearerAuth" => [])] : [],
            "responses" => Dict(
                "200" => Dict("description" => "Success"),
                "400" => Dict("description" => "Bad request"),
                "401" => Dict("description" => "Unauthorized"),
                "404" => Dict("description" => "Not found"),
                "500" => Dict("description" => "Internal server error")
            )
        )
        
        # Add path parameters
        path_params = []
        for m in eachmatch(r":(\w+)", route.path)
            push!(path_params, Dict(
                "name" => m.captures[1],
                "in" => "path",
                "required" => true,
                "schema" => Dict("type" => "string")
            ))
        end
        
        if !isempty(path_params)
            paths[path_key][method_key]["parameters"] = path_params
        end
    end
    
    return Dict(
        "openapi" => "3.0.0",
        "info" => Dict(
            "title" => title,
            "version" => version,
            "description" => "JuliaHub Server-Side Platform API"
        ),
        "servers" => [
            Dict("url" => "/api/v1", "description" => "API v1")
        ],
        "paths" => paths,
        "components" => Dict(
            "securitySchemes" => Dict(
                "bearerAuth" => Dict(
                    "type" => "http",
                    "scheme" => "bearer",
                    "bearerFormat" => "JWT"
                ),
                "apiKey" => Dict(
                    "type" => "apiKey",
                    "in" => "header",
                    "name" => "X-API-Key"
                )
            )
        )
    )
end

end # module HTTPServer
