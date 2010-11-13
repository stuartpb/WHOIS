local udc = require "urldecode"
return function(env)
  local params=udc.form(env.QUERY_STRING)
  if something then print(something) end
  local msg = params.msg
  local tel = params.tel
  local uid = params.uid

  print(os.date("Message recieved %c"))
  print("body: ",msg,"\nfrom: ",phone,"\nUID:",uid)

  local knownphones={
    ["+18153883400"]="BENNO",
    ["+16079724146"]="CHARLIE",
    ["+16107610054"]="BROHAM",
    ["+16107618560"]="Mom",
    ["+16107618600"]="Dad",
    ["+14255912606"]="SCOTT",
  }

  local function derp()
    local cy=coroutine.yield
    if msg=="" then
      cy"It works even better if you type something after the LOLOL"
    else
      cy"And "
      cy(msg)
      cy" to you, too"
    end
    if knownphones[tel] then
      cy", " cy(knownphones[tel])
    end
    cy"!"
  end
  return 200,{ ["Content-Type"] = "text/plain" },coroutine.wrap(derp)
end
