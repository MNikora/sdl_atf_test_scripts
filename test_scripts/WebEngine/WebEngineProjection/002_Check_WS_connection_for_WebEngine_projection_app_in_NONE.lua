--  Requirement summary:
--  TBD
--
--  Description:
--  Check that SDL doesn't close the connection with WebEngine 
--  projection app if the app was closed (HMILevel NONE is assigned)
--
--  Used precondition
--  SDL, HMI are running on the system.
--  WebEngine projection app is connected to SDL, successfully 
--  registered and activated (HMI level is FULL)
--
--  Performed steps
--  HMI->SDL: BasicCommunication.OnExitApplication(reason = "USER_EXIT")
--
--  Expected behavior:
--  1. SDL assigns HMILevel (NONE) to the WebEngine projection app and doesn't close the WebSocket connection
--  2. WebEngine projection app can be successfully activated using remained connection to SDL 
---------------------------------------------------------------------------------------------------
-- [[ Required Shared Libraries ]]
local common = require('test_scripts/WebEngine/commonWebEngine')

--[[ Test Configuration ]]
config.defaultMobileAdapterType = "WS"
common.testSettings.restrictions.sdlBuildOptions = {{ webSocketServerSupport = { "ON" }}}

--[[ Local Variables ]]
local appHMIType = "WEB_VIEW"

--[[ General configuration parameters ]]
config.application1.registerAppInterfaceParams.appHMIType = { appHMIType }
config.application1.registerAppInterfaceParams.syncMsgVersion.majorVersion = 6
config.application1.registerAppInterfaceParams.syncMsgVersion.minorVersion = 2

local function deactivateAppToNoneAndCheckConnection()
  common.getHMIConnection():SendNotification("BasicCommunication.OnExitApplication",
    { appID = common.getHMIAppId(), reason = "USER_EXIT" })
  common.getMobileSession():ExpectNotification("OnHMIStatus",
    { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
    common.getMobileSession():ExpectEvent(common.disconnectedEvent, "Disconnected")
  :Times(0)
  :Timeout(10000)
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Update WS Server Certificate parameters in smartDeviceLink.ini file", common.commentAllCertInIniFile)
common.Step("Start SDL, HMI", common.startWOdeviceConnect)
common.Step("Connect WebEngine device", common.connectWebEngine, { 1, config.defaultMobileAdapterType })

common.Title("Test")
common.Step("Register App", common.registerApp)
common.Step("Activate web app", common.activateApp, { 1 })
common.Step("Deactivate web app to NONE and check connection", deactivateAppToNoneAndCheckConnection)
common.Step("Check connection via successful activation", common.activateApp, { 1 })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)

