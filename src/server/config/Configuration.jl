"""
    Configuration

Configuration management for JuliaHub server-side platform.
Supports hierarchical configuration: defaults → env vars → config file → CLI
"""
module Configuration

using Dates
using TOML
using JSON

export ServerConfiguration, load_config, save_config, get_config_value, set_config_value
export validate_config, merge_configs, get_env_config, default_config, apply_env_overrides
export DatabaseConfig, HTTPConfig, AuthConfig, CacheConfig, LoggingConfig

# Allow String values to be used where Symbol is expected (e.g., environment field)
Base.convert(::Type{Symbol}, s::AbstractString) = Symbol(s)

"""
    DatabaseConfig

Database connection configuration.
"""
Base.@kwdef struct DatabaseConfig
    backend::Symbol = :sqlite
    connection_string::String = "juliahub.db"
    pool_size::Int = 10
    timeout_seconds::Int = 30
end

"""
    HTTPConfig

HTTP server configuration.
"""
Base.@kwdef struct HTTPConfig
    host::String = "0.0.0.0"
    port::Int = 8080
    enable_ssl::Bool = false
    ssl_cert_path::Union{String, Nothing} = nothing
    ssl_key_path::Union{String, Nothing} = nothing
    request_timeout_seconds::Int = 30
    max_request_size_mb::Int = 100
    enable_cors::Bool = true
    cors_origins::Vector{String} = ["*"]
end

"""
    AuthConfig

Authentication and authorization configuration.
"""
Base.@kwdef struct AuthConfig
    jwt_secret::String = ""
    jwt_expiry_hours::Int = 24
    enable_api_keys::Bool = true
    enable_oauth::Bool = false
    oauth_providers::Vector{String} = String[]
    password_min_length::Int = 8
    max_login_attempts::Int = 5
    lockout_duration_minutes::Int = 30
    enable_mfa::Bool = false
end

"""
    CacheConfig

Caching configuration.
"""
Base.@kwdef struct CacheConfig
    enabled::Bool = true
    backend::Symbol = :memory
    redis_url::String = ""
    default_ttl_seconds::Int = 300
    max_entries::Int = 10000
end

"""
    LoggingConfig

Logging configuration.
"""
Base.@kwdef struct LoggingConfig
    level::Symbol = :info
    format::Symbol = :json
    output::Symbol = :stdout
    file_path::String = "logs/juliahub.log"
    max_file_size_mb::Int = 100
    max_files::Int = 10
    enable_audit_log::Bool = true
    audit_log_path::String = "logs/audit.log"
end

"""
    ServerConfiguration

Complete server configuration.
"""
Base.@kwdef mutable struct ServerConfiguration
    environment::Symbol = :development
    database::DatabaseConfig = DatabaseConfig()
    http::HTTPConfig = HTTPConfig()
    auth::AuthConfig = AuthConfig()
    cache::CacheConfig = CacheConfig()
    logging::LoggingConfig = LoggingConfig()
    storage_path::String = "./juliahub_storage"
    max_workers::Int = 10
    metadata::Dict{String, Any} = Dict{String, Any}()
end

# Default configuration
const DEFAULT_CONFIG = ServerConfiguration()

# Environment variable prefix
const ENV_PREFIX = "JULIAHUB_"

"""
    load_config(path::String) -> ServerConfiguration

Load configuration from a TOML file.
"""
function load_config(path::String)
    if !isfile(path)
        @warn "Configuration file not found, using defaults" path
        return ServerConfiguration()
    end
    
    toml_data = TOML.parsefile(path)
    return parse_config(toml_data)
end

