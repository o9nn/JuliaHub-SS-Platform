"""
CloudStation module for High Performance Computing infrastructure
"""

"""
    HPCNode

Represents a node in the HPC cluster.
"""
struct HPCNode
    id::String
    name::String
    cores::Int
    memory_gb::Int
    gpu_count::Int
    status::String
    created_at::DateTime
end

"""
    CloudStation

HPC infrastructure management.
"""
mutable struct CloudStation
    id::String
    name::String
    nodes::Vector{HPCNode}
    active_jobs::Dict{String, Dict{String, Any}}
    queue::Vector{Dict{String, Any}}
    max_concurrent_jobs::Int
    
    function CloudStation(name::String; max_concurrent_jobs::Int=100)
        new(
            string(uuid4()),
            name,
            HPCNode[],
            Dict{String, Dict{String, Any}}(),
            Vector{Dict{String, Any}}(),
            max_concurrent_jobs
        )
    end
end

"""
    create_cloudstation(name::String)

Create a new CloudStation HPC infrastructure.
"""
function create_cloudstation(name::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    station = CloudStation(name)
    state["cloudstation_nodes"][station.id] = station
    
    @info "Created CloudStation" name station.id
    
    return station
end

"""
    add_hpc_node(station_id::String, name::String, cores::Int, memory_gb::Int, gpu_count::Int=0)

Add a new HPC node to a CloudStation.
"""
function add_hpc_node(station_id::String, name::String, cores::Int, memory_gb::Int, gpu_count::Int=0)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    station = get(state["cloudstation_nodes"], station_id, nothing)
    isnothing(station) && error("CloudStation not found: $station_id")
    
    node = HPCNode(
        string(uuid4()),
        name,
        cores,
        memory_gb,
        gpu_count,
        "available",
        now()
    )
    
    push!(station.nodes, node)
    
    @info "Added HPC node to CloudStation" station_id name node.id
    
    return node
end

"""
    submit_hpc_job(station_id::String, job_name::String, script::String; 
                   cores::Int=1, memory_gb::Int=4, gpu_count::Int=0)

Submit a job to the HPC CloudStation.
"""
function submit_hpc_job(station_id::String, job_name::String, script::String; 
                        cores::Int=1, memory_gb::Int=4, gpu_count::Int=0)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    station = get(state["cloudstation_nodes"], station_id, nothing)
    isnothing(station) && error("CloudStation not found: $station_id")
    
    job_id = string(uuid4())
    job = Dict{String, Any}(
        "id" => job_id,
        "name" => job_name,
        "script" => script,
        "cores" => cores,
        "memory_gb" => memory_gb,
        "gpu_count" => gpu_count,
        "status" => "queued",
        "submitted_at" => now()
    )
    
    push!(station.queue, job)
    
    @info "Submitted HPC job" station_id job_name job_id
    
    return job_id
end

"""
    get_hpc_job_status(station_id::String, job_id::String)

Get the status of an HPC job.
"""
function get_hpc_job_status(station_id::String, job_id::String)
    state = get_server_state()
    isnothing(state) && error("Server is not running")
    
    station = get(state["cloudstation_nodes"], station_id, nothing)
    isnothing(station) && error("CloudStation not found: $station_id")
    
    # Check active jobs
    if haskey(station.active_jobs, job_id)
        return station.active_jobs[job_id]["status"]
    end
    
    # Check queue
    job = findfirst(j -> j["id"] == job_id, station.queue)
    if !isnothing(job)
        return "queued"
    end
    
    return "not_found"
end
