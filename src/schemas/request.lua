local avro = require 'avro_schema'

local _, schema = avro.create {
    type   = "record",
    name   = "entry_schema",
    fields = {
        { name = 'host',            type = 'string'   },
        { name = 'service',         type = 'string'   },
        { name = 'ttl',             type = 'double'   }
    }
}
return schema

