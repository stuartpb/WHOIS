local people = {}
local set = {}
local in_filename = "list.txt"
local out_filename = "people.json"
local json = require "dkjson"

local file = io.open(in_filename)
for line in file:lines() do
  local name, desc = line:match"^(.-)%:%s*(.-)$"
  if set[name] then
    error(name)
  else
    set[name]=true
  end
  people[#people+1] = {name = name, body = desc, links = {}}
end
file:close()

local file = io.open(out_filename, 'w')
file:write(json.encode(people,{
  indent = true,
  keyorder = {"name","body","links"},
  }))
file:close()
