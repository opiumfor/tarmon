local space = box.space.tarmon
local fiber = require('fiber')

local exports = {}

exports.run = function()
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

return exports