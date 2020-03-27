local actions = require("user_modules/sequences/actions")
local runner = require('user_modules/script_runner')
local common_stability = require('Stability/common')
--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false


runner.Title("Preconditions")
runner.Step("Clean environment", actions.preconditions)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"five_apps_multireg"})
runner.Step("Start SDL, HMI, connect Mobile, start Session", actions.start)

for i = 1, 5 do
  -- local app = 1
  for app = 1, 5 do
    runner.Step("RAI " .. i, actions.registerAppWOPTU, {app})
  end
  for app = 1, 5 do
    runner.Step("Activate App " .. i, actions.activateApp, {app})
  end
  runner.Step("1 second waiting ",common_stability.Wait, {actions, 1000, 1}) 
  for app = 1, 5 do
    runner.Step("Unregister App " .. i, common_stability.unregisterApp, {actions,app})
  end
  runner.Step("Wait before next RAI: 3 seconds ",common_stability.Wait, {actions, 1000, 3}) 
end
runner.Step("IDLE ",common_stability.IDLE, {actions, 1000, 600}) -- 15 minutes
-- runner.Title("Postconditions")
runner.Step("Stop SDL", actions.postconditions)