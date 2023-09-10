-- @description Apply param changes and snapshots to envelopes
-- @author grimiu
-- @version 1.0
-- @about
  -- Stores and retrieves params, mixer pan/vol/mute and sends pan/vol/mute snapshots
  -- Snapshooter main difference from SWS is that it stores/recalls param values instead of serializing/unserializing tracks
  -- Snapshots can be recalled to FXparams or written into the timeline

-- tofix:
  -- disable volume and sends for first release
  -- write sends change

function log(t)
  reaper.ShowConsoleMsg(t .. '\n')
end
function logtable(table, indent)
  log(tostring(table))
  for index, value in pairs(table) do -- print table
    log('    ' .. tostring(index) .. ' : ' .. tostring(value))
  end
end

function makesnap()
  local numtracks = reaper.GetNumTracks()
  local entries = {}
  for i = 0, numtracks - 1 do
    -- vol,send,mute
    local tr = reaper.GetTrack(0, i)
    local ret, vol, pan = reaper.GetTrackUIVolPan(tr)
    local ret, mute = reaper.GetTrackUIMute(tr)
    table.insert(entries, { tr, 'Volume', vol })
    table.insert(entries, { tr, 'Pan', pan })
    table.insert(entries, { tr, 'Mute', mute and 1 or 0 })
    -- sends
    local sendcount = {} -- aux send counter
    for send = 0, reaper.GetTrackNumSends(tr, 0) do
      local src = reaper.GetTrackSendInfo_Value(tr, 0, send, 'P_SRCTRACK')
      local dst = reaper.GetTrackSendInfo_Value(tr, 0, send, 'P_DESTTRACK')
      local ret, svol, span = reaper.GetTrackSendUIVolPan(tr, send)
      local ret, smute = reaper.GetTrackSendUIMute(tr, send)
      key = tostring(src)..tostring(dst)
      count = sendcount[key] and sendcount[key] + 1 or 1
      table.insert(entries, { tr, 'Send', count, key, svol, span, smute and 1 or 0 })
      sendcount[key] = count
    end
    -- fx params
    local fxcount = reaper.TrackFX_GetCount(tr)
    for j = 0, fxcount - 1 do
      fxid = reaper.TrackFX_GetFXGUID(tr, j)
      paramcount = reaper.TrackFX_GetNumParams(tr, j)
      for k = 0, paramcount - 1 do
        param = reaper.TrackFX_GetParam(tr, j, k)
        table.insert(entries, { tr, fxid , k, param })
      end
    end
  end
  return entries
end

function diff_visible(snapshot)
  -- TODO
  -- for each visible line
  -- if snapshot line
  -- add automation point
end

function difference (s1, s2)
  diff = {}
  hashmap = {}
  -- create snap2 hashmap
  for i, line2 in pairs(s2) do
    if #line2 == 3 then
      hashmap[line2[1]..line2[2]] = line2
    elseif #line2 == 4 then -- fx param
      hashmap[line2[1]..line2[2]..line2[3]] = line2
    elseif #line2 == 7 then -- sends
      hashmap[line2[1]..line2[2]..line2[3]..line2[4]] = line2
    end
  end
  -- compare s1 with s2 entries
  for i, line1 in pairs(s1) do
    if #line1 == 3 then -- volpanmute
      local line2 = hashmap[line1[1]..line1[2]]
      if line2 and line1[3] ~= line2[3] then
        table.insert(diff, line1)
      end
    elseif #line1 == 4 then -- params
      local line2 = hashmap[line1[1]..line1[2]..line1[3]]
      if line2 and line1[3] ~= line2[3] then
        table.insert(diff, line1)
      elseif line2 and line1[4] ~= line2[4] then
        table.insert(diff, line1)
      end
    elseif #line1 == 7 then -- sends
      local line2 = hashmap[line1[1]..line1[2]..line1[3]..line1[4]]
      if line2 and (line1[5] ~= line2[5] or line1[6] ~= line2[6] or line1[7] ~= line2[7]) then
        if line1[5] == line2[5] then line1[5] = 'unchanged' end
        if line1[6] == line2[6] then line1[6] = 'unchanged' end
        if line1[7] == line2[7] then line1[7] = 'unchanged' end
        table.insert(diff, line1)
      end
    end
  end
  return diff
end

-- stringify/parse snapshot for mem storage
function stringify(snap)
  local entries = {}
  for i, line in ipairs(snap) do
    for j, col in ipairs(line) do
      line[j] = tostring(col)
    end
    table.insert(entries, table.concat(line, ','))
  end
  return table.concat(entries, '\n')
end

function parse(snapstr)
  function splitline(line)
    local split = {}
    for word in string.gmatch(line, '([^,]+)') do
      table.insert(split, word)
    end
    return split
  end
  local lines = {}
  for line in string.gmatch(snapstr, '([^\n]+)') do
    table.insert(lines, splitline(line))
  end
  return lines
end

