"""
    Authentication

Authentication and authorization module for JuliaHub server-side platform.
Provides user management, JWT tokens, sessions, RBAC, and API keys.
"""
module Authentication

using Dates
using UUIDs
using SHA
using Base64
using JSON

export User, Session, APIKey, Role, Permission
export create_user, authenticate_user, get_user, update_user, delete_user, list_users
export create_session, validate_session, invalidate_session, refresh_session
export create_api_key, validate_api_key, revoke_api_key, list_api_keys
export generate_jwt, validate_jwt, decode_jwt
export has_permission, check_permission, grant_permission, revoke_permission
export hash_password, verify_password

# ============================================================================
# Types
# ============================================================================

"""
    Role

User role for RBAC.
"""
struct Role
    id::String
    name::String
    permissions::Vector{String}
    created_at::DateTime
end

"""
    Permission

System permission.
"""
struct Permission
    id::String
    name::String
    resource::String
    actions::Vector{String}
    description::String
end

"""
    User

User account in the system.
"""
mutable struct User
    id::String
    username::String
    email::String
    password_hash::String
    roles::Vector{String}
    permissions::Vector{String}
    created_at::DateTime
    updated_at::DateTime
    last_login::Union{DateTime, Nothing}
    is_active::Bool
    is_locked::Bool
    failed_login_attempts::Int
    locked_until::Union{DateTime, Nothing}
    metadata::Dict{String, Any}
end

"""
    Session

User session for authentication.
"""
mutable struct Session
    id::String
    user_id::String
    token::String
    created_at::DateTime
    expires_at::DateTime
    last_activity::DateTime
    ip_address::String
    user_agent::String
    is_valid::Bool
end

"""
    APIKey

API key for programmatic access.
"""
mutable struct APIKey
    id::String
    user_id::String
    name::String
    key_hash::String
    prefix::String
    permissions::Vector{String}
    created_at::DateTime
    expires_at::Union{DateTime, Nothing}
    last_used::Union{DateTime, Nothing}
    is_active::Bool
end

# ============================================================================
# Default Roles and Permissions
# ============================================================================

const DEFAULT_PERMISSIONS = [
    Permission("read_projects", "Read Projects", "projects", ["read"], "Can view projects"),
    Permission("write_projects", "Write Projects", "projects", ["create", "update"], "Can create and update projects"),
    Permission("delete_projects", "Delete Projects", "projects", ["delete"], "Can delete projects"),
    Permission("admin_projects", "Admin Projects", "projects", ["admin"], "Full project administration"),
    
    Permission("read_environments", "Read Environments", "environments", ["read"], "Can view coding environments"),
    Permission("write_environments", "Write Environments", "environments", ["create", "update"], "Can create and manage environments"),
    Permission("delete_environments", "Delete Environments", "environments", ["delete"], "Can delete environments"),
    
    Permission("read_jobs", "Read Jobs", "jobs", ["read"], "Can view HPC jobs"),
    Permission("submit_jobs", "Submit Jobs", "jobs", ["create"], "Can submit HPC jobs"),
    Permission("cancel_jobs", "Cancel Jobs", "jobs", ["delete"], "Can cancel HPC jobs"),
    Permission("admin_jobs", "Admin Jobs", "jobs", ["admin"], "Full job administration"),
    
    Permission("read_users", "Read Users", "users", ["read"], "Can view user profiles"),
    Permission("write_users", "Write Users", "users", ["create", "update"], "Can manage users"),
    Permission("delete_users", "Delete Users", "users", ["delete"], "Can delete users"),
    Permission("admin_users", "Admin Users", "users", ["admin"], "Full user administration"),
    
    Permission("read_packages", "Read Packages", "packages", ["read"], "Can view package registry"),
    Permission("write_packages", "Write Packages", "packages", ["create", "update"], "Can register packages"),
    Permission("admin_packages", "Admin Packages", "packages", ["admin"], "Full registry administration"),
    
    Permission("read_dashboards", "Read Dashboards", "dashboards", ["read"], "Can view dashboards"),
    Permission("write_dashboards", "Write Dashboards", "dashboards", ["create", "update"], "Can create dashboards"),
    Permission("admin_dashboards", "Admin Dashboards", "dashboards", ["admin"], "Full dashboard administration"),
    
    Permission("system_admin", "System Admin", "system", ["admin"], "Full system administration")
]