"""
    parse_config(data::Dict) -> ServerConfiguration

Parse configuration from a dictionary.
"""
function parse_config(data::Dict)
    config = ServerConfiguration()
    
    # Environment
    if haskey(data, "environment")
        config.environment = Symbol(data["environment"])
    end
    
    # Storage path
    if haskey(data, "storage_path")
        config.storage_path = data["storage_path"]
    end
    
    # Max workers
    if haskey(data, "max_workers")
        config.max_workers = data["max_workers"]
    end
    
    # Database config
    if haskey(data, "database")
        db = data["database"]
        config.database = DatabaseConfig(
            backend = Symbol(get(db, "backend", "sqlite")),
            connection_string = get(db, "connection_string", "juliahub.db"),
            pool_size = get(db, "pool_size", 10),
            timeout_seconds = get(db, "timeout_seconds", 30)
        )
    end
    
    # HTTP config
    if haskey(data, "http")
        http = data["http"]
        config.http = HTTPConfig(
            host = get(http, "host", "0.0.0.0"),
            port = get(http, "port", 8080),
            enable_ssl = get(http, "enable_ssl", false),
            ssl_cert_path = get(http, "ssl_cert_path", nothing),
            ssl_key_path = get(http, "ssl_key_path", nothing),
            request_timeout_seconds = get(http, "request_timeout_seconds", 30),
            max_request_size_mb = get(http, "max_request_size_mb", 100),
            enable_cors = get(http, "enable_cors", true),
            cors_origins = get(http, "cors_origins", ["*"])
        )
    end
    
    # Auth config
    if haskey(data, "auth")
        auth = data["auth"]
        config.auth = AuthConfig(
            jwt_secret = get(auth, "jwt_secret", ""),
            jwt_expiry_hours = get(auth, "jwt_expiry_hours", 24),
            enable_api_keys = get(auth, "enable_api_keys", true),
            enable_oauth = get(auth, "enable_oauth", false),
            oauth_providers = get(auth, "oauth_providers", String[]),
            password_min_length = get(auth, "password_min_length", 8),
            max_login_attempts = get(auth, "max_login_attempts", 5),
            lockout_duration_minutes = get(auth, "lockout_duration_minutes", 30),
            enable_mfa = get(auth, "enable_mfa", false)
        )
    end
    
    # Cache config
    if haskey(data, "cache")
        cache = data["cache"]
        config.cache = CacheConfig(
            enabled = get(cache, "enabled", true),
            backend = Symbol(get(cache, "backend", "memory")),
            redis_url = get(cache, "redis_url", ""),
            default_ttl_seconds = get(cache, "default_ttl_seconds", 300),
            max_entries = get(cache, "max_entries", 10000)
        )
    end
    
    # Logging config
    if haskey(data, "logging")
        logging = data["logging"]
        config.logging = LoggingConfig(
            level = Symbol(get(logging, "level", "info")),
            format = Symbol(get(logging, "format", "json")),
            output = Symbol(get(logging, "output", "stdout")),
            file_path = get(logging, "file_path", "logs/juliahub.log"),
            max_file_size_mb = get(logging, "max_file_size_mb", 100),
            max_files = get(logging, "max_files", 10),
            enable_audit_log = get(logging, "enable_audit_log", true),
            audit_log_path = get(logging, "audit_log_path", "logs/audit.log")
        )
    end
    
    # Metadata
    if haskey(data, "metadata")
        config.metadata = data["metadata"]
    end
    
    return config
end

"""
    save_config(config::ServerConfiguration, path::String)

Save configuration to a TOML file.
"""
function save_config(config::ServerConfiguration, path::String)
    data = config_to_dict(config)
    
    # Ensure directory exists
    dir = dirname(path)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end
    
    open(path, "w") do io
        TOML.print(io, data)
    end
    
    return true
end

