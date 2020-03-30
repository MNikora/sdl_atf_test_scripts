---------------------------------------------------------------------------------------------------
-- PerformInteraction - 500 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("user_modules/sequences/actions")
local utils = require("user_modules/utils")
local SDL = require("SDL")
local common_stability = require('test_scripts/Stability/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local numOfTries = 500

local putFileParams = {
  requestParams = {
    syncFileName = 'icon.png',
    fileType = "GRAPHIC_PNG",
    persistentFile = false,
    systemFile = false
  },
  filePath = "files/icon.png"
}

local function getPathToFileInAppStorage(pFileName)
  return SDL.AppStorage.path() .. common.getConfigAppParams().fullAppID .. "_"
    .. utils.getDeviceMAC() .. "/" .. pFileName
end

local ImageValue = {
  value = getPathToFileInAppStorage("icon.png"),
  imageType = "DYNAMIC",
}

local function getPromptValue(pText)
  return {
    {
      text = pText,
      type = "TEXT"
    }
  }
end

local initialPromptValue = getPromptValue(" Make your choice ")

local helpPromptValue = getPromptValue(" Help Prompt ")

local timeoutPromptValue = getPromptValue(" Time out ")

local vrHelpvalue = {
  {
    text = " New VRHelp ",
    position = 1,
    image = ImageValue
  }
}

local requestParams = {
  initialText = "StartPerformInteraction",
  initialPrompt = initialPromptValue,
  interactionMode = "BOTH",
  interactionChoiceSetIDList = {
    100, 200, 300
  },
  helpPrompt = helpPromptValue,
  timeoutPrompt = timeoutPromptValue,
  timeout = 5000,
  vrHelp = vrHelpvalue,
  interactionLayout = "ICON_ONLY"
}

--[[ Local Functions ]]
local function setChoiceSet(pChoiceIDValue)
  local temp = {
    {
      choiceID = pChoiceIDValue,
      menuName ="Choice" .. tostring(pChoiceIDValue),
      vrCommands = {
        "VrChoice" .. tostring(pChoiceIDValue),
      },
      image = {
        value ="icon.png",
        imageType ="STATIC",
      }
    }
  }
  return temp
end

local function setChoiceSet_noVR(pChoiceIDValue)
  return {
    {
      choiceID = pChoiceIDValue,
      menuName ="Choice" .. tostring(pChoiceIDValue),
      image = {
        value ="icon.png",
        imageType ="STATIC",
      }
    }
  }
end

local function sendOnSystemContext(pCtx)
  common.getHMIConnection():SendNotification("UI.OnSystemContext", {
    appID = common.getHMIAppId(),
    systemContext = pCtx
  })
end

local function setExChoiceSet(pChoiceIDValues)
  local exChoiceSet = { }
  for i = 1, #pChoiceIDValues do
    exChoiceSet[i] = {
      choiceID = pChoiceIDValues[i],
      image = {
        value = "icon.png",
        imageType = "STATIC",
      },
      menuName = "Choice" .. pChoiceIDValues[i]
    }
  end
  return exChoiceSet
end

local function expectOnHMIStatusWithAudioStateChanged_PI(pRequest)
  if pRequest == "BOTH" then
    common.getMobileSession():ExpectNotification("OnHMIStatus",
      { hmiLevel = "FULL", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" },
      { hmiLevel = "FULL", audioStreamingState = "NOT_AUDIBLE", systemContext = "VRSESSION" },
      { hmiLevel = "FULL", audioStreamingState = "ATTENUATED", systemContext = "VRSESSION" },
      { hmiLevel = "FULL", audioStreamingState = "ATTENUATED", systemContext = "HMI_OBSCURED" },
      { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "HMI_OBSCURED" },
      { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
    :Times(6)
  elseif pRequest == "VR" then
    common.getMobileSession():ExpectNotification("OnHMIStatus",
      { systemContext = "MAIN", hmiLevel = "FULL", audioStreamingState = "ATTENUATED" },
      { systemContext = "MAIN", hmiLevel = "FULL", audioStreamingState = "NOT_AUDIBLE" },
      { systemContext = "VRSESSION", hmiLevel = "FULL", audioStreamingState = "NOT_AUDIBLE" },
      { systemContext = "VRSESSION", hmiLevel = "FULL", audioStreamingState = "AUDIBLE" },
      { systemContext = "MAIN", hmiLevel = "FULL", audioStreamingState = "AUDIBLE" })
    :Times(5)
  elseif pRequest == "MANUAL" then
    common.getMobileSession():ExpectNotification("OnHMIStatus",
      { systemContext = "MAIN", hmiLevel = "FULL", audioStreamingState = "ATTENUATED" },
      { systemContext = "HMI_OBSCURED", hmiLevel = "FULL", audioStreamingState = "ATTENUATED" },
      { systemContext = "HMI_OBSCURED", hmiLevel = "FULL", audioStreamingState = "AUDIBLE" },
      { systemContext = "MAIN", hmiLevel = "FULL", audioStreamingState = "AUDIBLE" })
    :Times(4)
  end
end

local function createInteractionChoiceSet(pChoiceSetID)
  local choiceID = pChoiceSetID
  local cid = common.getMobileSession():SendRPC("CreateInteractionChoiceSet", {
      interactionChoiceSetID = pChoiceSetID,
      choiceSet = setChoiceSet(choiceID),
    })
  common.getHMIConnection():ExpectRequest("VR.AddCommand", {
      cmdID = choiceID,
      type = "Choice",
      vrCommands = { "VrChoice" .. tostring(choiceID) }
    })
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
    end)
  common.getMobileSession():ExpectResponse(cid, { resultCode = "SUCCESS", success = true })
end

local function createInteractionChoiceSet_noVR(pChoiceSetID)
  local choiceID = pChoiceSetID
  local cid = common.getMobileSession():SendRPC("CreateInteractionChoiceSet", {
      interactionChoiceSetID = pChoiceSetID,
      choiceSet = setChoiceSet_noVR(choiceID),
    })
  common.getMobileSession():ExpectResponse(cid, { resultCode = "SUCCESS", success = true })
end

local function PI_ViaMANUAL_ONLY(pParams)
  pParams.interactionMode = "MANUAL_ONLY"
  local cid = common.getMobileSession():SendRPC("PerformInteraction", pParams)
  common.getHMIConnection():ExpectRequest("VR.PerformInteraction", {
      helpPrompt = pParams.helpPrompt,
      initialPrompt = pParams.initialPrompt,
      timeout = pParams.timeout,
      timeoutPrompt = pParams.timeoutPrompt
    })
  :Do(function(_, data)
      common.getHMIConnection():SendNotification("TTS.Started")
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
    end)
  common.getHMIConnection():ExpectRequest("UI.PerformInteraction", {
      timeout = pParams.timeout,
      choiceSet = setExChoiceSet(pParams.interactionChoiceSetIDList),
      initialText = {
        fieldName = "initialInteractionText",
        fieldText = pParams.initialText
      }
    })
  :Do(function(_, data)
      sendOnSystemContext("HMI_OBSCURED")
      local function uiResponse()
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {
          choiceID = pParams.interactionChoiceSetIDList[1]
        })
        common.getHMIConnection():SendNotification("TTS.Stopped")
        sendOnSystemContext("MAIN")
      end
      common.run.runAfter(uiResponse, 1000)
    end)
  expectOnHMIStatusWithAudioStateChanged_PI("MANUAL")
  common.getMobileSession():ExpectResponse(cid, {
    success = true, resultCode = "SUCCESS", choiceID = pParams.interactionChoiceSetIDList[1]
  })
end

local function putFile(pParams)
  local cid = common.getMobileSession():SendRPC("PutFile", pParams.requestParams, pParams.filePath)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start metrics_collecting", common_stability.collect_metrics, {"perform_interaction"})
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("Upload icon file", putFile, { putFileParams })
runner.Step("CreateInteractionChoiceSet with id 100", createInteractionChoiceSet, { 100 })
runner.Step("CreateInteractionChoiceSet with id 200", createInteractionChoiceSet, { 200 })
runner.Step("CreateInteractionChoiceSet with id 300", createInteractionChoiceSet, { 300 })
runner.Step("CreateInteractionChoiceSet no VR commands with id 400", createInteractionChoiceSet_noVR, { 400 })

runner.Title("Test")
for i = 1, numOfTries do
  runner.Step("PerformInteraction " .. i, PI_ViaMANUAL_ONLY, { requestParams })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
