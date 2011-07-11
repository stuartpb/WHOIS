local hmac; do
  local rep = string.rep
  local blocksize = 64
  local opad = rep('\92',blocksize)
  local ipad = rep('\54',blocksize)
  local h = md5.sum
  local hexh = md5.sumhexa
  local xor = md5.exor

  function hmac(message, key)
    if #key > blocksize then key = h(key) end
    if #key < blocksize then
      key = key .. string.rep('\0',blocksize-#key)
    end
    return hexh(xor(key,opad) .. h(xor(key,ipad)..message))
  end
end

local format = string.format
local gsub = string.gsub

function main(web, req)
  local textmarks_token = mongodb:query('keys',
    {textmarks_token = {["$exists"] = true}}):next().textmarks_token

  local params=web:params()

  local msg = params.msg or ""
  local tel = params.tel or "+16107610054"
  local uid = params.uid or "1277842"
  local act = params.act or "REQ"
  local rqt = params.rqt
  local kwd = params.kwd
  local sig = params.sig

  local digest=kwd and tel and rqt
    and hmac(kwd..tel..rqt,textmarks_token)
  local signed = sig and sig == digest

  do --logging
    local lmc={}

    lmc.date = os.date("Message recieved %c",rqt and tonumber(rqt))

    if act=="REQ" then
      lmc.what = "body: "..msg
    else
      lmc.what = "action: "..act
    end

    lmc.from = tel

    if signed then
      lmc.sigstat = "Signature OK"
    else
      if sig then
        lmc.sigstat = format([[
Bad signature:
  Recieved: %q
  %s]], sig, digest and format("Expected: %q",digest) or
          format("kwd: %s tel: %s rqt: %s",
            tostring(kwd),tostring(tel),tostring(rqt)))
      else
        lmc.sigstat = "No signature"
      end
    end

    moai.log(gsub([[
$date
$what
from: $from
$sigstat
]],"%$(%w*)",lmc),signed and "INFO" or "WARN")
  end

  local function get(key)
    local cursor = mongodb:query('users', {uid = uid})
    local usertable = cursor:next()
    if not usertable then
      --this technically shouldn't happen, but just be chill
      return nil
    else
      return usertable[key]
    end
  end

  local function set(key, val)
    mongodb:update('users', {uid = uid}, {['$set']={[key]=val}}, true)
  end

  local function unset(key)
    mongodb:update('users', {uid = uid}, {['$unset']={[key]=1}}, true)
  end

  local function respond(body)
    web:page(body,200,'OK')
  end

  local function atk(fmat,kword)
    return gsub(fmat,'@',kword)
  end

  set("tel",tel)

  if act=="SUB" then
    set("subscribed",true)
    respond""
  elseif act=="UNSUB" then
    unset("subscribed")
    respond""
  else
    local username=get("name")

    --empty messages
    if msg=="" then
      if not username then
        respond('Text "LOLOL name" followed by your name!')
      else
        respond(atk('Y helo thar, @!',username))
      end

    --begin inserting your elseifs here...
    elseif msg:find"^name" then
      local uname=msg:match"^name%s*(.-)$"
      if uname then
        if uname:find"\n" then
          uname=uname:match"^(.-)\n"
        end
        if uname:len() > 50 then
          respond"Holy cow! Let's keep it under 50 characters, OK?"
        else
          set("name",uname)
          local response = atk("Hello, @!",uname)
          if username then
            response = response .. atk(" You are cooler than @.",username)
          end
          respond(response)
        end
      else
        respond("Didn't get a name. "..
        'Try just a space between "lolol name" and your name.')
      end
    elseif msg=="matt stupid" then
      respond"So I've heard."

    --end of elseifs - default case
    else
      local response = atk("And @ to you, too",gsub(msg,'^%p*(.-)%p*$',"%1"))
      if username then response = response..atk(", @",username) end
      response = response .. '!'
      respond(response)
    end
  end
end
