local avro = require 'avro_schema'
local request_schema = require('schemas/request')
local clock = require 'clock'
local space = box.space.tarmon
local exports = {}

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

exports.add = function(req)
    local params              = req:json()
    local ok, validation_res  = avro.validate(request_schema, params)
    if not ok then
        local resp            = req:render({text = validation_res})
        resp.status           = 400
        return resp
    end

    params['seen']            = clock.time()
    params['alarm']           = params['seen'] + params['ttl']
    params['sent']            = false
    params['sentOk']          = false
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
    local resp = req:render({text = req.method..' '..req.path..' '..dump(validation_res) })
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
            params['sentOk'],
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

return exports