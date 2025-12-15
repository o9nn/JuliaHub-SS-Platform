"""
Integrations module for RStudio, GitLens, and Windows Workstation
"""

abstract type Integration end

"""
    RStudioIntegration

Integration with RStudio for R language support.
"""
struct RStudioIntegration <: Integration
    id::String
    name::String
    r_version::String
    port::Int
    workspace_path::String
    enabled::Bool
    created_at::DateTime
    
    function RStudioIntegration(name::String, workspace_path::String; 
                                r_version::String="4.3.0", port::Int=8787)
        new(
            string(uuid4()),
            name,
            r_version,
            port,
            workspace_path,
            true,
            now()
        )
    end
end

"""
    GitLensIntegration

Integration with GitLens for enhanced Git functionality.
"""
struct GitLensIntegration <: Integration
    id::String
    name::String
    repository_url::String
    features::Vector{String}
    enabled::Bool
    created_at::DateTime
    
    function GitLensIntegration(name::String, repository_url::String)
        new(
            string(uuid4()),
            name,
            repository_url,
            ["blame_annotations", "code_lens", "file_history", "branch_comparison"],
            true,
            now()
        )
    end
end

"""
    WindowsWorkstationIntegration

Integration with Windows Workstation for remote desktop access.
"""
struct WindowsWorkstationIntegration <: Integration
    id::String
    name::String
    hostname::String
    port::Int
    rdp_enabled::Bool
    gpu_support::Bool
    enabled::Bool
    created_at::DateTime
    
    function WindowsWorkstationIntegration(name::String, hostname::String; 
                                          port::Int=3389, rdp_enabled::Bool=true, 
                                          gpu_support::Bool=false)
        new(
            string(uuid4()),
            name,
            hostname,
            port,
            rdp_enabled,
            gpu_support,
            true,
            now()
        )
    end
end

"""
    create_rstudio_integration(name::String, workspace_path::String; kwargs...)

Create an RStudio integration.
"""
function create_rstudio_integration(name::String, workspace_path::String; kwargs...)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    integration = RStudioIntegration(name, workspace_path; kwargs...)
    state["integrations"][integration.id] = integration
    
    @info "Created RStudio integration" name integration.id
    
    return integration
end

"""
    create_gitlens_integration(name::String, repository_url::String)

Create a GitLens integration.
"""
function create_gitlens_integration(name::String, repository_url::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    integration = GitLensIntegration(name, repository_url)
    state["integrations"][integration.id] = integration
    
    @info "Created GitLens integration" name integration.id repository_url
    
    return integration
end

"""
    create_windows_workstation_integration(name::String, hostname::String; kwargs...)

Create a Windows Workstation integration.
"""
function create_windows_workstation_integration(name::String, hostname::String; kwargs...)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    integration = WindowsWorkstationIntegration(name, hostname; kwargs...)
    state["integrations"][integration.id] = integration
    
    @info "Created Windows Workstation integration" name integration.id hostname
    
    return integration
end

"""
    list_integrations()

List all active integrations.
"""
function list_integrations()
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    return collect(values(state["integrations"]))
end

"""
    get_integration(integration_id::String)

Get details of a specific integration.
"""
function get_integration(integration_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    return get(state["integrations"], integration_id, nothing)
end

"""
    disable_integration(integration_id::String)

Disable an integration.
"""
function disable_integration(integration_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    integration = get(state["integrations"], integration_id, nothing)
    isnothing(integration) && error("Integration not found: $integration_id")
    
    # Create new integration with disabled status
    disabled_integration = if integration isa RStudioIntegration
        RStudioIntegration(
            integration.id,
            integration.name,
            integration.r_version,
            integration.port,
            integration.workspace_path,
            false,
            integration.created_at
        )
    elseif integration isa GitLensIntegration
        GitLensIntegration(
            integration.id,
            integration.name,
            integration.repository_url,
            integration.features,
            false,
            integration.created_at
        )
    elseif integration isa WindowsWorkstationIntegration
        WindowsWorkstationIntegration(
            integration.id,
            integration.name,
            integration.hostname,
            integration.port,
            integration.rdp_enabled,
            integration.gpu_support,
            false,
            integration.created_at
        )
    else
        error("Unknown integration type")
    end
    
    state["integrations"][integration_id] = disabled_integration
    
    @info "Disabled integration" integration_id
    
    return true
end

"""
    delete_integration(integration_id::String)

Delete an integration.
"""
function delete_integration(integration_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    if haskey(state["integrations"], integration_id)
        delete!(state["integrations"], integration_id)
        @info "Deleted integration" integration_id
        return true
    end
    
    return false
end

# Helper constructor functions for disabled integrations
function RStudioIntegration(id::String, name::String, r_version::String, port::Int, 
                           workspace_path::String, enabled::Bool, created_at::DateTime)
    new_integration = RStudioIntegration(name, workspace_path; r_version=r_version, port=port)
    return RStudioIntegration(
        id,
        name,
        r_version,
        port,
        workspace_path,
        enabled,
        created_at
    )
end

function GitLensIntegration(id::String, name::String, repository_url::String, 
                           features::Vector{String}, enabled::Bool, created_at::DateTime)
    GitLensIntegration(
        id,
        name,
        repository_url,
        features,
        enabled,
        created_at
    )
end

function WindowsWorkstationIntegration(id::String, name::String, hostname::String, port::Int, 
                                       rdp_enabled::Bool, gpu_support::Bool, enabled::Bool, 
                                       created_at::DateTime)
    WindowsWorkstationIntegration(
        id,
        name,
        hostname,
        port,
        rdp_enabled,
        gpu_support,
        enabled,
        created_at
    )
end
