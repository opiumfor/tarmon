#!/usr/bin/env tarantool
local clock = require 'clock'
local recordFields = require('models/record')

---- Configure database
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
    box.space.tarmon:format(recordFields)
    box.schema.sequence.create('id_seq',{min=1000, start=1000})
    box.space.tarmon:create_index('primary', { sequence = 'id_seq' })
    box.space.tarmon:create_index('alarm',
        { type = 'TREE', parts = { 'alarm' }, unique = false})
    box.space.tarmon:create_index('host_service',
        { type = 'TREE', parts = { { 'host' }, { 'service' } }, unique = true })
    box.space.tarmon:create_index('sender',
        { type = 'TREE', parts = { 'sender' }, unique = false })
end)

---- run http-api
local server = require('http.server').new(nil, 8080) -- listen *:8080
server:route({ path = '/add',  method = 'POST'}, 'record#add')
server:start()

---- enable console access
console = require('console')
console.listen('127.0.0.1:3302')

---- run scheduler
local fiber = require('fiber')
local scheduler = require('fibers/scheduler')
scheduler_fiber = fiber.create(scheduler.run)

---- run sender
local sender = require('fibers/sender')
sender_fiber = fiber.create(sender.run)
