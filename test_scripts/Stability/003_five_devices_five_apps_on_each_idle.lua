local actions = require("user_modules/sequences/actions")
local common = require('test_scripts/TheSameApp/commonTheSameApp')
local common_stability = require('test_scripts/Stability/common')
local runner = require('user_modules/script_runner')
local utils = require('user_modules/utils')

-- [[ Test Configuration ]]
-- runner.testSettings.isSelfIncluded = false


--[[ Local Data ]]
local devices = {
  [1] = { host = "1.0.0.1",         port = config.mobilePort },
  [2] = { host = "192.168.100.199", port = config.mobilePort },
  [3] = { host = "10.42.0.1",       port = config.mobilePort },
  [4] = { host = "8.8.8.8",         port = config.mobilePort }
}


local app_id_gen = 1
local app_name_gen = 1

local function gen_app()
   local res = { appName = "Test Application_"..app_name_gen,   appID = "000"..app_id_gen,  fullAppID = "000000"..app_id_gen }
   app_id_gen = app_id_gen + 1
   app_name_gen = app_name_gen + 1
   return res
end

-- utils.printTable(common_stability)
-- print(common_stability.collect_metrics)

runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"five_devices_fice_apps_on_each_idle"})
runner.Step("Start SDL and HMI", common.start)

runner.Title("Test")
runner.Step("Connect " .. #devices .." mobiles devices to SDL", common.connectMobDevices, {devices})

for i = 1,4 do
  runner.Step("Register App" .. app_id_gen .." from device 1", common.registerAppEx, {i, gen_app(), 1})
end
for i = 1,4 do
  runner.Step("Register App" .. app_id_gen .." from device 2", common.registerAppEx, {i, gen_app(), 2})
end
for i = 1,4 do
  runner.Step("Register App" .. app_id_gen .." from device 3", common.registerAppEx, {i, gen_app(), 3})
end
for i = 1,4 do
  runner.Step("Register App" .. app_id_gen .." from device 4", common.registerAppEx, {i, gen_app(), 4})
end
runner.Step("IDLE ",common_stability.IDLE, {actions, 1000, 600}) -- 20 minutes
runner.Title("Postconditions")
runner.Step("Remove mobile devices", common.clearMobDevices, {devices})
runner.Step("Stop SDL", common.postconditions)
