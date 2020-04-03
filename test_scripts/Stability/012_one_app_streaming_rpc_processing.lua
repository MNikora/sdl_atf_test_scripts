---------------------------------------------------------------------------------------------------
-- 1 application - streaming and RPC processing - 200 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local fileName = os.tmpname()
local fileSize = 1 -- Gb
local numOfTries = 200

--[[ Local Functions ]]
local function createFile()
  local cmd = "fallocate -l " .. fileSize .. "G " .. fileName
  os.execute(cmd)
end

local function deleteFile()
  os.remove(fileName)
end


local function addCommand(pCmdId)
  local requestParams = {
    cmdID = pCmdId,
    menuParams = {
      position = 0,
      menuName ="Commandpositive_" .. pCmdId
    },
    vrCommands = {
      "VRCommandonepositive_" .. pCmdId,
    },
    grammarID = pCmdId
  }
  local cid = common.getMobileSession():SendRPC("AddCommand", requestParams)
  common.getHMIConnection():ExpectRequest("UI.AddCommand")
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)
  common.getHMIConnection():ExpectRequest("VR.AddCommand")
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getMobileSession():ExpectNotification("OnHashChange")
end

local function createInteractionChoiceSet(pIntChSetId)
  local requestParams = {
    interactionChoiceSetID = pIntChSetId,
    choiceSet = {
      {
        choiceID = pIntChSetId,
        menuName ="Choice100" .. pIntChSetId,
        vrCommands = {
          "Choice100" .. pIntChSetId
        }
      }
    }
  }
  local cid = common.getMobileSession():SendRPC("CreateInteractionChoiceSet", requestParams)
  common.getHMIConnection():ExpectRequest("VR.AddCommand")
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getMobileSession():ExpectNotification("OnHashChange")
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Create big file for streaming", createFile)
common.Step("Start SDL and HMI", common.start, { "012_one_app_streaming_rpc_processing" })
common.Step("Connect Mobile", common.connectMobile)
common.Step("Register App", common.registerApp)
common.Step("PolicyTableUpdate with HMI types", common.policyTableUpdate)
common.Step("Activate App", common.activateApp)

common.Title("Test")
common.Step("Start video streaming", common.startVideoStreaming, { fileName, 1, 5000000, false })
for i = 1, numOfTries do
  common.Step("AddCommand " .. i, addCommand, { i })
  common.Step("CreateInteractionChoiceSet " .. i, createInteractionChoiceSet, { i })
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop video streaming", common.stopVideoStreaming, { fileName })
common.Step("Delete big file for streaming", deleteFile)
common.Step("Stop SDL", common.postconditions)
