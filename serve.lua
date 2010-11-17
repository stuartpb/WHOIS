local xavante = require "xavante"
local augh = require "wsapi.xavante"

local lolol_func

local function load_stable()
  lolol_func=dofile "lolol_stable.lua"
  print "lolol_stable.lua loaded."
end

local function load()
  local suc,result=pcall(dofile,"lolol.lua")
  if suc then
    lolol_func=result
    print "lolol.lua loaded successfully"
  else
    print "Error loading lolol.lua:"
    print(result)
    --If there isn't already a working function loaded
    if not lolol_func then
      load_stable()
    end
  end
end

load()

local function dololol(env)
  return lolol_func(env)
end

xavante.HTTP{
  server = {host = "*", port = 80},
  defaultHost={
    rules={
      {
        match = "sms(.*)",
        with = wsapi.xavante.makeHandler(dololol,"sms")
      }
    }
  }
}

local running=true

local function stop_running()
  return not running
end

xavante.start(stop_running)

local commands={}

commands.reload=load

function commands.stop()
  running=false
end

commands["reload stable"]=load_stable

commands["save stable"]=function()
  local current=io.open"lolol.lua"
  local stable=io.open("lolol_stable.lua","w")
  for line in current:lines() do
    stable:write(line,'\n')
  end
  stable:close()
  current:close()
  print "Current lolol.lua saved as stable."
end

while running do
  local query=io.read'*l'
  if commands[query] then
    commands[query]()
  else
    print(string.format("Command %q not recognized",query))
  end
end
