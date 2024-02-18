local space = box.space.tarmon
local fiber = require('fiber')
--local vk_monitoring = dofile('senders/vk_monitoring.lua')
local vk_monitoring = require('senders.vk_monitoring')
local clock = require 'clock'

local exports = {}

exports.run = function()
    while true do
        for _, record in space.index.sender:pairs( box.info.hostname ) do
            if record['sent'] == false then
                if record['alarm'] < clock.time() then
                    local send = vk_monitoring.alert.send(record['host'], record['service'])
                    local is_sent = ( send.status == 200 )
                    space:update(
                        record['id'],
                        {
                            { '+', 'sendAttempts',  1       },
                            { '=', 'sent',          is_sent },
                            { '=', 'sentOk',        false }
                        }
                    )
                end
            else
                if record['alarm'] > clock.time() and record['sentOk'] == false then
                    local send = vk_monitoring.alert.send_ok(record['host'], record['service'])
                    local is_sent = ( send.status == 200 )
                    space:update(
                            record['id'],
                            {
                                { '+', 'sendAttempts',  1       },
                                { '=', 'sentOk',        is_sent },
                                { '=', 'sent',          false }
                            }
                    )
                end
            end
        end
        fiber.sleep(3)
    end
end

return exports
