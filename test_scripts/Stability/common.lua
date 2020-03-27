local utils = require('user_modules/utils')

local common = {}

function common.Wait(actions, msec, count, title)
  if count == nil then
  	count = 1
  end
  if title == nil then
    title = 'Will Wait for '
  end
  print(title .. msec * count )
  local wait_step = function()
    title = 'Wait step ' .. msec .. " ms"
    return actions.run.wait(msec)
  end
  local i = 0
  local step_waiting = function(post_func)
    if i < count then
      print("Wait iteration ".. i.. "for" .. msec )
      wait_step():Do(function ()
        post_func(post_func)
      end)
      i = i + 1
    end
  end
  local bigexpect = actions.run.wait(msec * count)
  step_waiting(step_waiting)
end

function common.IDLE(actions, msec, count)
  common.Wait(actions, msec, count, "IDLE for ")
end

function common.collect_metrics(filename)
  local cmd = "pwd && bash ./measure_sdl.sh " .. filename.."_stat" .. " &" 
  os.execute(cmd)
end

function common.unregisterApp(actions, pAppId)
  if not pAppId then pAppId = 1 end
  local mobSession = actions.getMobileSession(pAppId)
  local hmiAppId = actions.getHMIAppId(pAppId)
  actions.deleteHMIAppId(pAppId)
  local cid = mobSession:SendRPC("UnregisterAppInterface",{})
  actions.hmi.getConnection():ExpectNotification("BasicCommunication.OnAppUnregistered",
    { appID = hmiAppId, unexpectedDisconnect = false })
  mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS"}):Do(function (_,_)
    mobSession:Stop()
  end)
end


return common