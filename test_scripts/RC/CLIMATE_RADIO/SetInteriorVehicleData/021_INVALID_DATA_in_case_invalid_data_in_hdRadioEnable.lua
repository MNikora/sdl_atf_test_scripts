---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0160-rc-radio-parameter-update.md
-- User story: TBD
--
-- Requirement summary:
-- TBD
--
-- Description:
-- In case:
-- 1) Application is registered with REMOTE_CONTROL appHMIType
-- 2) and sends valid SetInteriorVehicleData RPC with invalid value in hdRadioEnable
-- SDL must:
-- 1) Respond with INVALID_DATA result code, success = false
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local Module = "RADIO"

--[[ Local Functions ]]
local function rpcInvalidData()
  local requestParams = commonRC.getSettableModuleControlData(Module)
  requestParams.radioControlData.hdRadioEnable = "ENABLE"

  local cid = commonRC.getMobileSession():SendRPC("SetInteriorVehicleData", {
	moduleData = requestParams
  })

  EXPECT_HMICALL("RC.SetInteriorVehicleData")
  :Times(0)

  commonRC.getMobileSession():ExpectResponse(cid, { success = false, resultCode = "INVALID_DATA" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test")

runner.Step("SetInteriorVehicleData INVALID_DATA", rpcInvalidData)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
