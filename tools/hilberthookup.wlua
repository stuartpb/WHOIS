--Tool to configure seed person data for WHOIS.

local iup = require "iuplua"
local cd = require "cdlua"
require "iupluacd"

require "cdluacontextplus"
cd.UseContextPlus(1)

local json = require'dkjson'.use_lpeg()

-- Local toolbox --------------------------------------------------
local floor = math.floor
local ceil = math.ceil

-- Data serialization and synthesis -------------------------------

-- The array of person tables.
local people
-- The layout of people nodes.
local nodes
-- Reverse lookup of names to coordinates, indices, and incoming connections.
local lookup

--Input parsing.
local function parse_colon_list(filename)
  people = {}
  local file = io.open(filename)
  for line in file:lines() do
    local name, desc = line:match"^(.-)%:%s*(.-)$"
    people[#people+1] = {name = name, body = desc, links = {}}
  end
  file:close()
end

local function parse_json(filename)
  local file = io.open(filename)
  local content = file:read"*a"
  file:close()
  people = json.decode(content, 1, nil, nil, nil)
end

-- Make the node layout and store the coordinates.
local function populate()
  --Determine necessary power of two to fit all nodes.
  local n = 1
  while 2^n < #people do
    n=n+1
  end

  nodes = {}
  for i=1, 2^n do
    nodes[i] = {}
  end
  positions = {}

  local function d2xy(d)
    local x, y = 0, 0
    local s = 1
    local t = d
    while s < n do
      -- determine rotation
      local rx = floor(t/2) % 2 ~= 0
      local ry = not ((t%2 ~= 0) == rx)
      -- rotate
      if not ry then
        if rx then
          x = s-1 - x
          y = s-1 - y
        end
        x, y = y, x
      end

      if rx then
        x = x + s
      end
      if ry then
        y = y + s
      end
      t = floor(t/4)
      s = s * 2
    end
    return x, y
  end

  -- populate nodes and positions
  for d=1, #people do
    local x, y = d2xy(d)
    nodes[y+1][x+1] = people[d]
    positions[people[d].name] = {d=d, x=x, y=y, inbound = {}}
  end
  -- populate incoming connections
  for d=1, #people do
    for i, similar in pairs(people[d].links) do
      table.insert(lookup[similar].inbound,people[d].name)
    end
  end

end

local function save_people(filename)
  local file = io.open(filename, 'w')
  file:write(json.encode(people,{
    indent = true,
    keyorder = {"name","body","links"},
    }))
  file:close()
end

-- Parameters -----------------------------------------------------
-- Diameter of a node
local node_diam = 100
-- The gap between nodes.
local node_gap = 40
-- The first connection width.
local bandw = 25
-- The reduction in size of each successive band.
local bandr = 2

-- Variables ------------------------------------------------------
--The name of the active person node.
local active_person = 1
local zoom = 1
local topcorner = 50
local leftcorner = 50

-- Dialogs --------------------------------------------------------
local function file_dlg(
  dlg_type, dlg_title, dlg_extfilter,
  filename_operation)

  local filedlg = iup.filedlg{
    dialogtype = dlg_type,
    title = dlg_title,
    extfilter = dlg_extfilter
  }

  filedlg:popup()

  local status = tonumber(filedlg.status)

  if status > -1 then --not canceled
    filename_operation(filedlg.value)
  end

end

local function open_list()
  file_dlg("OPEN",
    "Open Colon-Separated List",
    "All Files|*.*|",
    function(filename)
      parse_colon_list(filename)
      populate()
    end)
end

local function open_json()
  file_dlg("OPEN",
    "Open JSON List",
    "JSON Files|*.json|"..
    "All Files|*.*|",
    function(filename)
      parse_json(filename)
      populate()
    end)
end

local function save_json()
  file_dlg("Save",
    "Save JSON List",
    "JSON Files|*.json|"..
    "All Files|*.*|",
    function(filename)
      save_people(filename)
    end)
end

-- Window ---------------------------------------------------------
local menu = iup.menu{
  {"File",iup.menu{
    iup.item{title="Open Colon-Separated List...",
      action=open_list},
    iup.item{title="Open JSON List...",
      action=open_json},
    {},
    iup.item{title="Save People...",
      action=save_json},
    iup.item{title="Exit",
      action=iup.ExitLoop},
  }},
}

local canvas = iup.canvas{}
local desc = iup.text{expand="horizontal"}
local descsave = iup.button{title="Save"}
local dlg = iup.dialog{
  menu = menu,
  title = "WHOIS it?",
  shrink = "yes",
  size="HALFxHALF";
  iup.vbox{
    canvas,
      iup.hbox{
        desc,
        descsave}}}
--TODO: Label / textbox with number of characters in description
--TODO: Toggles for which connections are visible

-- Coordination ---------------------------------------------------
local nodexy_to_screenxy, screenxy_to_nodexy
do
  local function sc_from_nc(nc)
    return node_diam * (nc-.5)
      + node_gap * (nc-1)
  end

  function nodexy_to_screenxy(x,y)
    return topcorner + (sc_from_nc(x) * zoom),
      leftcorner + (sc_from_nc(y) * zoom)
  end

  function screenxy_to_nodexy(sx,sy)
    local cell_size = (node_diam + node_gap) * zoom
    local function cell_of_sc(sc)
      return ceil(sc/cell_size)
    end
    local nx, ny = cell_of_sc(sx-topcorner), cell_of_sc(sy-leftcorner)
    --Center of node on screen
    local cx, cy = sc_from_nc(nx), sc_from_nc(ny)

    -- If the cell is within range
    if nx < 0 and ny < 0 and nx >= #nodes and ny >= #nodes
    --And the screen coordinate is within the node for its cell
      and sqrt((cx-sx)^2 + (cx-sx)^2) < node_diam/2
    then return nx, ny
    --return nil for non-node screen coordinates
    else return nil
    end
  end
end

-- Viewport -------------------------------------------------------

local can
function canvas:map_cb()
  can=cd.CreateCanvas(cd.IUP,self)
  can:YAxisMode(0)
  can:Flush()
end

function canvas:action()
  can:Activate()
  local w, h = can:GetSize()
  can:Clear()
  can:TextAlignment(cd.CENTER)
  if nodes then
    can:TextOrientation(45)
    for ny=1, #nodes do
      for nx=1, #nodes do
      local node = nodes[ny][nx]
        if node then
          local sx, sy = nodexy_to_screenxy(nx,ny)
          can:Foreground(cd.GRAY)
          can:Sector(sx,sy,node_diam,node_diam,0,360)
          can:Foreground(cd.BLACK)
          can:Text(sx,sy,node.name)
        end
      end
    end
  else
    can:TextAlignment(cd.CENTER)
    can:TextOrientation(0)
    can:Foreground(cd.YELLOW)
    can:Sector(w/2,h/2,40,40,0,360)
    can:Foreground(cd.BLACK)
    can:Text(w/2,h/2,"load some people")
  end
  can:Flush()
end

-- Action ---------------------------------------------------------

dlg:show()
iup.MainLoop()
