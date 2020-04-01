---------------------------------------------------------------------------------------------------
-- 5 devices - 1 application each
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfAppAndDevices = 5

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "002_five_devices_one_app_idle" })

common.Title("Test")
for app = 1, numOfAppAndDevices do
  common.Step("Connect Mobile", common.connectMobileEx, { app })
  common.Step("RAI " .. app, common.registerNoPTU, { app, app })
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
