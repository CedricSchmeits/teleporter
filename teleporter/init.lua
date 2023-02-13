---
--Teleporter 1.07
--Copyright (C) 2012 Bad_Command
--
--This library is free software; you can redistribute it and/or
--modify it under the terms of the GNU Lesser General Public
--License as published by the Free Software Foundation; either
--version 2.1 of the License, or (at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU General Public License for more details.
--
--You should have received a copy of the GNU Lesser General Public
--License along with this library; if not, write to the Free Software
--Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
----

teleporter = {}
teleporter.version = 1.08

-- config.lua contains configuration parameters
dofile(minetest.get_modpath("teleporter").."/config.lua")

local function set_teleporter_formspec(meta)
    meta:set_string("formspec",
        "formspec_version[4]" ..
        "size[10.0,3.5]" ..
        "image[0.5,0.5;1.0,1.0;" .. teleporter.tile_image .. "]" ..
        "label[1.8,1.1;Teleport to " .. meta:get_string("desc") .. "]" ..
        "field[0.5,1.8;1.1,0.5;x;X;" .. meta:get_float("x") .. "]" ..
        "field[1.7,1.8;1.1,0.5;y;Y;" .. meta:get_float("y") .. "]" ..
        "field[2.9,1.8;1.1,0.5;z;Z;" .. meta:get_float("z") .. "]" ..
        "field[5.0,1.8;3.5,0.5;desc;Description;" .. meta:get_string("desc") .. "]")
end

minetest.register_craft({
    output = 'teleporter:teleporter_pad',
    recipe = {
                {'moreores:copper_ingot', 'default:glass', 'moreores:copper_ingot'},
                {'moreores:copper_ingot', 'moreores:gold_block', 'moreores:copper_ingot'},
                {'moreores:copper_ingot', 'mesecons_powerplant:power_plant', 'moreores:copper_ingot'},
        }
})

minetest.register_craft({
    output = 'teleporter:teleporter_pad',
    recipe = {
                {'default:wood', 'default:glass', 'default:wood'},
                {'default:wood', 'default:mese', 'default:wood'},
                {'default:wood', 'default:wood', 'default:wood'},
        }
})

minetest.register_node("teleporter:teleporter_pad", {
    tiles = {teleporter.tile_image},
    drawtype = "nodebox",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    description="Teleporter Pad",
    inventory_image = teleporter.tile_image,
    wield_image = teleporter.tile_image,
    legacy_wallmounted = true,
    light_source = 2,
    --sounds = default.node_sound_defaults(),
    groups = {choppy=2, dig_immediate=2, attached_node=1},
    node_box = {
        type = "wallmounted",
        wall_top = {-0.4375, 0.4375, -0.4375, 0.4375, 0.5, 0.4375},
        wall_bottom = {-0.4375, -0.5, -0.4375, 0.4375, -0.4375, 0.4375},
        wall_side = {-0.5, -0.4375, -0.4375, -0.4375, 0.4375, 0.4375},
    },
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)

        --meta:set_string("formspec", "hack:sign_text_input")
        meta:set_string("infotext", "\"Teleport to "..teleporter.default_coordinates.desc.."\"")
        meta:set_float("enabled", -1)
        meta:set_string("desc", teleporter.default_coordinates.desc)
        meta:set_float("x", teleporter.default_coordinates.x)
        meta:set_float("y", teleporter.default_coordinates.y)
        meta:set_float("z", teleporter.default_coordinates.z)
        set_teleporter_formspec(meta)
    end,

    after_place_node = function(pos, placer)
        local meta = minetest.get_meta(pos)
        local name = placer:get_player_name()
        meta:set_string("owner", name)
        set_teleporter_formspec(meta)

        if teleporter.perms_to_build and not minetest.get_player_privs(name)["teleport"] then
            minetest.chat_send_player(name, 'Teleporter:  Teleport privileges are required to build teleporters.')
            minetest.remove_node(pos)
            minetest.add_item(pos, 'teleporter:teleporter_pad')
        else
            meta:set_float("enabled", 1)
        end
    end,

    on_receive_fields = function(pos, formname, fields, sender)
        if not fields.x then
            return
        end

        local coords = teleporter.coordinates(fields)
        local meta = minetest.get_meta(pos)
        local name = sender:get_player_name()
        local privs = minetest.get_player_privs(name)

        if name ~= meta:get_string("owner") and not privs["server"] then
            minetest.chat_send_player(name, 'Teleporter:  This is not your teleporter, it belongs to '..meta:get_string("owner"))
            return false
        else if privs["server"] then
            minetest.chat_send_player(name, 'Teleporter:  This teleporter belongs to '..meta:get_string("owner"))
        end

        if teleporter.perms_to_configure and not privs["teleport"] then
            minetest.chat_send_player(name, 'Teleporter:  You need teleport privileges to configure a teleporter')
            return
        end

        local infotext = ""
        if coords~=nil then
            meta:set_float("x", coords.x)
            meta:set_float("y", coords.y)
            meta:set_float("z", coords.z)
            if teleporter.requires_pairing and not teleporter.is_paired(coords) and not privs["server"] then
                minetest.chat_send_player(name, 'Teleporter:  There is no recently-used teleporter pad at the destination!')
                infotext="Teleporter is Disabled"
                meta:set_float("enabled", -1)
            else
                meta:set_float("enabled", 1)
                if coords.desc~=nil then
                    meta:set_string("desc", coords.desc)
                    infotext="Teleport to "..coords.desc
                else
                    infotext="Teleport to "..coords.x..","..coords.y..","..coords.z..""
                end
            end
        else
            minetest.chat_send_player(name, 'Teleporter:  Incorrect coordinates.  Enter them as \'X,Y,Z,Description\' without decimals.')
            meta:set_float("enabled", -1)
            infotext="Teleporter Offline"
        end

        print((sender:get_player_name() or "").." entered \"" .. fields.x .. "," .. fields.y .. "," .. fields.z ..
                        "\" to teleporter at "..minetest.pos_to_string(pos))
        meta:set_string("infotext", '"'..infotext..'"')
        set_teleporter_formspec(meta)
        end
    end,

    can_dig = function(pos,player)
        local meta = minetest.get_meta(pos)
        local name = player:get_player_name()
        local privs = minetest.get_player_privs(name)
        if name == meta:get_string("owner") or privs["server"] then
            return true
        end
        return false
    end
})

