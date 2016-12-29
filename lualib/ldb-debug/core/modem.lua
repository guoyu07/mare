local class = require('ldb-debug/utils/oo').class
local serializer = require('ldb-debug/utils/serializer')
local packager = require('ldb-debug/utils/packager')

local Modem = class({

    constructor = function(self, iostream)
        self.iostream = iostream;
        self.listeners = {}
        self.chunk = ''
    end,

    on = function(self, event, listener)
        self.listeners[event] = listener
    end,

    emit = function(self, event, ...)
        local listener = self.listeners[event]
        if listener then
            listener(...)
        end
    end,

    connect = function(self)
        self.chunk = ''
        self.iostream:close()
        if self.iostream:open() then
            self:emit('connect')
        end
    end,

    feed = function(self, data)
        if not data or data == '' then
            return
        end

        local buffer = self.chunk .. data
        local chunk, pkgs
        chunk, pkgs = packager.parse(buffer)
        self.chunk = chunk

        for _, pkg in ipairs(pkgs) do
            local cmd = serializer.decode(pkg)
            self:emit('command', cmd)
        end
    end,

    write = function(self, data)
        local ok = self.iostream:write(data)
        return ok
    end,

    read = function(self, timeout)
        local ok, data = self.iostream:read(timeout)
        if ok then
            self:feed(data)
        end
    end,

    send = function(self, op, args)
        if not self:is_connecting() then
            return
        end

        local pkg = serializer.encode({op, args})
        local data = packager.dump(pkg)
        if self:write(data) then
            self:read()
        end
    end,

    recv = function(self, timeout)
        if not self:is_connecting() then
            return
        end
        self:read(timeout)
    end,

    is_connecting = function(self)
        return self.iostream:is_opened()
    end,

})

return {
    Modem = Modem,
}
