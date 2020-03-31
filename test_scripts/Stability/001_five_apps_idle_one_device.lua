---------------------------------------------------------------------------------------------------
-- 1 device - 5 applications
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfApps = 5

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "001_five_apps_idle" })

common.Title("Test")
common.Step("Connect Mobile", common.connectMobile)
for app = 1, numOfApps do
  common.Step("RAI " .. app, common.registerNoPTU, { app })
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
