---------------------------------------------------------------------------------------------------
-- PutFile - 500 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfFiles = 500

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "008_put_file" })
common.Step("Connect Mobile", common.connectMobile)
common.Step("Register App", common.registerApp)
common.Step("Activate App", common.activateApp)

common.Title("Test")
for i = 1, numOfFiles do
  local filePath = "files/icon_bmp.bmp"
  local params = {
    syncFileName = "icon_" .. i .. ".bmp",
    fileType = "GRAPHIC_PNG",
    persistentFile = false,
    systemFile = false
  }
  common.Step("PutFile " .. i, common.putFile, { params, filePath })
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
