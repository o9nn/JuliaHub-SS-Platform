"""
    JuliaHub.Server

Server-side platform module for JuliaHub, providing core server infrastructure
and orchestration for all JuliaHub services.

# Features
- **Storage Layer**: Persistent storage with SQLite/PostgreSQL backends
- **HTTP Server**: RESTful API server with routing and middleware
- **Authentication**: User management, JWT, sessions, API keys, RBAC
- **Configuration**: Hierarchical configuration management

# Quick Start
```julia
using JuliaHub

# Start with default configuration
state = JuliaHub.Server.start_server()

# Or with custom configuration
config = JuliaHub.Server.ServerConfig(port=9090, max_workers=20)
state = JuliaHub.Server.start_server(config)

# Start HTTP API server
JuliaHub.Server.start_http_api_server()
```
"""
module Server

using HTTP
using JSON
using Dates
using UUIDs
using SHA
using Base64
using TOML

# Include infrastructure modules
include("storage/Storage.jl")
include("config/Configuration.jl")
include("auth/Authentication.jl")
include("http/HTTPServer.jl")
include("http/routes.jl")

# Make submodules available
using .Storage
using .Configuration
using .Authentication
using .HTTPServer
using .Routes

# Include all server-side feature modules
include("coding_environments.jl")
include("projects.jl")
include("time_capsule.jl")
include("cloudstation.jl")
include("package_registry.jl")
include("dashboard_apps.jl")
include("apis_notifications.jl")
include("code_analysis.jl")
include("traceability_logs.jl")
include("chatgpt_simple.jl")
include("quarto_reports.jl")
include("integrations.jl")

# Export main server types and functions
export ServerConfig, start_server, stop_server, get_server_state
export start_http_api_server, stop_http_api_server

# Export infrastructure modules
export Storage, Configuration, Authentication, HTTPServer

# Export feature types and functions
export CodingEnvironment, PlutoEnvironment, JuliaIDEEnvironment
export Project, TeamProject
export TimeCapsule, create_snapshot, restore_snapshot
export CloudStation, HPCNode, submit_hpc_job
export PackageRegistry, register_package
export DashboardApp, deploy_dashboard
export APIEndpoint, NotificationService
export CodeAnalyzer, run_static_analysis
export TraceabilityLog, ComplianceReport
export ChatGPTService, query_chatgpt
export QuartoReport, render_quarto
export Integration, RStudioIntegration, GitLensIntegration, WindowsWorkstationIntegration

"""
    ServerConfig

Configuration for the JuliaHub server-side platform.
"""
Base.@kwdef struct ServerConfig
    # Basic settings
    host::String = "0.0.0.0"
    port::Int = 8080
    max_workers::Int = 10
    storage_path::String = "./juliahub_storage"
    
    # SSL settings
    enable_ssl::Bool = false
    ssl_cert_path::Union{String, Nothing} = nothing
    ssl_key_path::Union{String, Nothing} = nothing
    
    # Database settings
    db_backend::Symbol = :sqlite
    db_connection_string::String = "juliahub.db"
    
    # Auth settings
    jwt_secret::String = ""
    jwt_expiry_hours::Int = 24
    
    # Logging settings
    log_level::Symbol = :info
    enable_audit_log::Bool = true
    
    # Feature flags
    enable_http_api::Bool = true
    enable_storage::Bool = true
    enable_auth::Bool = true
end

# Global server state
const SERVER_STATE = Ref{Union{Nothing, Dict{String, Any}}}(nothing)
const HTTP_API_SERVER = Ref{Union{Nothing, Any}}(nothing)

"""
    start_server(config::ServerConfig=ServerConfig())

Start the JuliaHub server-side platform with the given configuration.
"""
function start_server(config::ServerConfig=ServerConfig())
    if !isnothing(SERVER_STATE[])
        @warn "Server already running"
        return SERVER_STATE[]
    end
    
    @info "Starting JuliaHub Server-Side Platform" config.host config.port
    
    # Initialize storage directories
    mkpath(config.storage_path)
    mkpath(joinpath(config.storage_path, "time_capsules"))
    mkpath(joinpath(config.storage_path, "projects"))
    mkpath(joinpath(config.storage_path, "dashboards"))
    mkpath(joinpath(config.storage_path, "packages"))
    mkpath(joinpath(config.storage_path, "logs"))
    
    # Initialize persistent storage backend
    storage_backend = if config.enable_storage
        if config.db_backend == :sqlite
            storage_config = Storage.StorageConfig(
                backend = :sqlite,
                connection_string = joinpath(config.storage_path, config.db_connection_string),
                pool_size = 10,
                timeout_seconds = 30
            )
            Storage.SQLiteStorage(storage_config)
        else
            Storage.InMemoryStorage()
        end
    else
        Storage.InMemoryStorage()
    end
    
    # Initialize server state
    SERVER_STATE[] = Dict{String, Any}(
        "config" => config,
        "start_time" => now(),
        "storage" => storage_backend,
        "coding_environments" => Dict{String, Any}(),
        "projects" => Dict{String, Any}(),
        "time_capsules" => Dict{String, Any}(),
        "cloudstation_nodes" => Dict{String, Any}(),
        "package_registries" => Dict{String, Any}(),
        "dashboard_apps" => Dict{String, Any}(),
        "api_endpoints" => Dict{String, Any}(),
        "notifications" => Dict{String, Any}(),
        "code_analysis_results" => Dict{String, Any}(),
        "traceability_logs" => Dict{String, Any}(),
        "chatgpt_sessions" => Dict{String, Any}(),
        "quarto_reports" => Dict{String, Any}(),
        "integrations" => Dict{String, Any}()
    )
    
    @info "JuliaHub Server-Side Platform started successfully"
    
    return SERVER_STATE[]
