local actions = require("user_modules/sequences/actions")
local runner = require('user_modules/script_runner')
local common_stability = require('Stability/common')
--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

runner.Title("Preconditions")
runner.Step("Clean environment", actions.preconditions)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"one_app_multiple_reg"})
runner.Step("Start SDL, HMI, connect Mobile, start Session", actions.start)

for i = 1, 1000 do
  local app = 1
  runner.Step("RAI " .. i, actions.registerAppWOPTU, {app})
  runner.Step("Activate App " .. i, actions.activateApp, {app})
  runner.Step("Unregister App " .. i, common_stability.unregisterApp, {actions, app})
  -- runner.Step("Wait" .. i, Wait)
end
runner.Step("IDLE ",common_stability.IDLE, {actions, 1000, 600}) -- 15 minutes
runner.Title("Postconditions")
runner.Step("Stop SDL", actions.postconditions)