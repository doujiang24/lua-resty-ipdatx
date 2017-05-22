-- Copyright (C) 2016 doujiang24

local bit = require "bit"

local lshift = bit.lshift
local str_byte = string.byte
local str_find = string.find
local str_sub = string.sub


local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

--[[
    datx file format in bytes:

        -----------
        | 4 bytes |                     <- offset number
        -----------------
        | 256 * 256 * 4 bytes |         <- first two ip number index
        -----------------------
        | offset - 262144 bytes |       <- ip index
        -----------------------
        |    data  storage    |
        -----------------------
]]--



local _M = { _VERSION = "0.01" }

local mt = { __index = _M }


local pow32 = math.pow(2, 32)

local CONTENT, OFFSET, NUM


local function _explode(str, sep, n)
    local t = new_tab(n, 0)

    local from = 1
    local i = 1

    while true do
        local to = str_find(str, sep, from, true)
        if not to then
            break
        end

        t[i] = str_sub(str, from, to - 1)
        i = i + 1

        from = to + 1
    end

    if i ~= n then
        return
    end

    t[i] = str_sub(str, from)

    return t
end


local function _uint32(a, b, c, d)
    if a and b and c and d then
        local u = lshift(a, 24) + lshift(b, 16) + lshift(c, 8) + d
        if u < 0 then
            u = u + pow32
        end
        return u
    end
end


local function _read_file(file)
    local fp, err = io.open(file, "r")
    if not fp then
        return nil, err
    end

    local data, err = fp:read("*a")

    fp:close()

    return data, err
end


function _M.init(file, data, num)
    local content = data

    if file then
        local data, err = _read_file(file)
        if not data then
            return nil, err
        end

        content = data
    end

    if not content then
        return nil, "invalid args"
    end

    -- big endian
    local offset = _uint32(str_byte(content, 1, 4))
    if not offset or offset < 256 * 256 * 4 + 4 then
        return nil, "invalid ipdatx"
    end

    CONTENT = content
    OFFSET = offset
    NUM = num or 13

    return true
end


function _M.query(ip)
    local content = CONTENT
    local data_offset = OFFSET

    if not content then
        return nil, "not inited"
    end

    local m = _explode(ip, ".", 4)
    if not m then
        return nil, "invalid ip"
    end

    local int = _uint32(m[1], m[2], m[3], m[4])

    local ip_offset = (m[1] * 256 + m[2]) * 4 + 4

    -- little endian
    local start = _uint32(content:byte(ip_offset + 4),
                          content:byte(ip_offset + 3),
                          content:byte(ip_offset + 2),
                          content:byte(ip_offset + 1))

    local max_comp_len = data_offset - 262144

    for i = start * 9 + 262144 + 5, max_comp_len, 9 do
        if int <= _uint32(str_byte(content, i, i + 4)) then
            -- little endian
            local index_offset = _uint32(0, str_byte(content, i + 6),
                                         str_byte(content, i + 5),
                                         str_byte(content, i + 4))

            -- big endian
            local length = str_byte(content, i + 7) * 8
                           + str_byte(content, i + 8)

            local offset = data_offset + index_offset - 262144

            local str = str_sub(content, offset + 1, offset + length)
            return _explode(str, "\t", NUM)
        end
    end

    -- actually seems impossible here
    return nil, "not found"
end


return _M
