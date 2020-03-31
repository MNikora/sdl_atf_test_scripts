---------------------------------------------------------------------------------------------------
-- PTU through Mobile - 500 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfTries = 500

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "006_ptu_through_mobile" })
common.Step("Connect Mobile", common.connectMobile)

common.Title("Test")
for i = 1, numOfTries do
  common.Step("Register App " .. i, common.registerApp, { i })
  common.Step("PTU", common.policyTableUpdate)
  common.Step("Unregister App " .. i, common.unregisterApp, { i })
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
