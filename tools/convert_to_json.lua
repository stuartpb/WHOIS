local people = {}
local file = io.open(in_filename)
for line in file:lines() do
  local name, desc = line:match"^(.-)%:%s*(.-)$"
  people[#people+1] = {name = name, body = desc, links = {}}
end
file:close()

local file = io.open(out_filename, 'w')
file:write(json.encode(people,{
  indent = true,
  keyorder = {"name","body","links"},
  }))
file:close()
