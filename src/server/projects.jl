"""
Projects module for team editing and collaboration
"""

"""
    Project

Base project structure for team collaboration.
"""
struct Project
    id::String
    name::String
    description::String
    owner_id::String
    created_at::DateTime
    updated_at::DateTime
end

"""
    TeamProject

Extended project with team collaboration features.
"""
mutable struct TeamProject
    project::Project
    members::Vector{String}
    permissions::Dict{String, Vector{String}}
    shared_files::Vector{String}
    active_sessions::Dict{String, DateTime}
    
    function TeamProject(name::String, description::String, owner_id::String)
        project = Project(
            string(uuid4()),
            name,
            description,
            owner_id,
            now(),
            now()
        )
        new(
            project,
            [owner_id],
            Dict(owner_id => ["read", "write", "admin"]),
            String[],
            Dict{String, DateTime}()
        )
    end
end

"""
    create_team_project(name::String, description::String, owner_id::String)

Create a new team project.
"""
function create_team_project(name::String, description::String, owner_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    team_project = TeamProject(name, description, owner_id)
    state["projects"][team_project.project.id] = team_project
    
    @info "Created team project" name team_project.project.id
    
    return team_project
end

"""
    add_project_member(project_id::String, user_id::String, permissions::Vector{String}=["read"])

Add a member to a team project.
"""
function add_project_member(project_id::String, user_id::String, permissions::Vector{String}=["read"])
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    project = get(state["projects"], project_id, nothing)
    isnothing(project) && error("Project not found: $project_id")
    
    if !(user_id in project.members)
        push!(project.members, user_id)
        project.permissions[user_id] = permissions
        @info "Added member to project" project_id user_id
        return true
    end
    
    return false
end

"""
    list_team_projects(user_id::String)

List all team projects a user is a member of.
"""
function list_team_projects(user_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    projects = filter(state["projects"]) do (_, proj)
        user_id in proj.members
    end
    
    return collect(values(projects))
end

"""
    share_project_file(project_id::String, file_path::String)

Share a file in a team project.
"""
function share_project_file(project_id::String, file_path::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    project = get(state["projects"], project_id, nothing)
    isnothing(project) && error("Project not found: $project_id")
    
    if !(file_path in project.shared_files)
        push!(project.shared_files, file_path)
        @info "Shared file in project" project_id file_path
        return true
    end
    
    return false
end