teleporter.is_paired = function(coords)
    for dx=-teleporter.pairing_check_radius,teleporter.pairing_check_radius do
        for dy=-teleporter.pairing_check_radius,teleporter.pairing_check_radius do
            for dz=-teleporter.pairing_check_radius,teleporter.pairing_check_radius do
                local node = minetest.get_node({x=coords.x + dx, y=coords.y + dy, z=coords.z + dz})
                if node.name == 'teleporter:teleporter_pad' then
                    return true
                end
            end
        end
    end
    return false
end

teleporter.coordinates = function(fields)
    local x = fields.x
    local y = fields.y
    local z = fields.z
    local desc = fields.desc

    if desc=="" then
        desc = nil
    end

    if x==nil or y==nil or z==nil or
        string.len(x) > 6 or string.len(y) > 6 or string.len(z) > 6 then
            return nil
    end

    x = x + 0.0
    y = y + 0.0
    z = z + 0.0

    if x > 32765 or x < -32765 or y > 32765 or y < -32765 or z > 32765 or z < -32765 then
        return nil
    end

    return {x=x, y=y, z=z, desc=desc}
end


minetest.register_abm(
    {nodenames = {"teleporter:teleporter_pad"},
    interval = 1.0,
    chance = 1,
    action = function(pos, node, active_object_count, active_object_count_wider)
        local objs = minetest.get_objects_inside_radius(pos, 1)
        for k, player in pairs(objs) do
            if player:is_player() then
                local meta = minetest.get_meta(pos)
                if meta:get_float("enabled") > 0 then
                    local target_coords={x=meta:get_float("x"), y=meta:get_float("y"), z=meta:get_float("z")}
                    minetest.sound_play("teleporter_teleport", {pos = pos, gain = 1.0, max_hear_distance = 10,})
                    player:move_to(target_coords, false)
                    minetest.sound_play("teleporter_teleport", {pos = target_coords, gain = 1.0, max_hear_distance = 10,})
                end
            else
            end
        end
    end
})
