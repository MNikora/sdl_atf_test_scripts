---------------------------------------------------------------------------------------------------
-- 5 devices - 5 applications each
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfApps = 5
local numOfDevices = 5

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "003_five_devices_fice_apps_on_each_idle" })

common.Title("Test")
local appId = 0
for deviceId = 1, numOfDevices do
  common.Step("Connect Mobile", common.connectMobileEx, { deviceId })
  for appNum = 1, numOfApps do
    appId = appId + 1
    common.Step("RAI " .. deviceId .. " " .. appNum .. " " .. appId, common.registerNoPTU, { appId, deviceId })
  end
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
