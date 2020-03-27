local actions = require("user_modules/sequences/actions")
local runner = require('user_modules/script_runner')
local common_stability = require('Stability/common')
--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false


runner.Title("Preconditions")
runner.Step("Clean environment", actions.preconditions)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"five_apps_idle"})
runner.Step("Start metrics_collecting", collect_metrics)
runner.Step("Start SDL, HMI, connect Mobile, start Session", actions.start)

  for app = 1, 5 do
    runner.Step("RAI " .. i, actions.registerAppWOPTU, {app})
  end

  runner.Step("IDLE ",common_stability.IDLE, {actions, 1000, 600}) -- 20 minutes
-- runner.Title("Postconditions")
runner.Step("Stop SDL", actions.postconditions)