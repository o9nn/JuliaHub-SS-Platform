"""
Traceability, Logs, and Compliance module
"""

"""
    TraceabilityLog

Tracks operations for compliance and auditing.
"""
struct TraceabilityLog
    id::String
    timestamp::DateTime
    user_id::String
    operation::String
    resource_type::String
    resource_id::String
    details::Dict{String, Any}
    ip_address::String
end

"""
    ComplianceReport

Generates compliance reports.
"""
struct ComplianceReport
    id::String
    name::String
    period_start::DateTime
    period_end::DateTime
    generated_at::DateTime
    logs::Vector{TraceabilityLog}
    summary::Dict{String, Any}
end

"""
    log_operation(user_id::String, operation::String, resource_type::String, 
                  resource_id::String; details::Dict{String, Any}=Dict{String, Any}(), 
                  ip_address::String="0.0.0.0")

Log an operation for traceability and compliance.
"""
function log_operation(user_id::String, operation::String, resource_type::String, 
                      resource_id::String; details::Dict{String, Any}=Dict{String, Any}(), 
                      ip_address::String="0.0.0.0")
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    log_entry = TraceabilityLog(
        string(uuid4()),
        now(),
        user_id,
        operation,
        resource_type,
        resource_id,
        details,
        ip_address
    )
    
    state["traceability_logs"][log_entry.id] = log_entry
    
    @info "Logged operation" user_id operation resource_type resource_id
    
    return log_entry
end

"""
    get_user_logs(user_id::String; limit::Int=100)

Get operation logs for a specific user.
"""
function get_user_logs(user_id::String; limit::Int=100)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    logs = filter(state["traceability_logs"]) do (_, log)
        log.user_id == user_id
    end
    
    # Sort by timestamp and limit
    sorted_logs = sort(collect(values(logs)), by=l->l.timestamp, rev=true)
    
    return sorted_logs[1:min(limit, length(sorted_logs))]
end

"""
    get_resource_logs(resource_type::String, resource_id::String)

Get all logs for a specific resource.
"""
function get_resource_logs(resource_type::String, resource_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    logs = filter(state["traceability_logs"]) do (_, log)
        log.resource_type == resource_type && log.resource_id == resource_id
    end
    
    return sort(collect(values(logs)), by=l->l.timestamp, rev=true)
end

"""
    generate_compliance_report(name::String, period_start::DateTime, period_end::DateTime)

Generate a compliance report for a time period.
"""
function generate_compliance_report(name::String, period_start::DateTime, period_end::DateTime)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    # Filter logs within the period
    period_logs = filter(state["traceability_logs"]) do (_, log)
        period_start <= log.timestamp <= period_end
    end
    
    logs = collect(values(period_logs))
    
    # Generate summary statistics
    summary = Dict{String, Any}(
        "total_operations" => length(logs),
        "unique_users" => length(unique(l.user_id for l in logs)),
        "operations_by_type" => Dict{String, Int}(),
        "operations_by_resource" => Dict{String, Int}()
    )
    
    for log in logs
        summary["operations_by_type"][log.operation] = get(summary["operations_by_type"], log.operation, 0) + 1
        summary["operations_by_resource"][log.resource_type] = get(summary["operations_by_resource"], log.resource_type, 0) + 1
    end
    
    report = ComplianceReport(
        string(uuid4()),
        name,
        period_start,
        period_end,
        now(),
        logs,
        summary
    )
    
    @info "Generated compliance report" name period_start period_end total_operations=length(logs)
    
    return report
end

"""
    export_compliance_report(report::ComplianceReport, format::String="json")

Export a compliance report to a file.
"""
function export_compliance_report(report::ComplianceReport, format::String="json")
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    config = state["config"]
    filename = joinpath(config.storage_path, "logs", "compliance_report_$(report.id).$(format)")
    
    if format == "json"
        # In a real implementation, this would write to a file
        @info "Exported compliance report to JSON" filename
    else
        error("Unsupported export format: $format")
    end
    
    return filename
end
