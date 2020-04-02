--  Requirement summary:
--  [RegisterAppInterface] SUCCESS
--  [RegisterAppInterface] RegisterAppInterface and HMILevel
--
--  Description:
--  Check that it is possible to register App with HMI type WEB_VIEW.
--
--  Used precondition
--  SDL, HMI are running on system.
--  Mobile device is connected to SDL.
--
--  Performed steps
--  appID->RegisterAppInterface(params)
--
--  Expected behavior:
--  1. SDL successfully registers application,responds to RAI request from mobile app and notifies HMI
--     SDL->HMI: OnAppRegistered(params)
--     SDL->appID: SUCCESS, success:"true":RegisterAppInterface()
--  2. SDL assignes HMILevel (NONE) to registered application and sends it a OnHMIStatus notification:
--     SDL->appID: OnHMIStatus(HMlLevel, audioStreamingState, systemContext)
---------------------------------------------------------------------------------------------------
-- [[ Required Shared Libraries ]]
local common = require('test_scripts/WebEngine/commonWebEngine')

--[[ Local Variables ]]
local appHMIType = "WEB_VIEW"

--[[ General configuration parameters ]]
config.application1.registerAppInterfaceParams.appHMIType = { appHMIType }
config.application1.registerAppInterfaceParams.syncMsgVersion.majorVersion = 6
config.application1.registerAppInterfaceParams.syncMsgVersion.minorVersion = 2

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL, HMI, connect Mobile", common.start)

common.Title("Test")
common.Step("Register App", common.registerApp)

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)

