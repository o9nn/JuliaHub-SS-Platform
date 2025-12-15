"""
Package and Registry Management Tools module
"""

"""
    PackageRegistry

Represents a Julia package registry.
"""
struct PackageRegistry
    id::String
    name::String
    url::String
    packages::Dict{String, Dict{String, Any}}
    created_at::DateTime
    
    function PackageRegistry(name::String, url::String)
        new(
            string(uuid4()),
            name,
            url,
            Dict{String, Dict{String, Any}}(),
            now()
        )
    end
end

"""
    create_package_registry(name::String, url::String)

Create a new package registry.
"""
function create_package_registry(name::String, url::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    registry = PackageRegistry(name, url)
    state["package_registries"][registry.id] = registry
    
    @info "Created package registry" name registry.id
    
    return registry
end

"""
    register_package(registry_id::String, package_name::String, version::String, 
                    uuid::String, dependencies::Dict{String, String}=Dict{String, String}())

Register a new package in a registry.
"""
function register_package(registry_id::String, package_name::String, version::String, 
                         uuid::String, dependencies::Dict{String, String}=Dict{String, String}())
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    registry = get(state["package_registries"], registry_id, nothing)
    isnothing(registry) && error("Package registry not found: $registry_id")
    
    package_info = Dict{String, Any}(
        "name" => package_name,
        "uuid" => uuid,
        "versions" => Dict(version => Dict(
            "dependencies" => dependencies,
            "registered_at" => now()
        ))
    )
    
    if haskey(registry.packages, package_name)
        # Add new version to existing package
        registry.packages[package_name]["versions"][version] = package_info["versions"][version]
    else
        # Register new package
        registry.packages[package_name] = package_info
    end
    
    @info "Registered package" registry_id package_name version
    
    return true
end

"""
    list_packages(registry_id::String)

List all packages in a registry.
"""
function list_packages(registry_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    registry = get(state["package_registries"], registry_id, nothing)
    isnothing(registry) && error("Package registry not found: $registry_id")
    
    return collect(keys(registry.packages))
end

"""
    get_package_info(registry_id::String, package_name::String)

Get detailed information about a package.
"""
function get_package_info(registry_id::String, package_name::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    registry = get(state["package_registries"], registry_id, nothing)
    isnothing(registry) && error("Package registry not found: $registry_id")
    
    return get(registry.packages, package_name, nothing)
end

"""
    unregister_package(registry_id::String, package_name::String)

Remove a package from a registry.
"""
function unregister_package(registry_id::String, package_name::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    registry = get(state["package_registries"], registry_id, nothing)
    isnothing(registry) && error("Package registry not found: $registry_id")
    
    if haskey(registry.packages, package_name)
        delete!(registry.packages, package_name)
        @info "Unregistered package" registry_id package_name
        return true
    end
    
    return false
end