function insertSendEnvelopePoint(track, key, count, value, type)
  local count = 0
  local cursor = reaper.GetCursorPosition()
  for send = 0, reaper.GetTrackNumSends(track, 0) do
    local src = reaper.GetTrackSendInfo_Value(track, 0, send, 'P_SRCTRACK')
    local dst = reaper.GetTrackSendInfo_Value(track, 0, send, 'P_DESTTRACK')
    if tostring(src)..tostring(dst) == key then
      count = count + 1
      if count == cnt then
        local envelope = reaper.GetTrackSendInfo_Value(track, 0, send, 'P_ENV:<'..type)
        local scaling = reaper.GetEnvelopeScalingMode(envelope)
        reaper.InsertEnvelopePoint(envelope, cursor, reaper.ScaleToEnvelopeMode(scaling, vol), 0, 0, true)
        br_env = reaper.BR_EnvAlloc(envelope, false)
        active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(br_env)
        reaper.BR_EnvSetProperties(br_env, true, true, true, inLane, laneHeight, defaultShape, faderScaling)
        reaper.BR_EnvFree(br_env, 1)
      end
    end
  end
end

-- show Volume/Pan/Mute envelopes for track
function showTrackEnvelopes(track, envtype)
  if envtype == 'Volume' then
    if not reaper.GetTrackEnvelopeByName(track, 'Volume') then
      reaper.SetOnlyTrackSelected(track)
      reaper.Main_OnCommand(40406, 0) -- Set track volume visible
    end
  elseif envtype == 'Pan' then
    if not reaper.GetTrackEnvelopeByName(track, 'Pan') then
      reaper.SetOnlyTrackSelected(track)
      reaper.Main_OnCommand(40407, 0) -- Set track pan visible
    end
  elseif envtype == 'Mute' then
    if not reaper.GetTrackEnvelopeByName(track, 'Mute') then
      reaper.SetOnlyTrackSelected(track)
      reaper.Main_OnCommand(40867, 0) -- Set track mute visible
    end
  end
end

-- apply snapshot to params or write to timeline
function applydiff(diff, write)
  local numtracks = reaper.GetNumTracks()
  local cursor = reaper.GetCursorPosition()
  -- tracks hashmap
  local tracks = {}
  for i = 0, numtracks - 1 do
    tracks[tostring(reaper.GetTrack(0, i))] = i
  end
  -- fxs hashmap
  local fxs = {}
  for guid, tr in pairs(tracks) do
    track = reaper.GetTrack(0, tr)
    fxcount = reaper.TrackFX_GetCount(track)
    for j = 0, fxcount - 1 do
      fxs[reaper.TrackFX_GetFXGUID(track, j)] = j
    end
  end
  -- sends hashmap
  local sends = {}
  for i = 0, numtracks - 1 do
    track = reaper.GetTrack(0, i)
    local sendscount = {}
    for i = 0, reaper.GetTrackNumSends(track, 0) do
      local src = reaper.GetTrackSendInfo_Value(track, 0, i, 'P_SRCTRACK')
      local dst = reaper.GetTrackSendInfo_Value(track, 0, i, 'P_DESTTRACK')
      key = tostring(src)..tostring(dst)
      count = sendscount[key] and sendscount[key] + 1 or 1
      sendscount[key] = count
      sends[key..tostring(count)] = i
    end
  end
  local exists, seltracks_chkbox = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_seltracks')
  local exists, vol_chkbox = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_volume')
  local exists, pan_chkbox = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_pan')
  local exists, mute_chkbox = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_mute')
  local exists, sends_chkbox = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_sends')

  -- apply diff lines
  for i,line in ipairs(diff) do
    tr = tracks[tostring(line[1])]
    if tr ~= nil then
      local track = reaper.GetTrack(0, tr)
      if seltracks_chkbox ~= 'true' or reaper.IsTrackSelected(track) then
        if #line == 3 then -- vol/pan/mute
          param = line[2]
          value = tonumber(line[3])
          if param == 'Volume' and vol_chkbox == 'true' or
            param == 'Pan' and vol_chkbox == 'true' or
            param == 'Mute' and vol_chkbox == 'true' then
            if write then
              showTrackEnvelopes(track, line[2])
              env = reaper.GetTrackEnvelopeByName(track, param)
              if param == 'Volume' then
                local scaling = reaper.GetEnvelopeScalingMode(env)
                reaper.InsertEnvelopePoint(env, cursor, reaper.ScaleToEnvelopeMode(scaling, value), 0, 0, true)
              else
                reaper.InsertEnvelopePoint(env, cursor, value, 0, 0, true)
              end
            elseif line[2] == 'Volume' then
              reaper.SetMediaTrackInfo_Value(track, "D_VOL", value)
            elseif line[2] == 'Pan' then
              reaper.SetMediaTrackInfo_Value(track, "D_PAN", value)
            elseif line[2] == 'Mute' then
              reaper.SetMediaTrackInfo_Value(track, "B_MUTE", value)
            end
          end
        elseif #line == 4 then -- fx params
          fxid = fxs[tostring(line[2])]
          param = tonumber(line[3])
          value = tonumber(line[4])
          if fxid ~= nil then
            if write then
              env = reaper.GetFXEnvelope(track, fxid, param, true)
              reaper.InsertEnvelopePoint(env, cursor, value, 0, 0, true)
            else
              reaper.TrackFX_SetParam(track, fxid, param, value)
            end
          else
            log('fx not found '..tostring(line))
            logtable(line)
          end
        elseif #line == 7 then -- sends
          local key = line[4]
          local count = line[3]
          send = sends[key..count]
          if send and sends_chkbox == 'true' then
            -- logtable(line)
            cnt = tonumber(line[3])
            key = line[4]
            vol = line[5]
            pan = line[6]
            mut = line[7]
            if vol ~= 'unchanged' then
              if write then insertSendEnvelopePoint(track, key, cnt, tonumber(vol), 'VOLENV')
              else
                reaper.SetTrackSendUIVol(track, send, tonumber(vol), -1)
              end
            end
            if pan ~= 'unchanged' then
              if write then insertSendEnvelopePoint(track, key, cnt, tonumber(pan), 'PANENV')
              else reaper.SetTrackSendUIPan(track, send, tonumber(pan), -1) end
            end
            -- TODO send mute
            -- if mut ~= 'unchanged' then
              -- if write then insertSendEnvelopePoint(track, key, cnt, tonumber(vol), 'MUTEENV')
              -- else reaper.SetTrackSendUIMute(track, send, tonumber(mut), -1) end
              -- else reaper.SetTrackSendInfo_Value(track, 0, cnt, 'B_MUTE', tonumber(mut)) end
            -- end
          end
        end
      end
    end
  end