const DEFAULT_ROLES = [
    Role(
        "viewer",
        "Viewer",
        ["read_projects", "read_environments", "read_jobs", "read_packages", "read_dashboards"],
        now()
    ),
    Role(
        "user",
        "User",
        ["read_projects", "write_projects", "read_environments", "write_environments",
         "read_jobs", "submit_jobs", "read_packages", "read_dashboards", "write_dashboards"],
        now()
    ),
    Role(
        "developer",
        "Developer",
        ["read_projects", "write_projects", "delete_projects",
         "read_environments", "write_environments", "delete_environments",
         "read_jobs", "submit_jobs", "cancel_jobs",
         "read_packages", "write_packages",
         "read_dashboards", "write_dashboards"],
        now()
    ),
    Role(
        "admin",
        "Administrator",
        ["admin_projects", "admin_jobs", "admin_users", "admin_packages", "admin_dashboards", "system_admin"],
        now()
    )
]

# In-memory storage for users, sessions, and API keys
const USERS = Dict{String, User}()
const SESSIONS = Dict{String, Session}()
const API_KEYS = Dict{String, APIKey}()
const ROLES = Dict{String, Role}(r.id => r for r in DEFAULT_ROLES)
const PERMISSIONS = Dict{String, Permission}(p.id => p for p in DEFAULT_PERMISSIONS)

# ============================================================================
# Password Hashing
# ============================================================================

"""
    hash_password(password::String) -> String

Hash a password using SHA-256 with salt.
"""
function hash_password(password::String)
    salt = bytes2hex(rand(UInt8, 16))
    hash = bytes2hex(sha256("$salt:$password"))
    return "$salt:$hash"
end

"""
    verify_password(password::String, hash::String) -> Bool

Verify a password against its hash.
"""
function verify_password(password::String, hash::String)
    parts = split(hash, ":")
    if length(parts) != 2
        return false
    end
    
    salt, stored_hash = parts
    computed_hash = bytes2hex(sha256("$salt:$password"))
    
    return computed_hash == stored_hash
end

# ============================================================================
# User Management
# ============================================================================

"""
    create_user(username::String, email::String, password::String; 
                role::String="", roles::Vector{String}=["user"], metadata::Dict{String, Any}=Dict{String, Any}()) -> User

Create a new user account. Use `role` for a single role or `roles` for multiple roles.
"""
function create_user(username::String, email::String, password::String;
                    role::String="",
                    roles::Vector{String}=String[],
                    metadata::Dict{String, Any}=Dict{String, Any}())
    # Determine roles list
    user_roles = if !isempty(role)
        [role]
    elseif !isempty(roles)
        roles
    else
        ["user"]
    end
    
    # Check for existing user
    for user in values(USERS)
        if user.username == username
            error("Username already exists: $username")
        end
        if user.email == email
            error("Email already exists: $email")
        end
    end
    
    user = User(
        string(uuid4()),
        username,
        email,
        hash_password(password),
        user_roles,
        String[],
        now(),
        now(),
        nothing,
        true,
        false,
        0,
        nothing,
        metadata
    )
    
    USERS[user.id] = user
    
    @info "Created user" username user.id
    
    return user
end

"""
    authenticate_user(username::String, password::String) -> Union{User, Nothing}

Authenticate a user with username and password.
"""
function authenticate_user(username::String, password::String)
    user = nothing
    
    for u in values(USERS)
        if u.username == username || u.email == username
            user = u
            break
        end
    end
    
    if isnothing(user)
        return nothing
    end
    
    # Check if user is locked
    if user.is_locked
        if !isnothing(user.locked_until) && now() < user.locked_until
            @warn "User account is locked" username
            return nothing
        else
            # Unlock user
            user.is_locked = false
            user.locked_until = nothing
            user.failed_login_attempts = 0
        end
    end
    
    # Verify password
    if !verify_password(password, user.password_hash)
        user.failed_login_attempts += 1
        
        # Lock account after 5 failed attempts
        if user.failed_login_attempts >= 5
            user.is_locked = true
            user.locked_until = now() + Minute(30)
            @warn "User account locked due to failed login attempts" username
        end
        
        return nothing
    end
    
    # Successful login
    user.failed_login_attempts = 0
    user.last_login = now()
    user.updated_at = now()
    
    @info "User authenticated" username user.id
    
    return user
