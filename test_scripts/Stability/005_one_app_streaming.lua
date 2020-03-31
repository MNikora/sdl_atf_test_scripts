---------------------------------------------------------------------------------------------------
-- 1 application - streaming
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local fileName = os.tmpname()
local fileSize = 1 -- Gb

--[[ Local Functions ]]
local function createFile()
  local cmd = "fallocate -l " .. fileSize .. "G " .. fileName
  os.execute(cmd)
end

local function deleteFile()
  os.remove(fileName)
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Create big file for streaming", createFile)
common.Step("Start SDL and HMI", common.start, { "005_one_app_streaming" })
common.Step("Connect Mobile", common.connectMobile)
common.Step("Register App", common.registerApp)
common.Step("PolicyTableUpdate with HMI types", common.policyTableUpdate)
common.Step("Activate App", common.activateApp)

common.Title("Test")
common.Step("Start video streaming", common.startVideoStreaming, { fileName, 1, 5000000 })

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop video streaming", common.stopVideoStreaming, { fileName })
common.Step("Delete big file for streaming", deleteFile)
common.Step("Stop SDL", common.postconditions)
