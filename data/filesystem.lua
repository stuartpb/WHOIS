local datamodule={}
local function filename(key,uid)
  return "/home/lolol/"..key..'/'..uid
end

function datamodule.get(key,uid)
  local result
  local file=io.open(filename(key,uid))
  if file then result=file:read'*a'; file:close() end
  return result
end

function datamodule.set(key,uid,content)
  local file=io.open(filename(key,uid),'w')
  if file then file:write(content); file:close() end
end

function datamodule.unset(datum,uid)
  local fname=filename(key,uid)
  local file=io.open(fname)
  if file then file:close(); os.remove(fname) end
end

return datamodule
