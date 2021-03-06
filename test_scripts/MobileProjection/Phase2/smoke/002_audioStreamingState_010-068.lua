---------------------------------------------------------------------------------------------------
-- Issue: https://github.com/smartdevicelink/sdl_core/issues/2129
---------------------------------------------------------------------------------------------------
-- Description:
-- In case:
-- 1) There are 2 mobile apps:
--   app1: is audio source ('audioStreamingState' = AUDIBLE)
--   app2: is not audio source ('audioStreamingState' = NOT_AUDIBLE)
-- 2) Mobile app2 is activated
-- SDL must:
-- 1) Send OnHMIStatus notification for both apps with appropriate value of 'audioStreamingState' parameter
-- Particular value depends on app's 'appHMIType' and 'isMediaApplication' flag, and described in 'testCases' table below
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/MobileProjection/Phase2/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local testCases = {
  [010] = { [1] = { t = "NAVIGATION",    m = false, s = "AUDIBLE" },     [2] = { t = "PROJECTION",    m = false, s = "NOT_AUDIBLE" }},
  [024] = { [1] = { t = "NAVIGATION",    m = false, s = "NOT_AUDIBLE" }, [2] = { t = "NAVIGATION",    m = false, s = "AUDIBLE" }    },
  [032] = { [1] = { t = "NAVIGATION",    m = false, s = "AUDIBLE" },     [2] = { t = "PROJECTION",    m = true,  s = "AUDIBLE" }    },
  [048] = { [1] = { t = "PROJECTION",    m = true,  s = "AUDIBLE" },     [2] = { t = "NAVIGATION",    m = false, s = "AUDIBLE" }    },
  [060] = { [1] = { t = "PROJECTION",    m = true,  s = "NOT_AUDIBLE" }, [2] = { t = "PROJECTION",    m = true,  s = "AUDIBLE" }    }
}

--[[ Local Functions ]]
local function activateApp2(pTC, pAudioSSApp1, pAudioSSApp2)
  local requestId = common.getHMIConnection():SendRequest("SDL.ActivateApp", { appID = common.getHMIAppId(2) })
  common.getHMIConnection():ExpectResponse(requestId)
  common.getMobileSession(1):ExpectNotification("OnHMIStatus")
  :ValidIf(function(_, data)
      return common.checkAudioSS(pTC, "App1", pAudioSSApp1, data.payload.audioStreamingState)
    end)
  common.getMobileSession(2):ExpectNotification("OnHMIStatus")
  :ValidIf(function(_, data)
      return common.checkAudioSS(pTC, "App2", pAudioSSApp2, data.payload.audioStreamingState)
    end)
end

--[[ Scenario ]]
for n, tc in common.spairs(testCases) do
  runner.Title("TC[" .. string.format("%03d", n) .. "]: "
    .. "App1[hmiType:" .. tc[1].t .. ", isMedia:" .. tostring(tc[1].m) .. "], "
    .. "App2[hmiType:" .. tc[2].t .. ", isMedia:" .. tostring(tc[2].m) .. "]")
  runner.Step("Clean environment", common.preconditions)
  runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
  runner.Step("Set App 1 Config", common.setAppConfig, { 1, tc[1].t, tc[1].m })
  runner.Step("Set App 2 Config", common.setAppConfig, { 2, tc[2].t, tc[2].m })
  runner.Step("Register App 1", common.registerApp, { 1 })
  runner.Step("Register App 2", common.registerApp, { 2 })
  runner.Step("Activate App 1", common.activateApp, { 1 })
  runner.Step("Activate App 2, audioStates: app1 " ..  tc[1].s .. ", app2 " .. tc[2].s, activateApp2,
    { n, tc[1].s, tc[2].s })
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL", common.postconditions)
end
runner.Step("Print failed TCs", common.printFailedTCs)