end

"""
    stop_server()

Stop the JuliaHub server-side platform.
"""
function stop_server()
    if isnothing(SERVER_STATE[])
        @warn "Server is not running"
        return false
    end
    
    @info "Stopping JuliaHub Server-Side Platform"
    
    # Stop HTTP API server if running
    stop_http_api_server()
    
    # Close storage backend if it's a SQLite backend
    storage = get(SERVER_STATE[], "storage", nothing)
    if !isnothing(storage) && storage isa Storage.SQLiteStorage
        Storage.close_storage(storage)
    end
    
    # Clean up resources
    SERVER_STATE[] = nothing
    
    @info "JuliaHub Server-Side Platform stopped successfully"
    
    return true
end

"""
    get_server_state()

Get the current server state. Returns nothing if server is not running.
"""
function get_server_state()
    return SERVER_STATE[]
end

"""
    start_http_api_server(; host::String="0.0.0.0", port::Int=8080)

Start the HTTP REST API server for JuliaHub.
"""
function start_http_api_server(; host::String="0.0.0.0", port::Int=8080)
    if !isnothing(HTTP_API_SERVER[])
        @warn "HTTP API server already running"
        return HTTP_API_SERVER[]
    end
    
    if isnothing(SERVER_STATE[])
        @warn "Server not running. Starting server first..."
        start_server(ServerConfig(host=host, port=port))
    end
    
    @info "Starting HTTP API server" host port
    
    # Create router and register routes
    router = HTTPServer.Router()
    Routes.register_all_routes!(router)
    
    # Create middleware stack
    middlewares = [
        HTTPServer.error_middleware,
        HTTPServer.cors_middleware,
        HTTPServer.logging_middleware,
        # HTTPServer.auth_middleware,  # Uncomment when auth is fully configured
        HTTPServer.rate_limit_middleware
    ]
    
    # Start HTTP server in a task
    HTTP_API_SERVER[] = @async begin
        try
            HTTPServer.start_server(router; 
                host=host, 
                port=port, 
                middlewares=middlewares
            )
        catch e
            @error "HTTP API server error" exception=e
        end
    end
    
    @info "HTTP API server started successfully"
    return HTTP_API_SERVER[]
end

"""
    stop_http_api_server()

Stop the HTTP REST API server.
"""
function stop_http_api_server()
    if isnothing(HTTP_API_SERVER[])
        @info "HTTP API server is not running"
        return false
    end
    
    @info "Stopping HTTP API server"
    
    # Note: HTTP.jl servers need to be stopped by closing the server socket
    # For now, we just set the reference to nothing
    # In production, we would need to properly close the server
    HTTP_API_SERVER[] = nothing
    
    @info "HTTP API server stopped"
    return true
end

"""
    load_config_from_file(filepath::String)

Load server configuration from a TOML file and return a ServerConfig.
"""
function load_config_from_file(filepath::String)
    if !isfile(filepath)
        @warn "Configuration file not found, using defaults" filepath
        return ServerConfig()
    end
    
    server_config = Configuration.load_config(filepath)
    
    return ServerConfig(
        host = server_config.http.host,
        port = server_config.http.port,
        storage_path = server_config.storage_path,
        enable_ssl = server_config.http.enable_ssl,
        ssl_cert_path = server_config.http.ssl_cert_path,
        ssl_key_path = server_config.http.ssl_key_path,
        db_backend = Symbol(server_config.database.backend),
        db_connection_string = server_config.database.connection_string,
        jwt_secret = server_config.auth.jwt_secret,
        jwt_expiry_hours = server_config.auth.jwt_expiry_hours,
        log_level = Symbol(server_config.logging.level),
        enable_audit_log = server_config.logging.enable_audit_log
    )
end

end # module Server
