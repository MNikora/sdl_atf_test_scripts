local actions = require("user_modules/sequences/actions")
local common = require('test_scripts/TheSameApp/commonTheSameApp')
local common_stability = require('test_scripts/Stability/common')
local runner = require('user_modules/script_runner')
local utils = require('user_modules/utils')
--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1",         port = config.mobilePort },
  [2] = { host = "192.168.100.199", port = config.mobilePort },
  [3] = { host = "10.42.0.1",       port = config.mobilePort },
  [4] = { host = "8.8.8.8",         port = config.mobilePort }
}

local appParams = {
  [1] = { appName = "Test Application",   appID = "0001",  fullAppID = "0000001" },
  [2] = { appName = "Test Application",   appID = "00022", fullAppID = "00000022" },
  [3] = { appName = "Test Application 2", appID = "00022", fullAppID = "00000022" },
  [4] = { appName = "Test Application",   appID = "0001",  fullAppID = "0000001" }
}

runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"five_devices_one_app_idle"})
runner.Step("Start SDL and HMI", common.start)

runner.Title("Test")
runner.Step("Connect " .. #devices .." mobiles devices to SDL", common.connectMobDevices, {devices})


runner.Step("Register App1 from device 1", common.registerAppEx, {1, appParams[1], 1})
runner.Step("Register App2 from device 2", common.registerAppEx, {2, appParams[2], 2})
runner.Step("Register App3 from device 3", common.registerAppEx, {3, appParams[3], 3})
runner.Step("Register App4 from device 4", common.registerAppEx, {4, appParams[4], 4})


runner.Step("IDLE ",common_stability.IDLE, {actions, 1000, 600}) -- 20 minutes
runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
