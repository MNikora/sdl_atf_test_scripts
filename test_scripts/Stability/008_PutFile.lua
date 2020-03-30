---------------------------------------------------------------------------------------------------
-- PutFile - 500 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("user_modules/sequences/actions")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local numOfFiles = 500

--[[ Local Functions ]]
local function putFile(pFileId)
  local filePath = "files/icon_bmp.bmp"
  local params = {
    syncFileName = "icon_" .. pFileId .. ".bmp",
    fileType = "GRAPHIC_PNG",
    persistentFile = false,
    systemFile = false
  }
  local cid = common.getMobileSession():SendRPC("PutFile", params, filePath)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.run.wait(500)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
for i = 1, numOfFiles do
  runner.Step("PutFile " .. i, putFile, { i })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
