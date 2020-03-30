---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- 1) Application is registered with PROJECTION appHMIType
-- 2) and starts video streaming
-- SDL must:
-- 1) Start service successful
-- 2) Process streaming from mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/MobileProjection/Phase1/common')
local common_stability = require('test_scripts/Stability/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local appHMIType = "PROJECTION"

--[[ General configuration parameters ]]
config.application1.registerAppInterfaceParams.appHMIType = { appHMIType }

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  pTbl.policy_table.app_policies[common.getConfigAppParams().fullAppID].AppHMIType = { appHMIType }
end


local function create_file() 
  local cmd = "fallocate -l 5G files/big_file" 
  os.execute(cmd)
end

local function onstream_finished() 
  print("File streaming done callback")
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Create big file for streaming", create_file)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"one_app_streaming"})
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("PolicyTableUpdate with HMI types", common.policyTableUpdate, { ptUpdate })
runner.Step("Activate App", common.activateApp)
runner.Step("Start video service", common.startService, { 11 })

runner.Title("Test"
)runner.Step("Start video streaming", common_stability.StartVideoStreaming,
									 {common,"files/big_file", 1, 5000000, onstream_finished})
runner.Title("Postconditions")
runner.Step("Stop video streaming", common.StopStreaming, { 11, "files/big_file" })
runner.Step("IDLE ",common_stability.IDLE, {common, 1000, 300}) -- 10 minutes
runner.Step("Stop SDL", common.postconditions)
