local udc = require "urldecode"

local function get(datum,uid)
  local result
  local file=io.open("/home/lolol/"..datum..'/'..uid)
  if file then result=file:read'*a'; file:close() end
  return result
end

local function set(datum,uid,content)
  local file=io.open("/home/lolol/"..datum..'/'..uid,'w')
  if file then file:write(content); file:close() end
end

local cy=coroutine.yield

return function(env)
  local params=udc.form(env.QUERY_STRING)

  local msg = params.msg or ""
  local tel = params.tel or "+16107610054"
  local uid = params.uid or "1277842"
  local act = params.act or "REQ"
  local sig = params.sig

  print(os.date("Message recieved %c"))
  print("body:", msg)
  print("from:", tel)
  --print("UID:", uid)

  set("tels",uid,tel)

  local function out()
    local username=get("names",uid)

    if msg=="" then
      if not username then
        cy'Text "LOLOL name" followed by your name!'
      else
        cy'Y helo thar, '
        cy(username)
        cy'!'
      end
    --begin inserting your elseifs here...
    elseif msg:find"^name" then
      local uname=msg:match"^name%s*(.-)$"
      if uname then
        if uname:find"\n" then
          uname=uname:match"^(.-)\n"
        end
        if uname:len() > 50 then
          cy"Holy cow! Let's keep it under 50 characters, OK?"
        else
          set("names",uid,uname)
          cy"Hello, "
          cy(uname)
          cy"!"
          if username then
            cy" You are cooler than "
            cy(username)
            cy"."
          end
        end
      else
        cy"Didn't get a name. "
        cy'Try just a space between "lolol name" and your name.'
      end
    elseif msg=="matt stupid" then
      cy"So I've heard."

    --end of elseifs - default case
    else
      cy"And "
      cy(msg)
      cy" to you, too"
      if username then cy", "; cy(username) end
      cy"!"
    end
  end
  return 200,{ ["Content-Type"] = "text/plain" },coroutine.wrap(out)
end
