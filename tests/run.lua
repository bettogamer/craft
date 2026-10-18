-- tests/run.lua — minimal test runner, pure Lua (5.1–5.4), ZERO dependencies.
-- Exists because busted does not install on the dev machine (luarocks needs a C
-- compiler); CI (Linux) keeps running the same specs with real busted. The API is
-- busted/luassert-compatible (describe/it + assert.equals/is_true/...), so specs
-- need no changes to run under either runner.
-- Usage (from repo root): lua tests/run.lua tests/button_spec.lua tests/sidebar_spec.lua

local passed, failed = 0, 0
local failures = {}
local path = {}  -- current describe nesting

local rawassert = assert

local function fail(msg)
    error({ runner = true, msg = msg }, 2)
end

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

-- luassert-style assert: callable like plain assert, plus the matcher methods below
local A = setmetatable({}, {
    __call = function(_, cond, msg) return rawassert(cond, msg) end,
})

function A.equals(exp, act)
    if exp ~= act then fail("expected " .. fmt(exp) .. " but got " .. fmt(act)) end
end
A.equal = A.equals

function A.near(exp, act, tol)
    if type(act) ~= "number" or math.abs(exp - act) > (tol or 1e-9) then
        fail("expected " .. fmt(act) .. " to be near " .. fmt(exp) .. " (tol " .. tostring(tol) .. ")")
    end
end

-- Deep equality (luassert's assert.same): tables compared key by key, recursively.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function dump(v)
    if type(v) ~= "table" then return fmt(v) end
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. dump(x) end
    return "{" .. table.concat(parts, ", ") .. "}"
end
function A.same(exp, act)
    if not same(exp, act) then fail("expected " .. dump(exp) .. " but got " .. dump(act)) end
end

function A.is_true(v)    if v ~= true  then fail("expected true, got " .. fmt(v)) end end
function A.is_false(v)   if v ~= false then fail("expected false, got " .. fmt(v)) end end
function A.is_nil(v)     if v ~= nil   then fail("expected nil, got " .. fmt(v)) end end
function A.is_not_nil(v) if v == nil   then fail("expected a value, got nil") end end

function A.has_no_errors(f)
    local ok, err = pcall(f)
    if not ok then
        local m = type(err) == "table" and err.msg or tostring(err)
        fail("expected no errors, got: " .. m)
    end
end

function A.has_error(f)
    if pcall(f) then fail("expected an error, but none was raised") end
end

function describe(name, body)
    path[#path + 1] = name
    local ok, err = pcall(body)
    if not ok then
        failed = failed + 1
        failures[#failures + 1] = table.concat(path, " > ") .. "\n    (describe) " .. tostring(err)
    end
    path[#path] = nil
end

function it(name, body)
    local full = table.concat(path, " > ") .. " > " .. name
    local ok, err = pcall(body)
    if ok then
        passed = passed + 1
        io.write(".")
    else
        failed = failed + 1
        io.write("F")
        local m = type(err) == "table" and err.msg or tostring(err)
        failures[#failures + 1] = full .. "\n    " .. m
    end
end

local specs = { ... }
if #specs == 0 then
    print("usage: lua tests/run.lua <spec.lua> [...]")
    os.exit(2)
end

assert = A  -- luassert-style global while specs run
for _, spec in ipairs(specs) do
    dofile(spec)
end
assert = rawassert

print(string.format("\n%d passed, %d failed", passed, failed))
for _, f in ipairs(failures) do print("FAIL: " .. f) end
os.exit(failed == 0 and 0 or 1)
