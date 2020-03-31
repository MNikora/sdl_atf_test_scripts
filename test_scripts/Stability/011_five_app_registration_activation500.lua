---------------------------------------------------------------------------------------------------
-- 5 applications - 500 registrations and activations
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfTries = 500

--[[ Local Functions ]]
local function activateApp(pAppId)
  common.activateApp(pAppId)
  common.delay(2000)
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "011_five_apps_multiple_reg_act" })

common.Title("Test")
common.Step("Connect Mobile", common.connectMobile)
for try = 1, numOfTries do
  common.Title("Try " .. try)
  for app = 1, 5 do
    common.Step("Register App " .. app, common.registerNoPTU, { app })
  end
  for app = 1, 5 do
    common.Step("Activate " .. app, activateApp, { app })
  end
  for app = 1, 5 do
    common.Step("Unregister " .. app, common.unregisterApp, { app })
  end
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
