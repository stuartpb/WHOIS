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
local max = math.max
local min = math.min
local sqrt = math.sqrt

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
local active_person
--The zoom multiplier.
local zoom = 1
-- The center of the viewport.
local center = {x=0, y=0}
-- The edges and dimensions of the viewport.
-- Updated when moving and resizing.
local viewport = {width=0, height=0, left=0, right=0, top=0, bottom=0}

-- Forward declaration --------------------------------------------
local post_load

-- Data serialization and synthesis -------------------------------

-- The array of person tables.
local people
-- The layout of people nodes.
local nodes
-- Reverse lookup of names to coordinates, indices, and incoming connections.
local lookup

--Input parsing.
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
  while n^2 < #people do
    n = n * 2
  end

  nodes = {}
  for i=1, n do
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
    local x, y = d2xy(d-1)
    nodes[y+1][x+1] = people[d]
    positions[people[d].name] = {d=d, x=x+1, y=y+1, inbound = {}}
  end
  -- populate incoming connections
  for d=1, #people do
    for i, similar in pairs(people[d].links) do
      table.insert(lookup[similar].inbound,people[d].name)
    end
  end

  local midx, midy = d2xy(floor(#people/2))
  --center.x = midx * (node_diam + node_gap)
  --center.y = midy * (node_diam + node_gap)

  --Update the canvas
  post_load()
end

local function save_people(filename)
  local file = io.open(filename, 'w')
  file:write(json.encode(people,{
    indent = true,
    keyorder = {"name","body","links"},
    }))
  file:close()
end

-- Dialogs --------------------------------------------------------
local function file_dlg(
  dlg_type, dlg_title, default_file,
  dlg_extfilter,
  filename_operation)

  local filedlg = iup.filedlg{
    dialogtype = dlg_type,
    title = dlg_title,
    extfilter = dlg_extfilter,
    file = default_file
  }

  filedlg:popup()

  local status = tonumber(filedlg.status)

  if status > -1 then --not canceled
    filename_operation(filedlg.value)
  end

end

local function open_json()
  file_dlg("OPEN",
    "Open People",
    "people.json",
    "JSON Files|*.json|"..
    "All Files|*.*|",
    function(filename)
      parse_json(filename)
      populate()
    end)
end

local function save_json()
  file_dlg("Save",
    "Save People",
    "people.json",
    "JSON Files|*.json|"..
    "All Files|*.*|",
    function(filename)
      save_people(filename)
    end)
end

-- Window ---------------------------------------------------------
local menu = iup.menu{
  {"File",iup.menu{
    iup.item{title="Open People...",
      action=open_json},
    {},
    iup.item{title="Save People...",
      action=save_json},
    {},
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
    return (node_diam * (nc-.5)
      + node_gap * (nc-1)) * zoom
  end

  function nodexy_to_screenxy(x,y)
    return viewport.left + sc_from_nc(x),
      viewport.top + sc_from_nc(y)
  end

  function screenxy_to_nodexy(sx,sy)
    local cell_size = (node_diam + node_gap) * zoom
    local function cell_of_sc(sc)
      return ceil(sc/cell_size)
    end

    local nx, ny = cell_of_sc(sx-viewport.left), cell_of_sc(sy-viewport.top)
    --Center of node on screen
    local cx, cy = sc_from_nc(nx)+viewport.left, sc_from_nc(ny)+viewport.top

  dlg.title = string.format("%i %i %i %i %i %i %f %f",
        nx, ny, cx,cy,sx,sy, (cx-sx)^2 + (cy-sy)^2,
       (zoom * node_diam/2)^2)

    -- If the cell is within range
    if nx > 0 and ny > 0 and nx <= #nodes and ny <= #nodes
    --And the screen coordinate is within the node for its cell
      and (cx-sx)^2 + (cy-sy)^2 < (zoom * node_diam/2)^2
    then return nx, ny
    --return nil for non-node screen coordinates
    else return nil
    end
  end
end

-- Nodes ----------------------------------------------------------

local bb, can
function canvas:map_cb()
  bb=cd.CreateCanvas(cd.IUP,self)
  can=cd.CreateCanvas(cd.DBUFFER,bb)
end

function canvas:action()
  can:Activate()
  local w, h = can:GetSize()
  can:Clear()
  can:TextAlignment(cd.CENTER)
  if nodes then
    for ny=1, #nodes do
      for nx=1, #nodes do
      local node = nodes[ny][nx]
        if node then
          local sx, sy = nodexy_to_screenxy(nx,ny)
          sy = can:InvertYAxis(sy)
          if node.name ~= active_person then
            can:Foreground(cd.GRAY)
            can:Sector(sx,sy,node_diam * zoom,node_diam * zoom,0,360)
          end
        end
      end
    end
    can:TextOrientation(20)
    for ny=1, #nodes do
      for nx=1, #nodes do
      local node = nodes[ny][nx]
        if node then
          local sx, sy = nodexy_to_screenxy(nx,ny)
          sy = can:InvertYAxis(sy)
          if node.name ~= active_person then
            can:Foreground(cd.EncodeColor(min(#node.body/80,1)*255,0,0))
            can:Text(sx,sy,node.name)
          end
        end
      end
    end
    if active_person then
      local position = positions[active_person]
      local node = people[position.d]
      local sx, sy = nodexy_to_screenxy(position.x,position.y)
      sy = can:InvertYAxis(sy)
      can:Foreground(cd.YELLOW)
      can:Sector(sx,sy,node_diam * zoom,node_diam * zoom,0,360)
      can:Foreground(cd.EncodeColor(min(#node.body/80,1)*255,0,0))
      can:Text(sx,sy,node.name)
    end
  else
    can:TextAlignment(cd.CENTER)
    can:TextOrientation(0)
    can:Foreground(cd.BLACK)
    can:Text(w/2,h/2,"load some people")
  end
  can:Flush()
end

local function recalculate_extents()
  viewport.left = center.x + viewport.width/2
  viewport.right = center.x - viewport.width/2
  viewport.top = center.y + viewport.height/2
  viewport.bottom = center.y - viewport.height/2
  dlg.title = string.format("%i %i %i %i %i %i",
        viewport.left,viewport.right,viewport.top,viewport.bottom,
        center.x,center.y)
end

do
  local downx, downy

  local function pan(x,y,status)
    if downx then
      center.x = center.x + (x - downx)
      center.y = center.y + (y - downy)
      recalculate_extents()
      iup.Update(canvas)
    end
    if iup.isbutton2(status) then
      downx = x
      downy = y
    else
      downx = nil
      downy = nil
    end
  end

  local function select_node(x, y)
    local node = nodes[y][x]
    active_person = node.name
    desc.value = node.body
    iup.Update(canvas)
  end
  local function deselect_node()
    active_person = nil
    desc.value = ""
    iup.Update(canvas)
  end

  function canvas:button_cb(but,pressed,x,y,status)
    pan(x,y,status)
    if pressed == 0 and but == iup.BUTTON1 then
      local nx, ny = screenxy_to_nodexy(x,y)
      if nx then
        select_node(nx, ny)
      else
        deselect_node()
      end
    end
  end

  function canvas:motion_cb(x, y, status)
    pan(x,y,status)
  end

  function canvas:wheel_cb(delta)
    zoom = max(zoom + delta * .1, .1)
    recalculate_extents()
    iup.Update(canvas)
  end
end

function canvas:resize_cb(w, h)
  viewport.width = w
  viewport.height = h
  recalculate_extents()

end

-- Hooks ----------------------------------------------------------
function post_load()
  iup.Update(canvas)
end

-- Action ---------------------------------------------------------

dlg:show()
iup.MainLoop()
