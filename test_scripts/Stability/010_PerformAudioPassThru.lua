---------------------------------------------------------------------------------------------------
-- PerformAudioPassThru - 500 times
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Stability/common')

--[[ Local Variables ]]
local numOfTries = 500

local requestParams = {
  initialPrompt = {
    {
      text = "Makeyourchoice",
      type = "TEXT",
    },
  },
  audioPassThruDisplayText1 = "DisplayText1",
  audioPassThruDisplayText2 = "DisplayText2",
  samplingRate = "8KHZ",
  maxDuration = 2000,
  bitsPerSample = "8_BIT",
  audioType = "PCM",
  muteAudio = true
}

local requestUiParams = {
  audioPassThruDisplayTexts = {
    [1] = {
      fieldName = "audioPassThruDisplayText1",
      fieldText = requestParams.audioPassThruDisplayText1
    },
    [2] = {
      fieldName = "audioPassThruDisplayText2",
      fieldText = requestParams.audioPassThruDisplayText2
    }
  },
  maxDuration = requestParams.maxDuration,
  muteAudio = requestParams.muteAudio
}

local requestTtsParams = {
  ttsChunks = common.cloneTable(requestParams.initialPrompt),
  speakType = "AUDIO_PASS_THRU"
}

local allParams = {
  requestParams = requestParams,
  requestUiParams = requestUiParams,
  requestTtsParams = requestTtsParams
}

--[[ Local Functions ]]
local function sendOnSystemContext(pCtx, pAppID)
  common.getHMIConnection():SendNotification("UI.OnSystemContext", { appID = pAppID, systemContext = pCtx })
end

local function performAudioPassThru(pParams)
  local cid = common.getMobileSession():SendRPC("PerformAudioPassThru", pParams.requestParams)
  pParams.requestUiParams.appID = common.getHMIAppId()
  common.getHMIConnection():ExpectRequest("TTS.Speak", pParams.requestTtsParams)
  :Do(function(_, data)
      common.getHMIConnection():SendNotification("TTS.Started")
      local function ttsSpeakResponse()
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
        common.getHMIConnection():SendNotification("TTS.Stopped")
      end
      common.runAfter(ttsSpeakResponse, 100)
    end)
  common.getHMIConnection():ExpectRequest("UI.PerformAudioPassThru", pParams.requestUiParams)
  :Do(function(_, data)
      sendOnSystemContext("HMI_OBSCURED", pParams.requestUiParams.appID)
      local function uiResponse()
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
        sendOnSystemContext("MAIN", pParams.requestUiParams.appID)
      end
      common.runAfter(uiResponse, 1500)
    end)
  common.getHMIConnection():ExpectNotification("UI.OnRecordStart", { appID = pParams.requestUiParams.appID })
  common.getMobileSession():ExpectNotification("OnHMIStatus",
    { hmiLevel = "FULL", audioStreamingState = "ATTENUATED", systemContext = "MAIN" },
    { hmiLevel = "FULL", audioStreamingState = "ATTENUATED", systemContext = "HMI_OBSCURED" },
    { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "HMI_OBSCURED" },
    { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
  :Times(4)
  common.getMobileSession():ExpectNotification("OnAudioPassThru")
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL and HMI", common.start, { "010_perform_audio_pass_thru" })
common.Step("Connect Mobile", common.connectMobile)
common.Step("Register App", common.registerApp)
common.Step("Activate App", common.activateApp)

common.Title("Test")
for i = 1, numOfTries do
  common.Step("PerformAudioPassThru " .. i, performAudioPassThru, { allParams })
end

common.Step("IDLE", common.IDLE, { 1000, 300 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
