using Test
using JuliaHub
using Dates

@testset "Server-Side Platform" begin
    @testset "Server Initialization" begin
        # Test server configuration
        config = JuliaHub.Server.ServerConfig(
            host="127.0.0.1",
            port=9090,
            max_workers=5,
            storage_path="/tmp/juliahub_test"
        )
        
        @test config.host == "127.0.0.1"
        @test config.port == 9090
        @test config.max_workers == 5
        @test config.enable_ssl == false
        
        # Test server start
        state = JuliaHub.Server.start_server(config)
        @test !isnothing(state)
        @test haskey(state, "config")
        @test haskey(state, "coding_environments")
        @test haskey(state, "projects")
        
        # Test server already running warning
        state2 = JuliaHub.Server.start_server(config)
        @test state2 === state
        
        # Test get server state
        @test JuliaHub.Server.get_server_state() === state
        
        # Test server stop
        @test JuliaHub.Server.stop_server() == true
        @test isnothing(JuliaHub.Server.get_server_state())
        
        # Test stop when not running
        @test JuliaHub.Server.stop_server() == false
    end
    
    @testset "Coding Environments" begin
        config = JuliaHub.Server.ServerConfig(storage_path="/tmp/juliahub_test_envs")
        JuliaHub.Server.start_server(config)
        
        # Test Pluto environment creation
        pluto_env = JuliaHub.Server.create_coding_environment(
            :pluto, "user123", "/path/to/notebook.jl", port=1234
        )
        @test pluto_env isa JuliaHub.Server.PlutoEnvironment
        @test pluto_env.user_id == "user123"
        @test pluto_env.port == 1234
        @test pluto_env.status == "initialized"
        
        # Test JuliaIDE environment creation
        ide_env = JuliaHub.Server.create_coding_environment(
            :julia_ide, "user456", "/path/to/workspace", port=8080
        )
        @test ide_env isa JuliaHub.Server.JuliaIDEEnvironment
        @test ide_env.user_id == "user456"
        @test "debugger" in ide_env.features
        
        # Test get environment
        retrieved_env = JuliaHub.Server.get_coding_environment(pluto_env.id)
        @test retrieved_env === pluto_env
        
        # Test list environments
        envs = JuliaHub.Server.list_coding_environments("user123")
        @test length(envs) == 1
        @test envs[1] === pluto_env
        
        # Test stop environment
        @test JuliaHub.Server.stop_coding_environment(pluto_env.id) == true
        @test isnothing(JuliaHub.Server.get_coding_environment(pluto_env.id))
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Team Projects" begin
        JuliaHub.Server.start_server()
        
        # Test project creation
        project = JuliaHub.Server.create_team_project(
            "Test Project", "A test project", "owner123"
        )
        @test project isa JuliaHub.Server.TeamProject
        @test project.project.name == "Test Project"
        @test "owner123" in project.members
        @test haskey(project.permissions, "owner123")
        
        # Test add member
        @test JuliaHub.Server.add_project_member(
            project.project.id, "user456", ["read", "write"]
        ) == true
        @test "user456" in project.members
        @test project.permissions["user456"] == ["read", "write"]
        
        # Test list projects
        projects = JuliaHub.Server.list_team_projects("owner123")
        @test length(projects) >= 1
        
        # Test share file
        @test JuliaHub.Server.share_project_file(
            project.project.id, "/path/to/file.jl"
        ) == true
        @test "/path/to/file.jl" in project.shared_files
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Time Capsule" begin
        JuliaHub.Server.start_server()
        
        # Test snapshot creation
        capsule = JuliaHub.Server.create_snapshot(
            "test-snapshot", "user123", "Test description"
        )
        @test capsule isa JuliaHub.Server.TimeCapsule
        @test capsule.name == "test-snapshot"
        @test capsule.user_id == "user123"
        
        # Test restore snapshot
        restored = JuliaHub.Server.restore_snapshot(capsule.id)
        @test restored === capsule
        
        # Test list capsules
        capsules = JuliaHub.Server.list_time_capsules("user123")
        @test length(capsules) == 1
        
        # Test delete capsule
        @test JuliaHub.Server.delete_time_capsule(capsule.id) == true
        @test length(JuliaHub.Server.list_time_capsules("user123")) == 0
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "CloudStation HPC" begin
        JuliaHub.Server.start_server()
        
        # Test CloudStation creation
        station = JuliaHub.Server.create_cloudstation("Test HPC Cluster")
        @test station isa JuliaHub.Server.CloudStation
        @test station.name == "Test HPC Cluster"
        
        # Test add HPC node
        node = JuliaHub.Server.add_hpc_node(
            station.id, "node-1", 32, 128, 4
        )
        @test node isa JuliaHub.Server.HPCNode
        @test node.cores == 32
        @test node.memory_gb == 128
        @test node.gpu_count == 4
        
        # Test submit HPC job
        job_id = JuliaHub.Server.submit_hpc_job(
            station.id, "test-job", "println(\"Hello HPC\")",
            cores=8, memory_gb=32
        )
        @test !isempty(job_id)
        
        # Test get job status
        status = JuliaHub.Server.get_hpc_job_status(station.id, job_id)
        @test status == "queued"
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Package Registry" begin
        JuliaHub.Server.start_server()
        
        # Test registry creation
        registry = JuliaHub.Server.create_package_registry(
            "TestRegistry", "https://github.com/test/registry"
        )
        @test registry isa JuliaHub.Server.PackageRegistry
        @test registry.name == "TestRegistry"
        
        # Test register package
        @test JuliaHub.Server.register_package(
            registry.id, "TestPackage", "1.0.0", "test-uuid-123",
            Dict("JSON" => "0.21")
        ) == true
        
        # Test list packages
        packages = JuliaHub.Server.list_packages(registry.id)
        @test "TestPackage" in packages
        
        # Test get package info
        info = JuliaHub.Server.get_package_info(registry.id, "TestPackage")
        @test !isnothing(info)
        @test haskey(info["versions"], "1.0.0")
        
        # Test unregister package
        @test JuliaHub.Server.unregister_package(registry.id, "TestPackage") == true
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Dashboard Apps" begin
        JuliaHub.Server.start_server()
        
        # Test deploy dashboard
        dashboard = JuliaHub.Server.deploy_dashboard(
            "TestDashboard", "user123", "Genie", port=8001
        )
        @test dashboard isa JuliaHub.Server.DashboardApp
        @test dashboard.name == "TestDashboard"
        @test dashboard.port == 8001
        @test dashboard.status == "deployed"
        
        # Test list dashboards
        dashboards = JuliaHub.Server.list_dashboards("user123")
        @test length(dashboards) == 1
        
        # Test get dashboard
        retrieved = JuliaHub.Server.get_dashboard(dashboard.id)
        @test retrieved === dashboard
        
        # Test update routes
        updated = JuliaHub.Server.update_dashboard_routes(
            dashboard.id, ["/", "/api", "/admin"]
        )
        @test "/admin" in updated.routes
        
        # Test stop dashboard
        @test JuliaHub.Server.stop_dashboard(dashboard.id) == true
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "APIs and Notifications" begin
        JuliaHub.Server.start_server()
        
        # Test create API endpoint
        endpoint = JuliaHub.Server.create_api_endpoint(
            "/api/v1/test", "GET", "Test endpoint",
            auth_required=true, rate_limit=100
        )
        @test endpoint isa JuliaHub.Server.APIEndpoint
        @test endpoint.path == "/api/v1/test"
        @test endpoint.method == "GET"
        
        # Test list endpoints
        endpoints = JuliaHub.Server.list_api_endpoints()
        @test length(endpoints) >= 1
        
        # Test create notification service
        service = JuliaHub.Server.create_notification_service(
            "TestNotifications", channels=["email", "webhook"]
        )
        @test service isa JuliaHub.Server.NotificationService
        @test service.enabled == true
        
        # Test send notification
        @test JuliaHub.Server.send_notification(
            service.id, "user@test.com", "Test message", "email"
        ) == true
        
        # Test get notifications
        notifications = JuliaHub.Server.get_notifications(service.id)
        @test length(notifications) == 1
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Code Analysis" begin
        JuliaHub.Server.start_server()
        
        # Test create analyzer
        analyzer = JuliaHub.Server.create_code_analyzer("TestAnalyzer")
        @test analyzer isa JuliaHub.Server.CodeAnalyzer
        @test "unused_variables" in analyzer.rules
        
        # Test run analysis
        result = JuliaHub.Server.run_static_analysis(analyzer, "/path/to/file.jl")
        @test result isa JuliaHub.Server.AnalysisResult
        @test haskey(result.metrics, "lines_of_code")
        
        # Test get analysis summary
        summary = JuliaHub.Server.get_analysis_summary(result.id)
        @test haskey(summary, "total_issues")
        @test haskey(summary, "metrics")
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Traceability and Compliance" begin
        JuliaHub.Server.start_server()
        
        # Test log operation
        log = JuliaHub.Server.log_operation(
            "user123", "create", "project", "proj-456",
            details=Dict{String, Any}("name" => "Test Project")
        )
        @test log isa JuliaHub.Server.TraceabilityLog
        @test log.user_id == "user123"
        @test log.operation == "create"
        
        # Test get user logs
        logs = JuliaHub.Server.get_user_logs("user123")
        @test length(logs) >= 1
        
        # Test get resource logs
        resource_logs = JuliaHub.Server.get_resource_logs("project", "proj-456")
        @test length(resource_logs) >= 1
        
        # Test generate compliance report
        report = JuliaHub.Server.generate_compliance_report(
            "Test Report",
            now() - Day(7),
            now()
        )
        @test report isa JuliaHub.Server.ComplianceReport
        @test haskey(report.summary, "total_operations")
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "ChatGPT Service" begin
        JuliaHub.Server.start_server()
        
        # Test create service
        service = JuliaHub.Server.create_chatgpt_service("TestChatGPT")
        @test service isa JuliaHub.Server.ChatGPTService
        @test service.model == "gpt-3.5-turbo"
        
        # Test query
        response = JuliaHub.Server.query_chatgpt(
            service.id, "user123", "Hello, how are you?"
        )
        @test haskey(response, "response")
        @test haskey(response, "session_id")
        
        session_id = response["session_id"]
        
        # Test get history
        history = JuliaHub.Server.get_chat_history(service.id, session_id)
        @test length(history) >= 2  # user + assistant
        
        # Test list sessions
        sessions = JuliaHub.Server.list_chat_sessions(service.id)
        @test session_id in sessions
        
        # Test clear session
        @test JuliaHub.Server.clear_chat_session(service.id, session_id) == true
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Quarto Reports" begin
        JuliaHub.Server.start_server()
        
        # Test create report
        report = JuliaHub.Server.create_quarto_report(
            "TestReport", "author123", "/path/to/source.qmd",
            format="html"
        )
        @test report isa JuliaHub.Server.QuartoReport
        @test report.name == "TestReport"
        @test report.status == "created"
        
        # Test render report
        rendered = JuliaHub.Server.render_quarto(report.id, execute=true)
        @test rendered.status == "rendered"
        @test !isnothing(rendered.rendered_at)
        
        # Test list reports
        reports = JuliaHub.Server.list_quarto_reports("author123")
        @test length(reports) >= 1
        
        # Test get report
        retrieved = JuliaHub.Server.get_quarto_report(report.id)
        @test retrieved.id == report.id
        
        # Test delete report
        @test JuliaHub.Server.delete_quarto_report(report.id) == true
        
        JuliaHub.Server.stop_server()
    end
    
    @testset "Integrations" begin
        JuliaHub.Server.start_server()
        
        # Test RStudio integration
        rstudio = JuliaHub.Server.create_rstudio_integration(
            "TestRStudio", "/workspace", r_version="4.3.0", port=8787
        )
        @test rstudio isa JuliaHub.Server.RStudioIntegration
        @test rstudio.r_version == "4.3.0"
        @test rstudio.enabled == true
        
        # Test GitLens integration
        gitlens = JuliaHub.Server.create_gitlens_integration(
            "TestGitLens", "https://github.com/test/repo"
        )
        @test gitlens isa JuliaHub.Server.GitLensIntegration
        @test "blame_annotations" in gitlens.features
        
        # Test Windows Workstation integration
        windows = JuliaHub.Server.create_windows_workstation_integration(
            "TestWindows", "ws-host-1", port=3389, gpu_support=true
        )
        @test windows isa JuliaHub.Server.WindowsWorkstationIntegration
        @test windows.gpu_support == true
        
        # Test list integrations
        integrations = JuliaHub.Server.list_integrations()
        @test length(integrations) == 3
        
        # Test get integration
        retrieved = JuliaHub.Server.get_integration(rstudio.id)
        @test retrieved.id == rstudio.id
        
        # Test delete integration
        @test JuliaHub.Server.delete_integration(gitlens.id) == true
        @test length(JuliaHub.Server.list_integrations()) == 2
        
        JuliaHub.Server.stop_server()
    end
    
    # Phase 1: Core Infrastructure Tests
    @testset "Storage Module" begin
        # Test InMemoryStorage
        storage = JuliaHub.Server.Storage.InMemoryStorage()
        @test storage isa JuliaHub.Server.Storage.AbstractStorage
        
        # Test store and retrieve
        JuliaHub.Server.Storage.store!(storage, "users", "user1", Dict("name" => "Alice", "email" => "alice@test.com"))
        result = JuliaHub.Server.Storage.retrieve(storage, "users", "user1")
        @test result["name"] == "Alice"
        @test result["email"] == "alice@test.com"
        
        # Test retrieve non-existent
        @test isnothing(JuliaHub.Server.Storage.retrieve(storage, "users", "nonexistent"))
        
        # Test update
        JuliaHub.Server.Storage.store!(storage, "users", "user1", Dict("name" => "Alice Updated", "email" => "alice@test.com"))
        updated = JuliaHub.Server.Storage.retrieve(storage, "users", "user1")
        @test updated["name"] == "Alice Updated"
        
        # Test exists
        @test JuliaHub.Server.Storage.exists(storage, "users", "user1") == true
        @test JuliaHub.Server.Storage.exists(storage, "users", "nonexistent") == false
        
        # Test list_all
        JuliaHub.Server.Storage.store!(storage, "users", "user2", Dict("name" => "Bob", "email" => "bob@test.com"))
        all_users = JuliaHub.Server.Storage.list_all(storage, "users")
        @test length(all_users) == 2
        
        # Test delete
        @test JuliaHub.Server.Storage.delete!(storage, "users", "user1") == true
        @test JuliaHub.Server.Storage.exists(storage, "users", "user1") == false
        @test JuliaHub.Server.Storage.delete!(storage, "users", "user1") == false
        
        # Test count
        @test JuliaHub.Server.Storage.count(storage, "users") == 1
        
        # Test clear
        JuliaHub.Server.Storage.clear!(storage, "users")
        @test JuliaHub.Server.Storage.count(storage, "users") == 0
    end
    
    @testset "Configuration Module" begin
        # Test default configuration
        config = JuliaHub.Server.Configuration.default_config()
        @test config isa JuliaHub.Server.Configuration.ServerConfiguration
        @test config.environment == :development
        @test config.http.port == 8080
        @test config.database.backend == :sqlite
        
        # Test validation
        @test JuliaHub.Server.Configuration.validate_config(config) == true
        
        # Test invalid configuration
        invalid_config = JuliaHub.Server.Configuration.ServerConfiguration(
            environment = "production",
            storage_path = config.storage_path,
            max_workers = config.max_workers,
            metadata = config.metadata,
            database = config.database,
            http = JuliaHub.Server.Configuration.HTTPConfig(
                host = config.http.host,
                port = -1,  # Invalid port
                enable_ssl = config.http.enable_ssl,
                ssl_cert_path = config.http.ssl_cert_path,
                ssl_key_path = config.http.ssl_key_path,
                request_timeout_seconds = config.http.request_timeout_seconds,
                max_request_size_mb = config.http.max_request_size_mb,
                enable_cors = config.http.enable_cors,
                cors_origins = config.http.cors_origins
            ),
            auth = config.auth,
            cache = config.cache,
            logging = config.logging
        )
        @test JuliaHub.Server.Configuration.validate_config(invalid_config) == false
        
        # Test environment variable override
        ENV["JULIAHUB_HTTP_PORT"] = "9999"
        config_with_env = JuliaHub.Server.Configuration.apply_env_overrides(JuliaHub.Server.Configuration.default_config())
        @test config_with_env.http.port == 9999
        delete!(ENV, "JULIAHUB_HTTP_PORT")
    end
    
    @testset "Authentication Module" begin
        # Reset auth state for clean test
        empty!(JuliaHub.Server.Authentication.USERS)
        empty!(JuliaHub.Server.Authentication.SESSIONS)
        empty!(JuliaHub.Server.Authentication.API_KEYS)
        
        # Test user creation
        user = JuliaHub.Server.Authentication.create_user(
            "testuser", "test@example.com", "password123", role="user"
        )
        @test user isa JuliaHub.Server.Authentication.User
        @test user.username == "testuser"
        @test user.email == "test@example.com"
        @test "user" in user.roles
        @test user.is_active == true
        
        # Test password hashing
        @test user.password_hash != "password123"
        @test occursin(":", user.password_hash)  # salt:hash format
        
        # Test authenticate user
        auth_user = JuliaHub.Server.Authentication.authenticate_user("testuser", "password123")
        @test !isnothing(auth_user)
        @test auth_user.id == user.id
        
        # Test wrong password
        @test isnothing(JuliaHub.Server.Authentication.authenticate_user("testuser", "wrongpassword"))
        
        # Test wrong username
        @test isnothing(JuliaHub.Server.Authentication.authenticate_user("nonexistent", "password123"))
        
        # Test session creation
        session = JuliaHub.Server.Authentication.create_session(user.id)
        @test session isa JuliaHub.Server.Authentication.Session
        @test session.user_id == user.id
        @test !session.is_revoked
        
        # Test session validation
        retrieved_session = JuliaHub.Server.Authentication.get_session(session.token)
        @test !isnothing(retrieved_session)
        @test retrieved_session.id == session.id
        
        # Test session revocation
        @test JuliaHub.Server.Authentication.revoke_session(session.token) == true
        @test JuliaHub.Server.Authentication.get_session(session.token).is_revoked == true
        
        # Test JWT generation - pass the user object
        jwt_token = JuliaHub.Server.Authentication.generate_jwt(user)
        @test !isempty(jwt_token)
        @test occursin(".", jwt_token)  # JWT format: header.payload.signature
        
        # Test JWT validation
        payload = JuliaHub.Server.Authentication.validate_jwt(jwt_token)
        @test !isnothing(payload)
        @test payload["sub"] == user.id
        @test "user" in payload["roles"]
        
        # Test API key generation
        api_key_result = JuliaHub.Server.Authentication.create_api_key(
            user.id, "test-key", ["read", "write"]
        )
        @test haskey(api_key_result, "full_key")
        @test haskey(api_key_result, "api_key")
        @test api_key_result["api_key"].name == "test-key"
        @test "read" in api_key_result["api_key"].scopes
        
        # Test API key validation
        validated = JuliaHub.Server.Authentication.validate_api_key(api_key_result["full_key"])
        @test !isnothing(validated)
        @test validated.user_id == user.id
        
        # Test RBAC permissions
        @test JuliaHub.Server.Authentication.has_permission("admin", "users", "create") == true
        @test JuliaHub.Server.Authentication.has_permission("viewer", "users", "create") == false
        @test JuliaHub.Server.Authentication.has_permission("user", "projects", "read") == true
        
        # Test user update
        updated = JuliaHub.Server.Authentication.update_user(user.id; email="newemail@example.com")
        @test !isnothing(updated)
        @test updated.email == "newemail@example.com"
        
        # Test get user
        retrieved_user = JuliaHub.Server.Authentication.get_user(user.id)
        @test !isnothing(retrieved_user)
        @test retrieved_user.username == "testuser"
        
        # Test list users
        users = JuliaHub.Server.Authentication.list_users()
        @test length(users) >= 1
        
        # Test delete user
        @test JuliaHub.Server.Authentication.delete_user(user.id) == true
        @test isnothing(JuliaHub.Server.Authentication.get_user(user.id))
    end
    
    @testset "HTTP Server Module" begin
        # Test Router creation
        router = JuliaHub.Server.HTTPServer.Router()
        @test router isa JuliaHub.Server.HTTPServer.Router
        @test isempty(router.routes)
        
        # Test route registration
        JuliaHub.Server.HTTPServer.add_route!(router, "GET", "/test", req -> Dict("status" => "ok"))
        @test length(router.routes) == 1
        @test router.routes[1].method == "GET"
        @test router.routes[1].path == "/test"
        
        # Test route matching
        matched, params = JuliaHub.Server.HTTPServer.match_route(router, "GET", "/test")
        @test !isnothing(matched)
        @test matched.path == "/test"
        @test isempty(params)
        
        # Test path parameter extraction
        JuliaHub.Server.HTTPServer.add_route!(router, "GET", "/users/:id", req -> Dict("id" => req[:params]["id"]))
        matched, params = JuliaHub.Server.HTTPServer.match_route(router, "GET", "/users/123")
        @test !isnothing(matched)
        @test params["id"] == "123"
        
        # Test nested path parameters
        JuliaHub.Server.HTTPServer.add_route!(router, "GET", "/projects/:project_id/files/:file_id", 
            req -> Dict("project" => req[:params]["project_id"]))
        matched, params = JuliaHub.Server.HTTPServer.match_route(router, "GET", "/projects/p1/files/f2")
        @test !isnothing(matched)
        @test params["project_id"] == "p1"
        @test params["file_id"] == "f2"
        
        # Test route not found
        matched, params = JuliaHub.Server.HTTPServer.match_route(router, "GET", "/nonexistent")
        @test isnothing(matched)
        
        # Test method not allowed
        matched, params = JuliaHub.Server.HTTPServer.match_route(router, "POST", "/test")
        @test isnothing(matched)
        
        # Test OpenAPI spec generation
        spec = JuliaHub.Server.HTTPServer.generate_openapi_spec(router, "JuliaHub API", "1.0.0")
        @test spec["openapi"] == "3.0.3"
        @test spec["info"]["title"] == "JuliaHub API"
        @test haskey(spec, "paths")
        
        # Test JSON response helper
        json_response = JuliaHub.Server.HTTPServer.json_response(Dict("test" => true))
        @test json_response isa HTTP.Response
        @test json_response.status == 200
        
        # Test error response helper
        error_response = JuliaHub.Server.HTTPServer.error_response("Not found", 404)
        @test error_response.status == 404
    end
    
    @testset "Routes Module" begin
        router = JuliaHub.Server.HTTPServer.Router()
        JuliaHub.Server.Routes.register_all_routes!(router)
        
        # Verify all expected routes are registered
        @test length(router.routes) > 0
        
        # Find specific routes
        routes_by_path = Dict(r.path => r for r in router.routes)
        
        # Health endpoints
        @test haskey(routes_by_path, "/api/v1/health")
        
        # Auth endpoints
        @test haskey(routes_by_path, "/api/v1/auth/login")
        @test haskey(routes_by_path, "/api/v1/auth/register")
        
        # Project endpoints
        @test haskey(routes_by_path, "/api/v1/projects")
        @test haskey(routes_by_path, "/api/v1/projects/:id")
        
        # Environment endpoints
        @test haskey(routes_by_path, "/api/v1/environments")
        @test haskey(routes_by_path, "/api/v1/environments/:id")
        
        # Dashboard endpoints
        @test haskey(routes_by_path, "/api/v1/dashboards")
        @test haskey(routes_by_path, "/api/v1/dashboards/:id")
    end
    
    @testset "Enhanced Server Initialization" begin
        # Test server with new config options
        config = JuliaHub.Server.ServerConfig(
            host = "127.0.0.1",
            port = 9999,
            max_workers = 4,
            storage_path = "/tmp/juliahub_phase1_test",
            enable_storage = true,
            db_backend = :sqlite,
            jwt_secret = "test-secret-key",
            jwt_expiry_hours = 12,
            log_level = :debug,
            enable_audit_log = true
        )
        
        @test config.db_backend == :sqlite
        @test config.jwt_secret == "test-secret-key"
        @test config.jwt_expiry_hours == 12
        @test config.log_level == :debug
        @test config.enable_audit_log == true
        
        # Start server
        state = JuliaHub.Server.start_server(config)
        @test !isnothing(state)
        @test haskey(state, "storage")
        
        # Stop server
        @test JuliaHub.Server.stop_server() == true
        
        # Clean up test directory
        rm("/tmp/juliahub_phase1_test", recursive=true, force=true)
    end
end
