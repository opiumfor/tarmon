#!/usr/bin/env tarantool

local clock = require 'clock'
local avro = require 'avro_schema'
local json = require 'json'

local ok, schema = avro.create {
    type   = "record",
    name   = "entry_schema",
    fields = {
        { name = 'host',            type = 'string'   },
        { name = 'service',         type = 'string'   },
        { name = 'ttl',             type = 'double'   }
    }
}
-- Configure database
box.cfg {
    listen              = 3301,
    work_dir            = '.',
    wal_dir             = 'wal',
    memtx_dir           = 'memtx',
    checkpoint_count    = 100,
    checkpoint_interval = 60
}
box.once("bootstrap", function()
    box.schema.space.create('tarmon')
    box.space.tarmon:format({
        { name = 'id',              type = 'unsigned' },
        { name = 'host',            type = 'string'   },
        { name = 'service',         type = 'string'   },
        { name = 'seen',            type = 'double'   },
        { name = 'ttl',             type = 'double'   },
        { name = 'alarm',           type = 'double'   },
        { name = 'sender',          type = 'string'   },
        { name = 'sent',            type = 'boolean'  },
        { name = 'sendAttempts',    type = 'unsigned' },
        { name = 'sendLockTTL',     type = 'unsigned' },
        { name = 'sendLockTS',      type = 'double'   },
        { name = 'lastSendAttempt', type = 'double'   }
    })
    box.schema.sequence.create('id_seq',{min=1000, start=1000})
    box.space.tarmon:create_index('primary', { sequence = 'id_seq' })
    box.space.tarmon:create_index('alarm',
        { type = 'TREE', parts = { 'alarm' }, unique = false})
    box.space.tarmon:create_index('host_service',
        { type = 'TREE', parts = { { 'host' }, { 'service' } }, unique = true })
    box.space.tarmon:create_index('sender',
        { type = 'TREE', parts = { 'sender' }, unique = false })
end)

local space = box.space.tarmon

local function handler(req)
    local params = req:json()
    return req:render{ json = params.service }
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local function add(req)
    local params              = req:json()
    ok, validationResult      = avro.validate(schema, params)
    if not ok then
        local resp            = req:render({text = validationResult})
        resp.status           = 400
        return resp
    end

    params['seen']            = clock.time()
    params['alarm']           = params['seen'] + params['ttl']
    params['sent']            = false
    params['sender']          = ''
    params['sendAttempts']    = 0
    params['sendLockTTL']     = 0
    params['sendLockTS']      = 0
    params['lastSendAttempt'] = 0

    local function get_host_service()
        if space.index.host_service and space.index.host_service:count() > 0 then
            return space.index.host_service:get {params['host'], params['service']}
        end
        return nil
    end
    local host_service = get_host_service()
    -- req is a Request object
    -- resp is a Response object
    local resp = req:render({text = req.method..' '..req.path..' '..dump(validationResult) })
    resp.headers['Server'] = 'TarMon v0.1';

    if not host_service then
        space:insert {
            nil,
            params['host'],
            params['service'],
            params['seen'],
            params['ttl'],
            params['alarm'],
            params['sender'],
            params['sent'],
            params['sendAttempts'],
            params['sendLockTTL'],
            params['sendLockTS'],
            params['lastSendAttempt']
        }
        resp.status = 201
    else
        space:update(
        host_service['id'],
        {
            { '=', 'seen',   params['seen']  },
            { '=', 'ttl',    params['ttl']   },
            { '=', 'alarm',  params['alarm'] }
        }
    )
    resp.status = 200
    end
    return resp
end

local server = require('http.server').new(nil, 8080) -- listen *:8080
server:route({ path = '/',  }, handler)
server:route({ path = '/add',  method = 'POST'}, add)
server:start()


---- enabling console access
console = require('console')
console.listen('127.0.0.1:3302')

fiber = require('fiber')
local function alarming()
    local space          = box.space.tarmon
    while true do
        if space.index.alarm then
            print('PENDING:')
            --for _, tuple in space.index.alarm:select({ clock.time() }, { iterator = 'LT', limit = 44 }) do
            local formattedResult = space.index.alarm:gselect({ clock.time() }, { iterator = 'LT', limit = 44 },{fselect_print=true})
            print(formattedResult)
            local result = space.index.alarm:select({ clock.time() }, { iterator = 'LT', limit = 44 })

            for num, record in pairs(result) do
                --print(num, record['host'], record['service'], 'Seconds remaining: ' .. record['sendLockTS'] - clock.time())
                if record['sender'] == '' then
                    space:update(
                            record['id'],
                            {
                                { '=', 'sender',        box.info.hostname  },
                                { '=', 'sendLockTTL',   20                 },
                                { '=', 'sendLockTS',    20 + clock.time()  }
                            }
                    )
                else
                    if record['sendLockTS'] < clock.time() and not record['sent'] then
                        space:update(
                                record['id'],
                                {
                                    { '=', 'sender',      '' },
                                    { '=', 'sendLockTTL', 0  },
                                    { '=', 'sendLockTS',  0  }
                                }
                        )
                    end
                end
            end
        io.flush()
        fiber.sleep(5)
        end
    end
end

local function sendAlerts()
    while true do
        local function maybe(x) if math.random() < x then return true else return false end end
        local sent = maybe(0.1)
        local result = space.index.sender:select( box.info.hostname )
        for num, record in pairs(result) do
            if record['sent'] == false then
                space:update(
                        record['id'],
                        {
                            { '+', 'sendAttempts',  1    },
                            { '=', 'sent',          sent }
                        }
                )
            end
        end
        fiber.sleep(3)
    end
end

alarm_fiber = fiber.create(alarming)
sender_fiber = fiber.create(sendAlerts)
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