"""
    config_to_dict(config::ServerConfiguration) -> Dict

Convert configuration to dictionary for serialization.
"""
function config_to_dict(config::ServerConfiguration)
    return Dict(
        "environment" => string(config.environment),
        "storage_path" => config.storage_path,
        "max_workers" => config.max_workers,
        "database" => Dict(
            "backend" => string(config.database.backend),
            "connection_string" => config.database.connection_string,
            "pool_size" => config.database.pool_size,
            "timeout_seconds" => config.database.timeout_seconds
        ),
        "http" => Dict(
            "host" => config.http.host,
            "port" => config.http.port,
            "enable_ssl" => config.http.enable_ssl,
            "ssl_cert_path" => config.http.ssl_cert_path,
            "ssl_key_path" => config.http.ssl_key_path,
            "request_timeout_seconds" => config.http.request_timeout_seconds,
            "max_request_size_mb" => config.http.max_request_size_mb,
            "enable_cors" => config.http.enable_cors,
            "cors_origins" => config.http.cors_origins
        ),
        "auth" => Dict(
            "jwt_secret" => config.auth.jwt_secret,
            "jwt_expiry_hours" => config.auth.jwt_expiry_hours,
            "enable_api_keys" => config.auth.enable_api_keys,
            "enable_oauth" => config.auth.enable_oauth,
            "oauth_providers" => config.auth.oauth_providers,
            "password_min_length" => config.auth.password_min_length,
            "max_login_attempts" => config.auth.max_login_attempts,
            "lockout_duration_minutes" => config.auth.lockout_duration_minutes,
            "enable_mfa" => config.auth.enable_mfa
        ),
        "cache" => Dict(
            "enabled" => config.cache.enabled,
            "backend" => string(config.cache.backend),
            "redis_url" => config.cache.redis_url,
            "default_ttl_seconds" => config.cache.default_ttl_seconds,
            "max_entries" => config.cache.max_entries
        ),
        "logging" => Dict(
            "level" => string(config.logging.level),
            "format" => string(config.logging.format),
            "output" => string(config.logging.output),
            "file_path" => config.logging.file_path,
            "max_file_size_mb" => config.logging.max_file_size_mb,
            "max_files" => config.logging.max_files,
            "enable_audit_log" => config.logging.enable_audit_log,
            "audit_log_path" => config.logging.audit_log_path
        ),
        "metadata" => config.metadata
    )
end

"""
    get_env_config() -> ServerConfiguration

Load configuration from environment variables.
"""
function get_env_config()
    config = ServerConfiguration()
    
    # Environment
    if haskey(ENV, "$(ENV_PREFIX)ENVIRONMENT")
        config.environment = Symbol(ENV["$(ENV_PREFIX)ENVIRONMENT"])
    end
    
    # Storage path
    if haskey(ENV, "$(ENV_PREFIX)STORAGE_PATH")
        config.storage_path = ENV["$(ENV_PREFIX)STORAGE_PATH"]
    end
    
    # Max workers
    if haskey(ENV, "$(ENV_PREFIX)MAX_WORKERS")
        config.max_workers = parse(Int, ENV["$(ENV_PREFIX)MAX_WORKERS"])
    end
    
    # Database config
    if haskey(ENV, "$(ENV_PREFIX)DB_BACKEND")
        config.database = DatabaseConfig(
            backend = Symbol(ENV["$(ENV_PREFIX)DB_BACKEND"]),
            connection_string = get(ENV, "$(ENV_PREFIX)DB_CONNECTION_STRING", config.database.connection_string),
            pool_size = parse(Int, get(ENV, "$(ENV_PREFIX)DB_POOL_SIZE", string(config.database.pool_size))),
            timeout_seconds = parse(Int, get(ENV, "$(ENV_PREFIX)DB_TIMEOUT", string(config.database.timeout_seconds)))
        )
    end
    
    # HTTP config
    if haskey(ENV, "$(ENV_PREFIX)HTTP_HOST") || haskey(ENV, "$(ENV_PREFIX)HTTP_PORT") || haskey(ENV, "$(ENV_PREFIX)HTTP_SSL")
        config.http = HTTPConfig(
            host = get(ENV, "$(ENV_PREFIX)HTTP_HOST", config.http.host),
            port = parse(Int, get(ENV, "$(ENV_PREFIX)HTTP_PORT", string(config.http.port))),
            enable_ssl = parse(Bool, get(ENV, "$(ENV_PREFIX)HTTP_SSL", string(config.http.enable_ssl)))
        )
    end
    
    # Auth config
    if haskey(ENV, "$(ENV_PREFIX)JWT_SECRET")
        config.auth = AuthConfig(
            jwt_secret = ENV["$(ENV_PREFIX)JWT_SECRET"],
            jwt_expiry_hours = parse(Int, get(ENV, "$(ENV_PREFIX)JWT_EXPIRY_HOURS", string(config.auth.jwt_expiry_hours)))
        )
    end
    
    return config