end

function savesnap(slot)
  slot = slot or 1
  snap = makesnap()
  reaper.SetProjExtState(0, 'snapshooter', 'snap'..slot, stringify(snap))
  reaper.SetProjExtState(0, 'snapshooter', 'snapdate'..slot, os.date())
end

function applysnap(slot, write)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  seltracks = {}
  for i = 0, reaper.CountSelectedTracks(0) do
    table.insert(seltracks, reaper.GetSelectedTrack(0, i))
  end
  globaloverride = reaper.GetGlobalAutomationOverride()
  reaper.SetGlobalAutomationOverride(6)
  exists, snap1 = reaper.GetProjExtState(0, 'snapshooter', 'snap'..slot)
  if exists then
    snap2 = makesnap()
    snap2 = parse(stringify(snap2)) -- normalize
    diff = difference(parse(snap1), snap2)
    applydiff(diff, write)
    rtk.callafter(1, reaper.UpdateArrange)
  else
    log('could not find snap'..slot)
  end
  reaper.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  for i, track in ipairs(seltracks) do
    reaper.SetTrackSelected(track, 1) -- restore selected tracks
  end
  reaper.SetGlobalAutomationOverride(globaloverride)
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock('apply snapshot', 0)
end

function clearsnap(slot)
  reaper.SetProjExtState(0, 'snapshooter', 'snap'..slot, '')
  reaper.SetProjExtState(0, 'snapshooter', 'snapdate'..slot, '')
end

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
local ui = dofile(script_folder .. 'ui.lua')
ui.start()

-- interactive dev:
  -- reaper.showConsoleMsg(¨chars¨) // show console output
  -- reaper.NamedCommandLookup('_RSad7acd2e5dbd41ab15aa68ffdb01c4c5fc82c446',0)
  -- reaper.Main_OnCommand(55863, 0)

-- TODOs
  -- help text: xx params applied
  -- envelopes to mixer
      -- if vol envelope and vol envelope is armed
      -- local ret, value, _, _, _ = reaper.Envelope_Evaluate(env, reaper.GetCursorPosition(), 0, 0)
      -- mixervolume = reaper.scaleFromEnvelope(env, value)
  -- mixer to envelopes
    -- new env point foreach mixer param foreach seltrack
  -- detect midi events for midi mapping, -- chn10 == edit/studio mode, chn11 == recording/songmode
      -- C3-C4 ch 10 == fns, update snapshots, toggle filters, split at cursor
      -- C4-C5 ch 10 == select snapshot 1-12
      -- C5-C6 ch 10 == write snapshot 1-12
      -- CX-CY ch 11 == param launch/apply snapshot
      -- CW-CZ ch 11 == param write ahead of cursor 1bar, 2bar, [triggersync], [possync] -- check grossbeat modes

--[[               33 tracks 33 params written
  [*] 1: xx/xx/xxxx :_alias       [save] [del]
  [ ] 2: empty                    [save] [del]
  [ ] 3: empty                    [save] [del]
  [ ] 4: empty                    [save] [del]
  [ ] 5: empty
  \//\

  SNAP 1
  [ APPLY ] [ WRITE ]
  [x] sel tracks [x] vol [x] pan [x] mute [x] sends

  Mixer
  [split at cursor]
  mixer vol [read][write] pan [read][write] mute [read][write]
  sends vol [read][write] pan [read][write] mute [read][write]
  [x] sel tracks
  [update sss]  -- add new instruments to snapshots


  ------ other program controls snapshots via tcp requests
  apply params 1by1 and tween them
  open TCP port with API to apply param with a certain ?curve/easing? and trigger (on beat, imeddiate, retrigger etc, check ableton)
 ]]