end

"""
    get_user(user_id::String) -> Union{User, Nothing}

Get a user by ID.
"""
function get_user(user_id::String)
    return get(USERS, user_id, nothing)
end

"""
    get_user_by_username(username::String) -> Union{User, Nothing}

Get a user by username.
"""
function get_user_by_username(username::String)
    for user in values(USERS)
        if user.username == username
            return user
        end
    end
    return nothing
end

"""
    update_user(user_id::String, updates::Dict{String, Any}) -> Union{User, Nothing}

Update user properties.
"""
function update_user(user_id::String, updates::Dict{String, Any})
    user = get_user(user_id)
    if isnothing(user)
        return nothing
    end
    
    if haskey(updates, "email")
        user.email = updates["email"]
    end
    
    if haskey(updates, "password")
        user.password_hash = hash_password(updates["password"])
    end
    
    if haskey(updates, "roles")
        user.roles = updates["roles"]
    end
    
    if haskey(updates, "is_active")
        user.is_active = updates["is_active"]
    end
    
    if haskey(updates, "metadata")
        user.metadata = merge(user.metadata, updates["metadata"])
    end
    
    user.updated_at = now()
    
    return user
end

"""
    delete_user(user_id::String) -> Bool

Delete a user account.
"""
function delete_user(user_id::String)
    if haskey(USERS, user_id)
        delete!(USERS, user_id)
        
        # Also invalidate all sessions for this user
        for (session_id, session) in SESSIONS
            if session.user_id == user_id
                session.is_valid = false
            end
        end
        
        @info "Deleted user" user_id
        return true
    end
    
    return false
end

"""
    list_users(; filter::Union{Nothing, Function}=nothing, limit::Int=100, offset::Int=0) -> Vector{User}

List all users with optional filtering.
"""
function list_users(; filter::Union{Nothing, Function}=nothing, limit::Int=100, offset::Int=0)
    users = collect(values(USERS))
    
    if !isnothing(filter)
        users = Base.filter(filter, users)
    end
    
    # Sort by created_at
    users = sort(users; by=u -> u.created_at, rev=true)
    
    # Apply pagination
    start_idx = offset + 1
    end_idx = min(offset + limit, length(users))
    
    if start_idx > length(users)
        return User[]
    end
    
    return users[start_idx:end_idx]
end

# ============================================================================
# Session Management
# ============================================================================

"""
    create_session(user_id::String; ip_address::String="0.0.0.0", 
                   user_agent::String="", expiry_hours::Int=24) -> Session

Create a new session for a user.
"""
function create_session(user_id::String; 
                       ip_address::String="0.0.0.0",
                       user_agent::String="",
                       expiry_hours::Int=24)
    user = get_user(user_id)
    if isnothing(user)
        error("User not found: $user_id")
    end
    
    # Generate session token
    token = bytes2hex(rand(UInt8, 32))
    
    session = Session(
        string(uuid4()),
        user_id,
        token,
        now(),
        now() + Hour(expiry_hours),
        now(),
        ip_address,
        user_agent,
        true
    )
    
    SESSIONS[session.id] = session
    
    @info "Created session" user_id session.id
    
    return session
end

"""
    validate_session(token::String) -> Union{Session, Nothing}

Validate a session token and return the session if valid.
"""
function validate_session(token::String)
    for session in values(SESSIONS)
        if session.token == token && session.is_valid
            if session.expires_at > now()
                session.last_activity = now()
                return session
            else
                session.is_valid = false
            end
        end
    end
    
    return nothing
end