end

"""
    merge_configs(base::ServerConfiguration, override::ServerConfiguration) -> ServerConfiguration

Merge two configurations, with override taking precedence for non-default values.
"""
function merge_configs(base::ServerConfiguration, override::ServerConfiguration)
    result = deepcopy(base)
    
    if override.environment != DEFAULT_CONFIG.environment
        result.environment = override.environment
    end
    
    if override.storage_path != DEFAULT_CONFIG.storage_path
        result.storage_path = override.storage_path
    end
    
    if override.max_workers != DEFAULT_CONFIG.max_workers
        result.max_workers = override.max_workers
    end
    
    # Merge database config
    if override.database.connection_string != DEFAULT_CONFIG.database.connection_string
        result.database = override.database
    end
    
    # Merge HTTP config
    if override.http.port != DEFAULT_CONFIG.http.port
        result.http = override.http
    end
    
    # Merge auth config
    if !isempty(override.auth.jwt_secret)
        result.auth = override.auth
    end
    
    # Merge metadata
    for (key, value) in override.metadata
        result.metadata[key] = value
    end
    
    return result
end

"""
    validate_config(config::ServerConfiguration) -> Tuple{Bool, Vector{String}}

Validate configuration and return (is_valid, errors).
"""
function validate_config(config::ServerConfiguration)
    errors = String[]
    
    # Validate HTTP config
    if config.http.port < 1 || config.http.port > 65535
        push!(errors, "HTTP port must be between 1 and 65535")
    end
    
    if config.http.enable_ssl
        if isnothing(config.http.ssl_cert_path) || !isfile(config.http.ssl_cert_path)
            push!(errors, "SSL certificate path is required when SSL is enabled")
        end
        if isnothing(config.http.ssl_key_path) || !isfile(config.http.ssl_key_path)
            push!(errors, "SSL key path is required when SSL is enabled")
        end
    end
    
    # Validate auth config
    if config.environment == :production && isempty(config.auth.jwt_secret)
        push!(errors, "JWT secret is required in production environment")
    end
    
    if config.auth.password_min_length < 6
        push!(errors, "Password minimum length must be at least 6")
    end
    
    # Validate database config
    if config.database.pool_size < 1
        push!(errors, "Database pool size must be at least 1")
    end
    
    # Validate max workers
    if config.max_workers < 1
        push!(errors, "Max workers must be at least 1")
    end
    
    return isempty(errors)
end

"""
    get_config_value(config::ServerConfiguration, path::String)

Get a configuration value by dot-separated path (e.g., "http.port").
"""
function get_config_value(config::ServerConfiguration, path::String)
    parts = split(path, ".")
    
    if length(parts) == 1
        return getfield(config, Symbol(parts[1]))
    elseif length(parts) == 2
        section = getfield(config, Symbol(parts[1]))
        return getfield(section, Symbol(parts[2]))
    else
        error("Invalid configuration path: $path")
    end
end

"""
    set_config_value!(config::ServerConfiguration, path::String, value)

Set a configuration value by dot-separated path.
"""
function set_config_value!(config::ServerConfiguration, path::String, value)
    parts = split(path, ".")
    
    if length(parts) == 1
        setfield!(config, Symbol(parts[1]), value)
    else
        error("Cannot set nested configuration values directly")
    end
    
    return config
end

"""
    default_config() -> ServerConfiguration

Return a ServerConfiguration with all default values.
"""
function default_config()
    return ServerConfiguration()
end

"""
    apply_env_overrides(config::ServerConfiguration) -> ServerConfiguration

Apply environment variable overrides to configuration.
Environment variables follow the pattern JULIAHUB_<SECTION>_<KEY>.
"""
function apply_env_overrides(config::ServerConfiguration)
    # Get environment overrides
    env_config = get_env_config()
    
    # Merge with base config (env vars override)
    return merge_configs(config, env_config)
end

end # module Configuration
