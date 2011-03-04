local xavante = require "xavante"
local augh = require "wsapi.xavante"

local suc,result=pcall(dofile,"lolol.lua")

local lolol_func

if suc then
  lolol_func=result
  print "lolol.lua loaded successfully"

  local function dololol(env)
    return lolol_func(env)
  end

  xavante.HTTP{
    server = {host = "*", port = 8080},
    defaultHost={
      rules={
        {
          match = "sms(.*)",
          with = wsapi.xavante.makeHandler(dololol,"sms")
        }
      }
    }
  }

  local should_stop=false

  local function stop_running()
    return should_stop
  end

  xavante.start(stop_running)

else
  print "Error loading lolol.lua:"
  print(result)
end
