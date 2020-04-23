--  Requirement summary:
--  TBD
--
--  Description:
--  Check that SDL forwards OnSystemCapabilityUpdated notification 
--  to the WebEngine projection app 
--
--  Used precondition
--  SDL, HMI are running on system.
--
--  Performed steps
--  1) WebEngine projection app tries to register
--  SDL does:
--  - proceed with `RAI` request successfully
--  - not send `OnSystemCapabilityUpdated` to the WebEngine projection app
--  2) HMI sends `OnSystemCapabilityUpdated` to SDL
--
--  Expected behavior:
--  SDL transfers `OnSystemCapabilityUpdated` notification to the WebEngine projection app 
---------------------------------------------------------------------------------------------------
-- [[ Required Shared Libraries ]]
local common = require('test_scripts/WebEngine/commonWebEngine')

--[[ Test Configuration ]]
config.defaultMobileAdapterType = "WS"
common.testSettings.restrictions.sdlBuildOptions = {{ webSocketServerSupport = {"ON"} }}

--[[ Local Variables ]]
local appHMIType = "WEB_VIEW"

--[[ General configuration parameters ]]
config.application1.registerAppInterfaceParams.appHMIType = { appHMIType }
config.application1.registerAppInterfaceParams.syncMsgVersion.majorVersion = 6
config.application1.registerAppInterfaceParams.syncMsgVersion.minorVersion = 2

--[[ Local Functions ]]
local function sendRegisterApp()
  common.getMobileSession():ExpectNotification("OnSystemCapabilityUpdated"):Times(0)
  common.registerAppWOPTU()
end

local function sendOnSCU()
  local paramsToSDL = common.getOnSystemCapabilityParams()
  paramsToSDL.appID = common.getHMIAppId()
  common.getHMIConnection():SendNotification("BasicCommunication.OnSystemCapabilityUpdated", paramsToSDL)
  common.getMobileSession():ExpectNotification("OnSystemCapabilityUpdated", common.getOnSystemCapabilityParams())
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Update WS Server Certificate parameters in smartDeviceLink.ini file", common.commentAllCertInIniFile)
common.Step("Start SDL, HMI", common.startWOdeviceConnect)
common.Step("Connect WebEngine device", common.connectWebEngine, { 1, config.defaultMobileAdapterType })

common.Title("Test")
common.Step("App sends RAI RPC no OnSCU notification", sendRegisterApp)
common.Step("HMI sends OnSCU notification", sendOnSCU)

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)

