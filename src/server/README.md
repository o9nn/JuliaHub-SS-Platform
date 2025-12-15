# JuliaHub Server-Side Platform

This directory contains the server-side platform implementation for JuliaHub, providing comprehensive infrastructure for running and managing JuliaHub services.

## Overview

The JuliaHub Server-Side Platform implements all the main features required for a complete JuliaHub deployment:

1. **Pluto and JuliaIDE Coding Environments** - Interactive computing environments
2. **Projects for Team Editing and Collaboration** - Multi-user project management
3. **Time Capsule for Reproducibility** - Environment snapshot and restoration
4. **CloudStation for High Performance Computing Infrastructure** - HPC cluster management
5. **Package and Registry Management Tools** - Julia package registry operations
6. **Dashboard App Development and Web Server** - Deploy and manage web applications
7. **APIs and Notification Features** - REST API endpoints and notification services
8. **Static Code Analysis Guidelines and Tooling** - Code quality and security analysis
9. **Traceability, Logs, Compliance** - Audit logging and compliance reporting
10. **ChatGPT Simple Version** - AI-powered assistance
11. **Quarto Reports** - Generate and manage reports
12. **Integrations** - RStudio, GitLens, and Windows Workstation integrations

## Architecture

The server-side platform is organized into modular components:

```
src/server/
├── Server.jl                  # Main server module
├── coding_environments.jl     # Pluto and JuliaIDE environments
├── projects.jl                # Team collaboration
├── time_capsule.jl           # Reproducibility snapshots
├── cloudstation.jl           # HPC infrastructure
├── package_registry.jl       # Package management
├── dashboard_apps.jl         # Web application hosting
├── apis_notifications.jl     # API and notifications
├── code_analysis.jl          # Static code analysis
├── traceability_logs.jl      # Audit logging
├── chatgpt_simple.jl         # AI assistance
├── quarto_reports.jl         # Report generation
└── integrations.jl           # External tool integrations
```

## Quick Start

### Starting the Server

```julia
using JuliaHub

# Create server configuration
config = JuliaHub.Server.ServerConfig(
    host="0.0.0.0",
    port=8080,
    max_workers=10,
    storage_path="./juliahub_storage"
)

# Start the server
state = JuliaHub.Server.start_server(config)
```

### Creating a Coding Environment

```julia
# Create a Pluto environment
pluto_env = JuliaHub.Server.create_coding_environment(
    :pluto, 
    "user123", 
    "/path/to/notebook.jl",
    port=1234
)

# Create a JuliaIDE environment
ide_env = JuliaHub.Server.create_coding_environment(
    :julia_ide,
    "user456",
    "/path/to/workspace",
    port=8080
)
```

### Managing Team Projects

```julia
# Create a team project
project = JuliaHub.Server.create_team_project(
    "My Project",
    "A collaborative project",
    "owner123"
)

# Add team members
JuliaHub.Server.add_project_member(
    project.project.id,
    "user456",
    ["read", "write"]
)

# Share files
JuliaHub.Server.share_project_file(
    project.project.id,
    "/path/to/shared/file.jl"
)
```

### Time Capsule for Reproducibility

```julia
# Create a snapshot
capsule = JuliaHub.Server.create_snapshot(
    "my-snapshot",
    "user123",
    "Production environment snapshot"
)

# Restore from snapshot
JuliaHub.Server.restore_snapshot(capsule.id)
```

### CloudStation HPC

```julia
# Create a CloudStation
station = JuliaHub.Server.create_cloudstation("HPC Cluster")

# Add HPC nodes
node = JuliaHub.Server.add_hpc_node(
    station.id,
    "node-1",
    cores=64,
    memory_gb=256,
    gpu_count=8
)

# Submit HPC job
job_id = JuliaHub.Server.submit_hpc_job(
    station.id,
    "simulation",
    """
    using Distributed
    @everywhere println("Running on worker")
    """,
    cores=32,
    memory_gb=128
)

# Check job status
status = JuliaHub.Server.get_hpc_job_status(station.id, job_id)
```

### Package Registry Management

```julia
# Create a registry
registry = JuliaHub.Server.create_package_registry(
    "MyRegistry",
    "https://github.com/myorg/registry"
)

# Register a package
JuliaHub.Server.register_package(
    registry.id,
    "MyPackage",
    "1.0.0",
    "pkg-uuid-123",
    Dict("JSON" => "0.21", "HTTP" => "1.0")
)

# List packages
packages = JuliaHub.Server.list_packages(registry.id)
```

### Dashboard Applications

