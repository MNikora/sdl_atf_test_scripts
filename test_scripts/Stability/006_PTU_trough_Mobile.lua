---------------------------------------------------------------------------------------------------
-- PTU through Mobile - 500 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("user_modules/sequences/actions")
local utils = require("user_modules/utils")
local common_stability = require('test_scripts/Stability/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local numOfApps = 500
local appParams = utils.cloneTable(common.app.getParams(1))

--[[ Local Functions ]]
local function registerApp(pAppId)
  appParams.appName = "App_" .. pAppId
  appParams.appID = "000" .. pAppId
  appParams.fullAppID = "000000" .. pAppId
  config["application" .. pAppId] = { registerAppInterfaceParams = appParams }
  common.app.register(pAppId)
end

local function unregisterApp(pAppId)
  if pAppId == nil then pAppId = 1 end
  local session = common.mobile.getSession(pAppId)
  local cid = session:SendRPC("UnregisterAppInterface", {})
  session:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.hmi.getConnection():ExpectNotification("BasicCommunication.OnAppUnregistered",
    { unexpectedDisconnect = false, appID = common.app.getHMIId(pAppId) })
  :Do(function()
      common.app.deleteHMIId(pAppId)
      common.mobile.closeSession(pAppId)
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"ptu_throgh_mobile"})
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
for i = 1, numOfApps do
  runner.Step("Register App " .. i, registerApp, { i })
  runner.Step("PTU", common.policyTableUpdate)
  runner.Step("Unregister App " .. i, unregisterApp, { i })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
