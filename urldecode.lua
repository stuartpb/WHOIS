local string = require "string"

--module table
local urldecode={}

--URL decode a string.
local function decode(str)

  --Convert plus signs to spaces
  str= string.gsub (str, "+", " ")

  --Percent-decode all percent-encoded characters
  str = string.gsub (str, "%%(%x%x)",
    function (c) return string.char(tonumber(c,16)) end)

  return str
end

--Make this function available as part of the module
urldecode.text = decode

--URL decode a series of parameters into a table.
function urldecode.form(formstr)

  --table of parameters
  local argts = {}

  --for every section of text that's not an ampersand or semicolon
  for pair in string.gmatch(formstr, "[^&;]+" ) do
  
    --get the key and value in the pair
    local k,v=string.match(pair,"^(.*)=(.*)$")

    --if that was a valid pair
    if k and v then
      --put the decoded strings into the table
      argts[decode(k)]=decode(v)
    end
    --if it wasn't, then, you know, robustness principle, don't do anything.

  end

  --if formstr was a valid form and it has produced at least one
  --key-value pair, return the resulting table.
  if next(argts) then return argts end

end

return urldecode
