local space = box.space.tarmon
local fiber = require('fiber')
local vk_monitoring = dofile('senders/vk_monitoring.lua')


local exports = {}

exports.run = function()
    while true do
        local result = space.index.sender:select( box.info.hostname )
        for _, record in pairs(result) do
            if record['sent'] == false then
                local send = vk_monitoring.alert.send(record['host'], record['service'])
                local is_sent = ( send.status == 200 )
                print( send.reason )
                space:update(
                        record['id'],
                        {
                            { '+', 'sendAttempts',  1    },
                            { '=', 'sent',          is_sent }
                        }
                )
            end
        end
        fiber.sleep(3)
    end
end

return exports
