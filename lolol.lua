local udc = require "urldecode"
local data = require "data.filesystem"
require "crypto" --stupid hmac can't just be included directly
local hmac = require "crypto.hmac"

--function to read in line from a file
local function readfilestr(fname)
  local f=io.open(fname,"r")
  if f then
    local r=f:read"*l"
    f:close()
    return r
  else return nil end
end

local lolol_token = readfilestr"keys/lolol-token"
local git_dir = readfilestr"config/git-dir"

local git_log_cmd=table.concat({"git","--git-dir",git_dir,
  "--no-pager", "log", "-1", "--date=relative"}," ")

local cy=coroutine.yield

local get=data.get
local set=data.set
local unset=data.unset

return function(env)
  local params=udc.form(env.QUERY_STRING)

  local msg = params.msg or ""
  local tel = params.tel or "+16107610054"
  local uid = params.uid or "1277842"
  local act = params.act or "REQ"
  local rqt = params.rqt
  local kwd = params.kwd
  local sig = params.sig

  local digest=kwd and tel and rqt
    and hmac.digest("md5",kwd..tel..rqt,lolol_token)
  local signed = sig and sig == digest

  print(os.date("Message recieved %c",rqt and tonumber(rqt)))
  if act=="REQ" then
    print("body:", msg)
  else
    print("action:",act)
  end
  print("from:", tel)
  --print("UID:", uid)
  if signed then print "Signature OK"
  else
    if sig then
      print("Sig recieved:",sig)
      if digest then
        print("Sig expected:",digest)
      else
        print("Insufficient parameters to validate signature")
        --that or the digest function is broken, but c'mon
      end
    else
      print("Unsigned (if this was not a test we've got trouble)")
    end
  end
  print"---"

  set("tels",uid,tel)

  local function emptyreturns()
    return 200,nil,function() return nil end
  end

  if act=="SUB" then
    set("subs",uid,"true")
    return emptyreturns()
  elseif act=="UNSUB" then
    unset("subs",uid,"true")
    return emptyreturns()
  else
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
end
