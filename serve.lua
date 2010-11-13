local xavante = require "xavante"
local augh = require "wsapi.xavante"

local func
local function loader(env)
  local suc,result=pcall(dofile,"lolol.lua")
  if suc then
    func=result
  else
    print(result)
  end
  if func then return func(env)
  else return 500, { ["Content-Type"] = "text/plain" },
    coroutine.wrap(function()
      coroutine.yield"The server wasn't started with a working file. Whoops."
    end)
end

xavante.HTTP{
  server = {host = "*", port = 80},
  defaultHost={
    rules={
      {
        match = "sms(.*)",
        with = wsapi.xavante.makeHandler(loader,"sms")
      }
    }
  }
}

xavante.start()
