local vk_monitoring = {alert = {}}
--local cfg = dofile('config.lua')
local cfg = require('conf')

local function dump(o)
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

print(dump(cfg))
local api_url = cfg.api_url
local api_key = cfg.api_key
print('API_URL: '..api_url, 'API_KEY: '..api_key)
local http_client = require('http.client').new()

vk_monitoring.alert.create = function(status, host, service, msg)
    return {{
    status = status,
    service = 'TarMon',
    subservice = service,
    monitorhost = box.info.hostname,
    server = host,
    msg = msg,
    sms = "0"
    }}
end

vk_monitoring.alert.send = function(host, service)
    local response = http_client:post(api_url, {
        objects = vk_monitoring.alert.create(3, host, service, "Didn't receive a heartbeat from service")
    }, {
        headers = {
            ['Content-Type'] = 'application/json',
            ['AUTHORIZATION'] = 'token ' .. api_key
        }
    })
    print('Status: '..response.status..' '.. response.reason)
    return response
end

vk_monitoring.alert.send_ok = function(host, service)
    local response = http_client:post(api_url, {
        objects = vk_monitoring.alert.create(0, host, service, "Received a heartbeat from service")
    }, {
        headers = {
            ['Content-Type'] = 'application/json',
            ['AUTHORIZATION'] = 'token ' .. api_key,
        }
    })
    print('Status: '..response.status..' '.. response.reason)
    return response
end

return vk_monitoring