"""
    invalidate_session(session_id::String) -> Bool

Invalidate a session.
"""
function invalidate_session(session_id::String)
    session = get(SESSIONS, session_id, nothing)
    if !isnothing(session)
        session.is_valid = false
        @info "Invalidated session" session_id
        return true
    end
    return false
end

"""
    refresh_session(session_id::String; expiry_hours::Int=24) -> Union{Session, Nothing}

Refresh a session's expiry time.
"""
function refresh_session(session_id::String; expiry_hours::Int=24)
    session = get(SESSIONS, session_id, nothing)
    if !isnothing(session) && session.is_valid
        session.expires_at = now() + Hour(expiry_hours)
        session.last_activity = now()
        return session
    end
    return nothing
end

# ============================================================================
# JWT Token Management
# ============================================================================

const JWT_ALGORITHM = "HS256"
const JWT_SECRET_KEY = Ref{String}("")

"""
    set_jwt_secret(secret::String)

Set the JWT secret key.
"""
function set_jwt_secret(secret::String)
    JWT_SECRET_KEY[] = secret
end

"""
    generate_jwt(user::User; expiry_hours::Int=24) -> String

Generate a JWT token for a user.
"""
function generate_jwt(user::User; expiry_hours::Int=24)
    header = Dict(
        "alg" => JWT_ALGORITHM,
        "typ" => "JWT"
    )
    
    payload = Dict(
        "sub" => user.id,
        "username" => user.username,
        "email" => user.email,
        "roles" => user.roles,
        "iat" => round(Int, datetime2unix(now())),
        "exp" => round(Int, datetime2unix(now() + Hour(expiry_hours)))
    )
    
    # Encode header and payload
    header_b64 = base64encode(JSON.json(header))
    payload_b64 = base64encode(JSON.json(payload))
    
    # Create signature
    message = "$header_b64.$payload_b64"
    secret = isempty(JWT_SECRET_KEY[]) ? "default-secret-key" : JWT_SECRET_KEY[]
    signature = bytes2hex(sha256("$message:$secret"))
    signature_b64 = base64encode(signature)
    
    return "$header_b64.$payload_b64.$signature_b64"
end

"""
    validate_jwt(token::String) -> Union{Dict{String, Any}, Nothing}

Validate a JWT token and return the payload if valid.
"""
function validate_jwt(token::String)
    parts = split(token, ".")
    if length(parts) != 3
        return nothing
    end
    
    header_b64, payload_b64, signature_b64 = parts
    
    # Verify signature
    message = "$header_b64.$payload_b64"
    secret = isempty(JWT_SECRET_KEY[]) ? "default-secret-key" : JWT_SECRET_KEY[]
    expected_signature = bytes2hex(sha256("$message:$secret"))
    
    try
        provided_signature = String(base64decode(signature_b64))
        if provided_signature != expected_signature
            return nothing
        end
        
        # Decode payload
        payload = JSON.parse(String(base64decode(payload_b64)))
        
        # Check expiry
        if haskey(payload, "exp")
            exp_time = unix2datetime(payload["exp"])
            if exp_time < now()
                return nothing
            end
        end
        
        return payload
    catch
        return nothing
    end
end

"""
    decode_jwt(token::String) -> Union{Dict{String, Any}, Nothing}

Decode a JWT token without validation (for debugging).
"""
function decode_jwt(token::String)
    parts = split(token, ".")
    if length(parts) != 3
        return nothing
    end
    
    try
        payload = JSON.parse(String(base64decode(parts[2])))
        return payload
    catch
        return nothing
    end
end

# ============================================================================
# API Key Management
# ============================================================================

