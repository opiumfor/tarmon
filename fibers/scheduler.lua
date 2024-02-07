local clock = require 'clock'
local space = box.space.tarmon
local fiber = require('fiber')

local exports = {}

exports.run = function()
    while true do
        if space.index.alarm then
            print('PENDING:')
            --for _, tuple in space.index.alarm:select({ clock.time() }, { iterator = 'LT', limit = 44 }) do
            local formattedResult = space.index.alarm:gselect({ clock.time() }, { iterator = 'LT', limit = 44 },{fselect_print=true})
            print(formattedResult)
            local result = space.index.alarm:select({ clock.time() }, { iterator = 'LT', limit = 44 })

            for _, record in pairs(result) do
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

return exports