```julia
# Deploy a dashboard
dashboard = JuliaHub.Server.deploy_dashboard(
    "Analytics Dashboard",
    "user123",
    "Genie",
    port=8001
)

# Update routes
JuliaHub.Server.update_dashboard_routes(
    dashboard.id,
    ["/", "/dashboard", "/api", "/admin"]
)
```

### APIs and Notifications

```julia
# Create API endpoint
endpoint = JuliaHub.Server.create_api_endpoint(
    "/api/v1/data",
    "GET",
    "Fetch data endpoint",
    auth_required=true,
    rate_limit=1000
)

# Create notification service
service = JuliaHub.Server.create_notification_service(
    "EmailNotifications",
    channels=["email", "webhook"]
)

# Send notification
JuliaHub.Server.send_notification(
    service.id,
    "user@example.com",
    "Your job has completed",
    "email",
    priority="high"
)
```

### Code Analysis

```julia
# Create analyzer
analyzer = JuliaHub.Server.create_code_analyzer("SecurityAnalyzer")

# Run analysis
result = JuliaHub.Server.run_static_analysis(
    analyzer,
    "/path/to/source.jl"
)

# Get summary
summary = JuliaHub.Server.get_analysis_summary(result.id)
```

### Traceability and Compliance

```julia
# Log operations
JuliaHub.Server.log_operation(
    "user123",
    "create",
    "dataset",
    "dataset-456",
    details=Dict{String, Any}("name" => "Research Data")
)

# Generate compliance report
report = JuliaHub.Server.generate_compliance_report(
    "Q4 2025 Report",
    DateTime(2025, 10, 1),
    DateTime(2025, 12, 31)
)
```

### ChatGPT Service

```julia
# Create ChatGPT service
service = JuliaHub.Server.create_chatgpt_service("AIAssistant")

# Query
response = JuliaHub.Server.query_chatgpt(
    service.id,
    "user123",
    "How do I optimize this Julia code?"
)

# Get chat history
history = JuliaHub.Server.get_chat_history(
    service.id,
    response["session_id"]
)
```

### Quarto Reports

```julia
# Create report
report = JuliaHub.Server.create_quarto_report(
    "Analysis Report",
    "analyst123",
    "/path/to/report.qmd",
    format="html"
)

# Render report
rendered = JuliaHub.Server.render_quarto(report.id, execute=true)

# Export to different format
pdf_path = JuliaHub.Server.export_quarto_report(report.id, "pdf")
```

### Integrations

```julia
# RStudio Integration
rstudio = JuliaHub.Server.create_rstudio_integration(
    "RStudio Server",
    "/workspace",
    r_version="4.3.0",
    port=8787
)

# GitLens Integration
gitlens = JuliaHub.Server.create_gitlens_integration(
    "Project Git",
    "https://github.com/myorg/myproject"
)

# Windows Workstation Integration
windows = JuliaHub.Server.create_windows_workstation_integration(
    "Windows Dev Station",
    "ws.example.com",
    port=3389,
    gpu_support=true
)
```

## Configuration

### Server Configuration Options

- `host`: Server bind address (default: "0.0.0.0")
- `port`: Server port (default: 8080)
- `max_workers`: Maximum concurrent workers (default: 10)
- `storage_path`: Path for persistent storage (default: "./juliahub_storage")
- `enable_ssl`: Enable SSL/TLS (default: false)
- `ssl_cert_path`: Path to SSL certificate
- `ssl_key_path`: Path to SSL key

### Storage Structure

The server creates the following directory structure:

```
juliahub_storage/
├── time_capsules/    # Reproducibility snapshots
├── projects/         # Team project files
├── dashboards/       # Dashboard application data
├── packages/         # Package registry data
└── logs/            # Audit and compliance logs
```

## Testing

Run the comprehensive test suite:

```julia
using Test
include("test/server.jl")
```

The test suite includes 112 tests covering all server-side features.

## Security Considerations

- All operations are logged for audit trails
- Support for SSL/TLS encryption
- Configurable rate limiting for API endpoints
- Authentication requirements for sensitive operations
- Compliance reporting for regulatory requirements

## Performance

- Concurrent request handling with configurable worker pool
- Efficient state management using in-memory structures
- Scalable HPC job queuing system
- Optimized package registry lookups

## Future Enhancements

Planned improvements include:

- Distributed server deployment
- Redis/database backend for state persistence
- WebSocket support for real-time collaboration
- Container orchestration (Kubernetes) integration
- Enhanced security with RBAC
- Metrics and monitoring dashboards
- Advanced load balancing

## Contributing

When adding new features to the server-side platform:

1. Add new module in `src/server/`
2. Include the module in `Server.jl`
3. Export relevant types and functions
4. Add comprehensive tests in `test/server.jl`
5. Update this documentation

## License

See the main LICENSE file in the repository root.