"""
    create_api_key(user_id::String, name::String; 
                   permissions::Vector{String}=String[],
                   expires_in_days::Union{Int, Nothing}=nothing) -> Tuple{APIKey, String}

Create a new API key. Returns (api_key, raw_key) where raw_key is the only time the key is visible.
"""
function create_api_key(user_id::String, name::String;
                       permissions::Vector{String}=String[],
                       expires_in_days::Union{Int, Nothing}=nothing)
    user = get_user(user_id)
    if isnothing(user)
        error("User not found: $user_id")
    end
    
    # Generate API key
    raw_key = bytes2hex(rand(UInt8, 32))
    prefix = raw_key[1:8]
    key_hash = bytes2hex(sha256(raw_key))
    
    api_key = APIKey(
        string(uuid4()),
        user_id,
        name,
        key_hash,
        prefix,
        permissions,
        now(),
        isnothing(expires_in_days) ? nothing : now() + Day(expires_in_days),
        nothing,
        true
    )
    
    API_KEYS[api_key.id] = api_key
    
    @info "Created API key" user_id name api_key.id
    
    return (api_key, raw_key)
end

"""
    validate_api_key(raw_key::String) -> Union{APIKey, Nothing}

Validate an API key and return it if valid.
"""
function validate_api_key(raw_key::String)
    key_hash = bytes2hex(sha256(raw_key))
    
    for api_key in values(API_KEYS)
        if api_key.key_hash == key_hash && api_key.is_active
            if isnothing(api_key.expires_at) || api_key.expires_at > now()
                api_key.last_used = now()
                return api_key
            end
        end
    end
    
    return nothing
end

"""
    revoke_api_key(api_key_id::String) -> Bool

Revoke an API key.
"""
function revoke_api_key(api_key_id::String)
    api_key = get(API_KEYS, api_key_id, nothing)
    if !isnothing(api_key)
        api_key.is_active = false
        @info "Revoked API key" api_key_id
        return true
    end
    return false
end

"""
    list_api_keys(user_id::String) -> Vector{APIKey}

List all API keys for a user.
"""
function list_api_keys(user_id::String)
    return [key for key in values(API_KEYS) if key.user_id == user_id]
end

# ============================================================================
# Permission Management
# ============================================================================

"""
    has_permission(user::User, permission::String) -> Bool

Check if a user has a specific permission.
"""
function has_permission(user::User, permission::String)
    # Check direct permissions
    if permission in user.permissions
        return true
    end
    
    # Check role-based permissions
    for role_id in user.roles
        role = get(ROLES, role_id, nothing)
        if !isnothing(role) && permission in role.permissions
            return true
        end
    end
    
    # Admin role has all permissions
    if "admin" in user.roles
        return true
    end
    
    return false
end

"""
    check_permission(user_id::String, permission::String) -> Bool

Check if a user ID has a specific permission.
"""
function check_permission(user_id::String, permission::String)
    user = get_user(user_id)
    if isnothing(user)
        return false
    end
    return has_permission(user, permission)
end

"""
    grant_permission(user_id::String, permission::String) -> Bool

Grant a permission to a user.
"""
function grant_permission(user_id::String, permission::String)
    user = get_user(user_id)
    if isnothing(user)
        return false
    end
    
    if !(permission in user.permissions)
        push!(user.permissions, permission)
        user.updated_at = now()
        @info "Granted permission" user_id permission
    end
    
    return true
end

"""
    revoke_permission(user_id::String, permission::String) -> Bool

Revoke a permission from a user.
"""
function revoke_permission(user_id::String, permission::String)
    user = get_user(user_id)
    if isnothing(user)
        return false
    end
    
    idx = findfirst(==(permission), user.permissions)
    if !isnothing(idx)
        deleteat!(user.permissions, idx)
        user.updated_at = now()
        @info "Revoked permission" user_id permission
    end
    
    return true
end

"""
    get_user_permissions(user::User) -> Vector{String}

Get all permissions for a user (direct + role-based).
"""
function get_user_permissions(user::User)
    permissions = Set{String}(user.permissions)
    
    for role_id in user.roles
        role = get(ROLES, role_id, nothing)
        if !isnothing(role)
            for perm in role.permissions
                push!(permissions, perm)
            end
        end
    end
    
    return collect(permissions)
end

# ============================================================================
# Clear Functions (for testing)
# ============================================================================

"""
    clear_all!()

Clear all authentication data (for testing).
"""
function clear_all!()
    empty!(USERS)
    empty!(SESSIONS)
    empty!(API_KEYS)
end

end # module Authentication
