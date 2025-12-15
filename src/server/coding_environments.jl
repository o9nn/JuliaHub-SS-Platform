"""
Coding Environments module for Pluto and JuliaIDE
"""

abstract type CodingEnvironment end

"""
    PlutoEnvironment

Pluto notebook environment for interactive computing.
"""
struct PlutoEnvironment <: CodingEnvironment
    id::String
    user_id::String
    notebook_path::String
    port::Int
    status::String
    created_at::DateTime
    
    function PlutoEnvironment(user_id::String, notebook_path::String; port::Int=1234)
        new(
            string(uuid4()),
            user_id,
            notebook_path,
            port,
            "initialized",
            now()
        )
    end
end

"""
    JuliaIDEEnvironment

Full-featured Julia IDE environment.
"""
struct JuliaIDEEnvironment <: CodingEnvironment
    id::String
    user_id::String
    workspace_path::String
    port::Int
    status::String
    created_at::DateTime
    features::Vector{String}
    
    function JuliaIDEEnvironment(user_id::String, workspace_path::String; port::Int=8080)
        new(
            string(uuid4()),
            user_id,
            workspace_path,
            port,
            "initialized",
            now(),
            ["syntax_highlighting", "autocomplete", "debugger", "git_integration"]
        )
    end
end

"""
    create_coding_environment(env_type::Symbol, user_id::String, path::String; kwargs...)

Create a new coding environment (Pluto or JuliaIDE).
"""
function create_coding_environment(env_type::Symbol, user_id::String, path::String; kwargs...)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    env = if env_type == :pluto
        PlutoEnvironment(user_id, path; kwargs...)
    elseif env_type == :julia_ide
        JuliaIDEEnvironment(user_id, path; kwargs...)
    else
        error("Unknown environment type: $env_type")
    end
    
    state["coding_environments"][env.id] = env
    
    @info "Created coding environment" env_type env.id user_id
    
    return env
end

"""
    get_coding_environment(env_id::String)

Get a coding environment by ID.
"""
function get_coding_environment(env_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    return get(state["coding_environments"], env_id, nothing)
end

"""
    list_coding_environments(user_id::String)

List all coding environments for a user.
"""
function list_coding_environments(user_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    envs = filter(state["coding_environments"]) do (_, env)
        env.user_id == user_id
    end
    
    return collect(values(envs))
end

"""
    stop_coding_environment(env_id::String)

Stop a coding environment.
"""
function stop_coding_environment(env_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    if haskey(state["coding_environments"], env_id)
        delete!(state["coding_environments"], env_id)
        @info "Stopped coding environment" env_id
        return true
    end
    
    return false
end
