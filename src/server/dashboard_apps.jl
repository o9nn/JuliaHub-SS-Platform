"""
Dashboard App Development and Web Server module
"""

"""
    DashboardApp

Represents a deployed dashboard application.
"""
struct DashboardApp
    id::String
    name::String
    owner_id::String
    port::Int
    url::String
    status::String
    created_at::DateTime
    updated_at::DateTime
    framework::String
    routes::Vector{String}
end

"""
    deploy_dashboard(name::String, owner_id::String, framework::String="Genie"; port::Int=8000)

Deploy a new dashboard application.
"""
function deploy_dashboard(name::String, owner_id::String, framework::String="Genie"; port::Int=8000)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    dashboard_id = string(uuid4())
    url = "http://localhost:$port"
    
    dashboard = DashboardApp(
        dashboard_id,
        name,
        owner_id,
        port,
        url,
        "deployed",
        now(),
        now(),
        framework,
        ["/", "/dashboard", "/api"]
    )
    
    state["dashboard_apps"][dashboard_id] = dashboard
    
    @info "Deployed dashboard app" name dashboard_id port framework
    
    return dashboard
end

"""
    list_dashboards(owner_id::String)

List all dashboard apps for a user.
"""
function list_dashboards(owner_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    dashboards = filter(state["dashboard_apps"]) do (_, app)
        app.owner_id == owner_id
    end
    
    return collect(values(dashboards))
end

"""
    get_dashboard(dashboard_id::String)

Get dashboard app details.
"""
function get_dashboard(dashboard_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    return get(state["dashboard_apps"], dashboard_id, nothing)
end

"""
    stop_dashboard(dashboard_id::String)

Stop a dashboard application.
"""
function stop_dashboard(dashboard_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    if haskey(state["dashboard_apps"], dashboard_id)
        delete!(state["dashboard_apps"], dashboard_id)
        @info "Stopped dashboard app" dashboard_id
        return true
    end
    
    return false
end

"""
    update_dashboard_routes(dashboard_id::String, routes::Vector{String})

Update the routes for a dashboard application.
"""
function update_dashboard_routes(dashboard_id::String, routes::Vector{String})
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    dashboard = get(state["dashboard_apps"], dashboard_id, nothing)
    isnothing(dashboard) && error("Dashboard not found: $dashboard_id")
    
    # Create new dashboard with updated routes
    updated_dashboard = DashboardApp(
        dashboard.id,
        dashboard.name,
        dashboard.owner_id,
        dashboard.port,
        dashboard.url,
        dashboard.status,
        dashboard.created_at,
        now(),
        dashboard.framework,
        routes
    )
    
    state["dashboard_apps"][dashboard_id] = updated_dashboard
    
    @info "Updated dashboard routes" dashboard_id
    
    return updated_dashboard
end
