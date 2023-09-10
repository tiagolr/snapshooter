ui_snaprows = {}
function ui_refresh_buttons()
  for i, row in ipairs(ui_snaprows) do
    hassnap = reaper.GetProjExtState(0, 'snapshooter', 'snap'..i) ~= 0
    row.children[1][1]:attr('color', hassnap and 0x99BD13 or 0x999999) -- savebtn
    row.children[2][1]:attr('color', hassnap and 0xffffff or 0x777777) -- savetxt
    row.children[3][1]:attr('color', hassnap and 0x999999 or 0x555555) -- applybtn
    row.children[4][1]:attr('color', hassnap and 0xffffff or 0x777777) -- applytxt
    row.children[5][1]:attr('color', hassnap and 0x999999 or 0x555555) -- writebtn
    row.children[6][1]:attr('color', hassnap and 0xffffff or 0x777777) -- writetxt
    row.children[7][1]:attr('color', hassnap and 0x999999 or 0x555555) -- delbtn
    row.children[8][1]:attr('color', hassnap and 0xffffff or 0x777777) -- deltxt

    status, datestr = reaper.GetProjExtState(0, 'snapshooter', 'snapdate'..i)
    row.children[2][1]:attr('text', hassnap and ' '..datestr or ' Empty')
  end
end

function ui_start()
  -- package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
  -- local rtk = require('rtk')
  local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
  local rtk = dofile(script_folder .. 'rtk.lua')
  local window = rtk.Window{w=470, h=390}
  window:open{align='center'}
  local box = window:add(rtk.VBox{margin=10})
  box:add(rtk.Heading{'Snapshots', bmargin=10})

  for i = 1, 12 do
    local row = box:add(rtk.HBox{bmargin=5})
    local button = row:add(rtk.Button{circular=true})
    local text = row:add(rtk.Text{string.format("%02d",i)..' Empty', w=230, textalign='center', lmargin=10})
    button.onclick = function ()
      savesnap(i)
      ui_refresh_buttons()
    end
    local button = row:add(rtk.Button{circular=true, lmargin=5})
    local text = row:add(rtk.Text{'Apply ', lmargin=5})
    button.onclick = function ()
      applysnap(i, false)
    end
    local button = row:add(rtk.Button{circular=true, lmargin=5})
    local text = row:add(rtk.Text{'Write ', lmargin=5})
    button.onclick = function ()
      applysnap(i, true)
    end
    local button = row:add(rtk.Button{circular=true, lmargin=5})
    local text = row:add(rtk.Text{'Del ', lmargin=5, lmargin=5})
    button.onclick = function()
      clearsnap(i)
      ui_refresh_buttons()
    end
    table.insert(ui_snaprows, row)
  end

  row = box:add(rtk.HBox{tmargin=10})
  ui_checkbox_seltracks = row:add(rtk.CheckBox{'Selected tracks'})
  ui_checkbox_volume = row:add(rtk.CheckBox{'Vol', lmargin=15})
  ui_checkbox_pan = row:add(rtk.CheckBox{'Pan',lmargin=15})
  ui_checkbox_mute = row:add(rtk.CheckBox{'Mute', lmargin=15})
  ui_checkbox_sends = row:add(rtk.CheckBox{'Sends', lmargin=15})

  ui_checkbox_seltracks.onchange = function(self)
    reaper.SetProjExtState(0, 'snapshooter', 'ui_checkbox_seltracks', tostring(self.value))
  end
  ui_checkbox_volume.onchange = function(self)
    reaper.SetProjExtState(0, 'snapshooter', 'ui_checkbox_volume', tostring(self.value))
  end
  ui_checkbox_pan.onchange = function(self)
    reaper.SetProjExtState(0, 'snapshooter', 'ui_checkbox_pan', tostring(self.value))
  end
  ui_checkbox_mute.onchange = function(self)
    reaper.SetProjExtState(0, 'snapshooter', 'ui_checkbox_mute', tostring(self.value))
  end
  ui_checkbox_sends.onchange = function(self)
    reaper.SetProjExtState(0, 'snapshooter', 'ui_checkbox_sends', tostring(self.value))
  end

  local exists, seltracks_chk = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_seltracks')
  if exists and seltracks_chk == 'true' then
    ui_checkbox_seltracks:toggle()
  end
  local exists, vol_chk = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_volume')
  if exists and vol_chk == 'true' or exists == 0 then
    ui_checkbox_volume:toggle()
  end
  local exists, pan_chk = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_pan')
  if exists and pan_chk == 'true' or exists == 0 then
    ui_checkbox_pan:toggle()
  end
  local exists, mute_chk = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_mute')
  if exists and mute_chk == 'true' or exists == 0 then
    ui_checkbox_mute:toggle()
  end
  local exists, sends_chk = reaper.GetProjExtState(0, 'snapshooter', 'ui_checkbox_sends')
  if exists and sends_chk == 'true' or exists == 0 then
    ui_checkbox_sends:toggle()
  end

  ui_refresh_buttons()
end

local ui = {}
ui.start = ui_start
return ui