"""
APIs and Notification Features module
"""

"""
    APIEndpoint

Represents an API endpoint in the system.
"""
struct APIEndpoint
    id::String
    path::String
    method::String
    description::String
    auth_required::Bool
    rate_limit::Int
    created_at::DateTime
end

"""
    NotificationService

Service for sending notifications to users.
"""
mutable struct NotificationService
    id::String
    name::String
    enabled::Bool
    channels::Vector{String}
    notifications::Vector{Dict{String, Any}}
    
    function NotificationService(name::String; channels::Vector{String}=["email", "webhook"])
        new(
            string(uuid4()),
            name,
            true,
            channels,
            Vector{Dict{String, Any}}()
        )
    end
end

"""
    create_api_endpoint(path::String, method::String, description::String; 
                       auth_required::Bool=true, rate_limit::Int=100)

Register a new API endpoint.
"""
function create_api_endpoint(path::String, method::String, description::String; 
                            auth_required::Bool=true, rate_limit::Int=100)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    endpoint = APIEndpoint(
        string(uuid4()),
        path,
        method,
        description,
        auth_required,
        rate_limit,
        now()
    )
    
    state["api_endpoints"][endpoint.id] = endpoint
    
    @info "Created API endpoint" path method
    
    return endpoint
end

"""
    list_api_endpoints()

List all registered API endpoints.
"""
function list_api_endpoints()
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    return collect(values(state["api_endpoints"]))
end

"""
    create_notification_service(name::String; channels::Vector{String}=["email", "webhook"])

Create a new notification service.
"""
function create_notification_service(name::String; channels::Vector{String}=["email", "webhook"])
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    service = NotificationService(name; channels=channels)
    state["notifications"][service.id] = service
    
    @info "Created notification service" name service.id
    
    return service
end

"""
    send_notification(service_id::String, recipient::String, message::String, 
                     channel::String="email"; priority::String="normal")

Send a notification to a user.
"""
function send_notification(service_id::String, recipient::String, message::String, 
                          channel::String="email"; priority::String="normal")
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    service = get(state["notifications"], service_id, nothing)
    isnothing(service) && error("Notification service not found: $service_id")
    
    if !service.enabled
        @warn "Notification service is disabled" service_id
        return false
    end
    
    if !(channel in service.channels)
        error("Channel not supported: $channel")
    end
    
    notification = Dict{String, Any}(
        "id" => string(uuid4()),
        "recipient" => recipient,
        "message" => message,
        "channel" => channel,
        "priority" => priority,
        "sent_at" => now(),
        "status" => "sent"
    )
    
    push!(service.notifications, notification)
    
    @info "Sent notification" service_id recipient channel
    
    return true
end

"""
    get_notifications(service_id::String; limit::Int=100)

Get recent notifications from a service.
"""
function get_notifications(service_id::String; limit::Int=100)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    service = get(state["notifications"], service_id, nothing)
    isnothing(service) && error("Notification service not found: $service_id")
    
    return service.notifications[max(1, end-limit+1):end]
end
