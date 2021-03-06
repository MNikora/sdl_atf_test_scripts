---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0160-rc-radio-parameter-update.md
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/3
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/SetInteriorVehicleData.md
-- Item: Use Case 1: Main Flow
--
-- Requirement summary:
-- [SDL_RC] Set available control module settings SetInteriorVehicleData
--
-- Description:
-- In case:
-- 1) Application is registered with REMOTE_CONTROL appHMIType
-- 2) and sends valid SetInteriorVehicleData RPC with valid parameters
-- SDL must:
-- 1) Transfer this request to HMI
-- 2) Respond with <result_code> received from HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local Module = "RADIO"

--[[ Local Functions ]]
local function setVehicleData()
  local requestParams = commonRC.getSettableModuleControlData(Module)
  requestParams.radioControlData.band = "XM"

  local cid = commonRC.getMobileSession():SendRPC("SetInteriorVehicleData", {
  moduleData = requestParams
  })

  EXPECT_HMICALL("RC.SetInteriorVehicleData", {
    appID = commonRC.getHMIAppId(),
    moduleData = requestParams
  })
  :Do(function(_, data)
  commonRC.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {
    moduleData = requestParams
  })
  end)

  commonRC.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test")

runner.Step("SetInteriorVehicleData with band XM", setVehicleData)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
