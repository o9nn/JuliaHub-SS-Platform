"""
    JuliaHub.Server

Server-side platform module for JuliaHub, providing core server infrastructure
and orchestration for all JuliaHub services.
"""
module Server

using HTTP
using JSON
using Dates
using UUIDs

# Include all server-side modules
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
export ServerConfig, start_server, stop_server
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
struct ServerConfig
    host::String
    port::Int
    max_workers::Int
    storage_path::String
    enable_ssl::Bool
    ssl_cert_path::Union{String, Nothing}
    ssl_key_path::Union{String, Nothing}
    
    function ServerConfig(;
        host="0.0.0.0",
        port=8080,
        max_workers=10,
        storage_path="./juliahub_storage",
        enable_ssl=false,
        ssl_cert_path=nothing,
        ssl_key_path=nothing
    )
        new(host, port, max_workers, storage_path, enable_ssl, ssl_cert_path, ssl_key_path)
    end
end

# Global server state
const SERVER_STATE = Ref{Union{Nothing, Dict{String, Any}}}(nothing)

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
    
    # Initialize server state
    SERVER_STATE[] = Dict{String, Any}(
        "config" => config,
        "start_time" => now(),
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

end # module Server
