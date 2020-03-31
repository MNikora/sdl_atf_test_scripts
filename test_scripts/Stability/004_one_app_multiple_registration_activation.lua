---------------------------------------------------------------------------------------------------
-- 1 application - 1000 registrations and activations
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfTries = 1000

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "004_one_app_multiple_reg_act" })

common.Title("Test")
common.Step("Connect Mobile", common.connectMobile)
for i = 1, numOfTries do
  local app = 1
  common.Step("Register App " .. i, common.registerNoPTU, { app })
  common.Step("Activate App " .. i, common.activateApp, { app })
  common.Step("Unregister App " .. i, common.unregisterApp, { app })
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
