#!/usr/bin/env tarantool

local clock = require('clock')

-- Configure database
box.cfg {
    listen = 3301
}
box.once("bootstrap", function()
    box.schema.space.create('tarmon')
    box.space.tarmon:format({
        { name = 'id', type = 'unsigned' },
        { name = 'host', type = 'string' },
        { name = 'service', type = 'string' },
        { name = 'seen', type = 'double' },
        { name = 'ttl', type = 'double' },
    })
    box.space.tarmon:create_index('primary',
        { type = 'TREE', parts = { 'id' }})
    box.space.tarmon:create_index('secondary',
        { type = 'TREE', parts = { 'ttl' }, unique = false})
end)

local function handler(req)
    local params = req:json()

    return req:render{ json = params.service }
end

function add(req)
    local params         = req:json()
    local host           = params.host
    local service        = params.service
    local ttl            = params.ttl
    local ts             = clock.time()

    box.space.tarmon:auto_increment{host, service, ts, ttl, diff}
    -- req is a Request object
    -- resp is a Response object
    local resp = req:render({text = req.method..' '..req.path })
    resp.headers['x-test-header'] = 'test';
    resp.status = 201
    return resp
end

local server = require('http.server').new(nil, 8080) -- listen *:8080
server:route({ path = '/',  }, handler)
server:route({ path = '/add',  method = 'POST'}, add)
server:start()


---- enabling console access
console = require('console')
console.listen('127.0.0.1:3302')
----os.execute("sleep " .. tonumber(10))
--
--function sleep(n)
--  os.execute("sleep " .. tonumber(n))
--end
--print('121232')
--io.flush()
----sleep(5)

--fiber = require('fiber')
--icu_date = require("icu-date")
---- Create a new date object and check result
--format_iso8601 = icu_date.formats.iso8601()
--local http_client = require('http.client').new()
--local response = http_client:get('https://ifconfig.co', {
--    headers = {
--        ['User-Agent'] = 'curl/8.4.0'
--    }
--}
--)

--function greet()
--	while true do
--        local date, err = icu_date.new({locale="en_US"}) -- default locale can be omitted
--        if err ~= nil then
--          return nil, err
--        end
--		print(date:format(format_iso8601))
--		print(response.body)
--		io.flush()
--		fiber.sleep(5)
--	end
--end
--greet_fiber = fiber.create(greet)

---- app.lua --
--fiber = require('fiber')
--

--
--greet_fiber = fiber.create(greet, 'John')
--print('Fiber already started')
--io.flush()
--
--
--while true do
--	os.execute("sleep " .. tonumber(2))
--	print('whiletrue')
--	io.flush()
--end
