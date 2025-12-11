local redis = require "resty.redis"
local red = redis:new()

red:set_timeout(1000)

local ok, err = red:connect("unix:/var/run/valkey/valkey.sock")
if not ok then
    ngx.log(ngx.ERR, "failed to connect to valkey: ", err)
    return ngx.exit(500)
end

local cookie_value = ngx.var.cookie_samizdater
if not cookie_value then
    red:close()
    return ngx.exit(401)
end

-- Check if session exists
local session_res, err = red:get("samizdat:" .. cookie_value)
if err then
    ngx.log(ngx.ERR, "valkey session check error: ", err)
    red:close()
    return ngx.exit(500)
end

if not session_res or session_res == ngx.null then
    red:close()
    return ngx.exit(403)
end

-- Parse session data (simple format: userid:group1,group2,group3)
local parts = ngx.re.split(session_res, ":")
if not parts or #parts < 2 then
    ngx.log(ngx.ERR, "invalid session data format")
    red:close()
    return ngx.exit(500)
end

local user_id = parts[1]
local groups_str = parts[2] or ""
local groups = ngx.re.split(groups_str, ",")

-- Check if user has required group membership
-- Get required group from nginx variable (set in location block)
local required_group = ngx.var.required_group
if required_group then
    -- Check if user has the required group
    for _, group in ipairs(groups) do
        if group == required_group then
            ngx.var.user_id = user_id
            ngx.var.user_groups = groups_str
            red:close()
            return  -- Allow access
        end
    end
    
    -- User doesn't have required group
    red:close()
    return ngx.exit(403)
else
    -- No specific group required, just valid session
    ngx.var.user_id = user_id
    ngx.var.user_groups = groups_str
    red:close()
    return  -- Allow access
end