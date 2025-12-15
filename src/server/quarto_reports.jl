"""
Quarto Reports module
"""

"""
    QuartoReport

Represents a Quarto report document.
"""
struct QuartoReport
    id::String
    name::String
    author::String
    format::String
    source_path::String
    output_path::String
    status::String
    created_at::DateTime
    rendered_at::Union{DateTime, Nothing}
    metadata::Dict{String, Any}
end

"""
    create_quarto_report(name::String, author::String, source_path::String; 
                        format::String="html")

Create a new Quarto report.
"""
function create_quarto_report(name::String, author::String, source_path::String; 
                             format::String="html")
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    report_id = string(uuid4())
    output_path = joinpath(state["config"].storage_path, "reports", "$(report_id).$(format)")
    
    report = QuartoReport(
        report_id,
        name,
        author,
        format,
        source_path,
        output_path,
        "created",
        now(),
        nothing,
        Dict{String, Any}()
    )
    
    state["quarto_reports"][report_id] = report
    
    @info "Created Quarto report" name report_id format
    
    return report
end

"""
    render_quarto(report_id::String; execute::Bool=true)

Render a Quarto report to the specified output format.
"""
function render_quarto(report_id::String; execute::Bool=true)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    report = get(state["quarto_reports"], report_id, nothing)
    isnothing(report) && error("Quarto report not found: $report_id")
    
    @info "Rendering Quarto report" report_id report.name report.format execute
    
    # In a real implementation, this would:
    # 1. Execute code blocks if execute=true
    # 2. Process markdown and code
    # 3. Generate output in specified format
    # 4. Save to output_path
    
    # Update report with rendering info
    rendered_report = QuartoReport(
        report.id,
        report.name,
        report.author,
        report.format,
        report.source_path,
        report.output_path,
        "rendered",
        report.created_at,
        now(),
        merge(report.metadata, Dict("executed" => execute))
    )
    
    state["quarto_reports"][report_id] = rendered_report
    
    @info "Quarto report rendered successfully" report_id
    
    return rendered_report
end

"""
    list_quarto_reports(author::String)

List all Quarto reports by an author.
"""
function list_quarto_reports(author::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    reports = filter(state["quarto_reports"]) do (_, report)
        report.author == author
    end
    
    return collect(values(reports))
end

"""
    get_quarto_report(report_id::String)

Get details of a Quarto report.
"""
function get_quarto_report(report_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    return get(state["quarto_reports"], report_id, nothing)
end

"""
    delete_quarto_report(report_id::String)

Delete a Quarto report.
"""
function delete_quarto_report(report_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    if haskey(state["quarto_reports"], report_id)
        delete!(state["quarto_reports"], report_id)
        @info "Deleted Quarto report" report_id
        return true
    end
    
    return false
end

"""
    export_quarto_report(report_id::String, export_format::String)

Export a Quarto report to a different format.
"""
function export_quarto_report(report_id::String, export_format::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    report = get(state["quarto_reports"], report_id, nothing)
    isnothing(report) && error("Quarto report not found: $report_id")
    
    if report.status != "rendered"
        error("Report must be rendered before exporting")
    end
    
    export_path = replace(report.output_path, report.format => export_format)
    
    @info "Exporting Quarto report" report_id export_format export_path
    
    # In a real implementation, this would convert the report to the new format
    
    return export_path
end
