---------------------------------------------------------------------------------------------------
-- PTU through HMI - 500 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("user_modules/sequences/actions")
local utils = require("user_modules/utils")

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

local function getPTUFromPTS()
  local pTbl = common.sdl.getPTS()
  if type(pTbl.policy_table) == "table" then
    pTbl.policy_table.consumer_friendly_messages = nil
    pTbl.policy_table.device_data = nil
    pTbl.policy_table.module_meta = nil
    pTbl.policy_table.usage_and_error_counts = nil
    pTbl.policy_table.functional_groupings["DataConsent-2"].rpcs = utils.json.null
    pTbl.policy_table.module_config.preloaded_pt = nil
    pTbl.policy_table.module_config.preloaded_date = nil
    pTbl.policy_table.vehicle_data = nil
  else
    utils.cprint(35, "PTU file has incorrect structure")
  end
  return pTbl
end

local function ptuViaHMI()
  local ptuFileName = os.tmpname()
  local requestId = common.hmi.getConnection():SendRequest("SDL.GetPolicyConfigurationData",
      { policyType = "module_config", property = "endpoints" })
  common.hmi.getConnection():ExpectResponse(requestId)
  :Do(function()
      local ptuTable = getPTUFromPTS()
      for i, _ in pairs(common.mobile.getApps()) do
        ptuTable.policy_table.app_policies[common.app.getParams(i).fullAppID] = common.ptu.getAppData(i)
      end
      utils.tableToJsonFile(ptuTable, ptuFileName)
      common.hmi.getConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
      common.hmi.getConnection():ExpectNotification("SDL.OnStatusUpdate", { status = "UP_TO_DATE" })
      common.hmi.getConnection():SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = ptuFileName })
      common.run.runAfter(function() os.remove(ptuFileName) end, 250)
      for _, session in pairs(common.mobile.getApps()) do
        session:ExpectNotification("OnPermissionsChange")
      end
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
for i = 1, numOfApps do
  runner.Step("Register App " .. i, registerApp, { i })
  runner.Step("PTU", ptuViaHMI)
  runner.Step("Unregister App " .. i, unregisterApp, { i })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
