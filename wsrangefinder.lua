--[[
Copyright © 2020, Silvermutt of Asura
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of DistancePlus nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Sammeh BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'WSRangefinder'
_addon.author = 'Silvermutt'
_addon.version = '1.0'
_addon.command = 'wsrf'

res = require 'resources'
config = require('config')
texts = require('texts')
inspect = require('inspect')
packets = require('packets')

defaults = {}
defaults.wstxt = {}
defaults.wstxt.pos = {}
defaults.wstxt.pos.x = -220
defaults.wstxt.pos.y = 45
defaults.wstxt.text = {}
defaults.wstxt.text.font = 'Arial'
defaults.wstxt.text.size = 10
defaults.wstxt.flags = {}
defaults.wstxt.flags.right = true

height_upper_threshold = 8.5
height_lower_threshold = -7.5

settings = config.load(defaults)
ws = texts.new('${value}', settings.wstxt)

show_ws = false

range_mult = {
  [2] = 1.55,
  [3] = 1.490909,
  [4] = 1.44,
  [5] = 1.377778,
  [6] = 1.30,
  [7] = 1.15,
  [8] = 1.25,
  [9] = 1.377778,
  [10] = 1.45,
  [11] = 1.454545454545455,
  [12] = 1.666666666666667,
}

function displayws(s, t)
  local list = 'Weapon Skills:\n'

  if wslist then

    for key,ws in pairs(wslist) do
      ws_name = res.weapon_skills[ws].name
      ws_range = res.weapon_skills[ws].range

      local is_out_of_range = isOutOfRange(ws_range, s, t)

      if ws_name then
        if t and t.distance:sqrt() ~= 0 and not is_out_of_range then 
          list = list..'\\cs(0,255,0)'..ws_name..'\\cs(255,255,255)'..'\n'
        else
          list = list..'\\cs(255,255,255)'..ws_name..'\n'
        end
      end
    end
  end
  ws.value = list
  ws:visible(show_ws)
end

-- 'ws_range' expected to be the range pulled from weapon_skills.lua
-- 's' is self player object
-- 't' is target object
function isOutOfRange(ws_name, s, t)
  if ws_name == nil or s == nil or t == nil then
    return true
  end

  local distance = t.distance:sqrt()
  local is_out_of_range = distance > (t.model_size + ws_range * range_mult[ws_range] + s.model_size)

  return is_out_of_range
end

-- Runs in a loop
windower.register_event('prerender', function()
  local t = windower.ffxi.get_mob_by_target('t') or windower.ffxi.get_mob_by_target('st')
  local s = windower.ffxi.get_mob_by_target('me')
  
  if t and show_ws then
    displayws(s,t)
  end
end)

windower.register_event('addon command', function(command)
  if command:lower() == 'help' then
    windower.add_to_chat(8,'WSRangefinder: Valid commands are //wsrf <command>:')
    windower.add_to_chat(8, 'wslist: Toggles display of list.')
  elseif command:lower() == 'wslist' or command:lower() == 'list' or command:lower() == 'showlist'
      or command:lower() == 'show' or command:lower() == 'visible' then
    if show_ws then
      show_ws = false
    else
      windower.add_to_chat(8,'Showing List')
      show_ws = true
      displayws()
    end
  elseif command:lower() == 'reload' or command:lower() == 'r' then
    windower.send_command('lua r wsrangefinder')
  end
end)

windower.register_event('job change', function()
  coroutine.sleep(2) -- sleeping because jobchange too fast doesn't show new abilities
  self = windower.ffxi.get_player()
  wslist = windower.ffxi.get_abilities().weapon_skills
  ws:visible(false)
  ws.value = ""
  displayws()
end)

windower.register_event('load', function()
  if windower.ffxi.get_player() then 
    coroutine.sleep(2) -- sleeping because jobchange too fast doesn't show new abilities
    self = windower.ffxi.get_player()
    wslist = windower.ffxi.get_abilities().weapon_skills
    displayws()
  end
end)

windower.register_event('login', function()
  coroutine.sleep(2) -- sleeping because jobchange too fast doesn't show new abilities
  self = windower.ffxi.get_player()
  wslist = windower.ffxi.get_abilities().weapon_skills
  displayws()
end)

-- TODO: Update ws list when main or ranged changes.

-- Intercept outgoing ws action packets and cancel if out of range
windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
  if id == 0x01A then -- Outgoing action command
    local packet = packets.parse('outgoing', data)
    local category = packet.Category -- Type of ability (WS is 7)
    local ws_id = packet.Param -- WS ID
    local targetId = packet.Target -- Target ID
    
    -- We only care about WS actions (category 7 and ID 1-255)
    if category == 7 and ws_id <= 255 then
      local ws = res.weapon_skills[ws_id]
      local player = windower.ffxi.get_mob_by_target('me')
      local target = windower.ffxi.get_mob_by_id(targetId)
  
      -- If not valid WS, block packet
      -- Invalid conditions:
      --    Player is targeting self with WS
      --    Attempting to WS while out of range of target
      if player.id == targetId then
        return true
      end
      if isOutOfRange(ws.range, player, target) then
        windower.add_to_chat(167, 'Stopping WS. Target out of range.')
        return true
      end
    end
  end
end)
