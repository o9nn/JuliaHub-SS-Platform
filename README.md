# JuliaHub.jl ![BETA][beta-badge]

[![Version][jh-version-img]][jh-version-url]
[![][docs-stable-img]][docs-stable-url]
[![][gha-img]][gha-url]
[![PkgEval][pkgeval-img]][pkgeval-url]
[![][codecov-img]][codecov-url]

A Julia client for the [JuliaHub platform][juliahub-com] APIs, with comprehensive server-side platform support.
It allows you to programmatically interact with the platform to, for example, upload or download datasets, start jobs, and so on.

This package now includes a complete server-side platform implementation for running your own JuliaHub instance.

## Client-Side Usage

The package is an open-source and available in the [Julia General registry](https://github.com/JuliaRegistries/General), and can simply be installed via the package manager.

```
pkg> add JuliaHub
```

To get started, you must first authenticate with a JuliaHub instance.
The package can be used to interact with both `juliahub.com` and enterprise instances.

```julia
using JuliaHub
JuliaHub.authenticate("juliahub.com")
```

Once your session is authenticated, you can start interacting with the JuliaHub instance.
For example, to list datasets you can call `JuliaHub.datasets()` or to upload a new dataset you can call

```julia
JuliaHub.upload_dataset("my-new-dataset", "local/file.csv")
```

Or you can also start JuliaHub jobs to offload computations to the cloud.

```julia
JuliaHub.submit_job(
    JuliaHub.script"""
    Hello JuliaHub!
    """
)
```

## Server-Side Platform

The package now includes a comprehensive server-side platform for running your own JuliaHub instance with all major features:

- **Pluto and JuliaIDE Coding Environments** - Interactive computing
- **Projects for Team Editing and Collaboration** - Multi-user collaboration
- **Time Capsule for Reproducibility** - Environment snapshots
- **CloudStation for HPC Infrastructure** - High-performance computing cluster management
- **Package and Registry Management** - Julia package registry
- **Dashboard App Development** - Web application hosting
- **APIs and Notification Features** - REST APIs and notifications
- **Static Code Analysis** - Code quality and security
- **Traceability, Logs, Compliance** - Audit trails and compliance
- **ChatGPT Simple Version** - AI-powered assistance
- **Quarto Reports** - Report generation and management
- **Integrations** - RStudio, GitLens, Windows Workstation

### Quick Start - Server

```julia
using JuliaHub

# Start the server
config = JuliaHub.Server.ServerConfig(port=8080)
state = JuliaHub.Server.start_server(config)

# Create a coding environment
env = JuliaHub.Server.create_coding_environment(:pluto, "user123", "/notebook.jl")

# Create a team project
project = JuliaHub.Server.create_team_project("My Project", "Description", "owner123")

# Deploy a dashboard
dashboard = JuliaHub.Server.deploy_dashboard("Analytics", "user123", "Genie")
```

See the [Server Platform Documentation](src/server/README.md) for comprehensive usage examples and API reference.

## Documentation

See [the documentation over at `help.juliahub.com`][docs-stable-url] for a more information on usage, guides, tutorials, and the reference manual.
If you are curious about changes and updates that new version have brought, see the [CHANGELOG][docs-stable-changelog-url].


[juliahub-com]: http://juliahub.com/

[beta-badge]: https://img.shields.io/badge/-BETA-blue.svg

[jh-version-img]: https://juliahub.com/docs/JuliaHub/version.svg
[jh-version-url]: https://juliahub.com/ui/Packages/JuliaHub/B9bPq/

[docs-stable-img]: https://img.shields.io/badge/docs-help.juliahub.com-blue.svg
[docs-stable-url]: https://help.juliahub.com/julia-api/stable/
<!-- [docs-stable-changelog-url]: https://help.juliahub.com/julia-api/stable/CHANGELOG/ -->
[docs-stable-changelog-url]: CHANGELOG.md

[gha-img]: https://github.com/JuliaComputing/JuliaHub.jl/workflows/CI/badge.svg
[gha-url]: https://github.com/JuliaComputing/JuliaHub.jl/actions?query=workflows/CI

[pkgeval-img]: https://juliahub.com/docs/JuliaHub/pkgeval.svg
[pkgeval-url]: https://juliahub.com/ui/Packages/JuliaHub/B9bPq

[codecov-img]: https://codecov.io/gh/JuliaComputing/JuliaHub.jl/branch/main/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaComputing/JuliaHub.jl
