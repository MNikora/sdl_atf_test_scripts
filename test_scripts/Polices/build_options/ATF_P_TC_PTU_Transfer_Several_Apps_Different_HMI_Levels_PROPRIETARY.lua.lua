--UNREADY:
---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [PolicyTableUpdate] Requirements for HMILevel of the application(s)
--taking part in Policy Update
--
-- Description:
-- Policies Manager must randomly select the application through which to send the policy table packet
-- and request an update to its local policy table only through apps with HMI status of BACKGROUND, LIMITED, and FULL.
-- If there are no mobile apps with any of these statuses, the system must use an app with an HMI Level of NONE.
--
-- Preconditions:
-- SDL is built with "-DEXTENDED_POLICY: PROPRIETARY" flag
-- There are registered 4 apps each with different HMILevel
-- app_1: NONE, app_2: LIMITED, app_3: BACKGROUND, app_4: FULL
--Performed steps
-- PTU is requested
-- SDL->HMI:SDL.OnStatusUpdate(UPDATE_NEEDED)
--
-- Expected result:
-- SDL chooses randomly between the app_2, app_3, app_4 to send OnSystemRequest
-- app_1 doesn't take part in PTU (except of the case when app_1 is the only application being run on SDL)
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local mobileSession = require("mobile_session")

--[[ Local Variables ]]
local expectedResult = {2, 3, 4} -- Expected Ids of applications
local actualResult = { } -- Actual Ids of applications
local sequence = { }
local hmiLevels = { }

--[[ Local Functions ]]
local function log(item)
  sequence[#sequence + 1] = item
end

local function contains(t, item)
  for _, v in pairs(t) do
    if v == item then
      return true
    end
  end
  return false
end

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require("connecttest")
require('cardinalities')
require("user_modules/AppTypes")

--[[ Specific Notifications ]]
EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate")
:Do(function(_, d)
    log("SDL->HMI: SDL.OnStatusUpdate(" .. d.params.status .. ")")
  end)
:Times(AnyNumber())
:Pin()

EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
:Do(function(_, _)
    log("SDL->HMI: BC.PolicyUpdate")
  end)
:Times(AnyNumber())
:Pin()

EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered")
:Do(function(_, d)
    log("SDL->HMI: BC.OnAppRegistered('".. d.params.application.appName .. "')")
  end)
:Times(AnyNumber())
:Pin()

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

for i = 1, 4 do
  Test["Precondition_RegisterApplication_" .. i] = function()
    config["application" .. i].registerAppInterfaceParams.appName = "App_" .. i
    config.application3.registerAppInterfaceParams.appHMIType = { "DEFAULT" }
    config.application4.registerAppInterfaceParams.appHMIType = { "DEFAULT" }
    config.application2.registerAppInterfaceParams.isMediaApplication = false
    config.application2.registerAppInterfaceParams.appHMIType = { "NAVIGATION" }
  end
end

-- Start 3 additional mobile sessions
for i = 2, 4 do
  Test["Precondition_StartSession_" .. i] = function(self)
    self["mobileSession" .. i] = mobileSession.MobileSession(self, self.mobileConnection)
    self["mobileSession" .. i]:StartService(7)
  end
end

-- Register 3 additional apps
for i = 2, 4 do
  Test["Precondition_RegisterApp_" .. i] = function(self)
    EXPECT_HMICALL("BasicCommunication.UpdateAppList")
    :Do(function(_, d)
        self.hmiConnection:SendResponse(d.id, d.method, "SUCCESS", { })
        self.applications = { }
        for _, app in pairs(d.params.applications) do
          self.applications[app.appName] = app.appID
        end
      end)
    local corId = self["mobileSession" .. i]:SendRPC("RegisterAppInterface", config["application" .. i].registerAppInterfaceParams)
    self["mobileSession" .. i]:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
  end
end

function Test:Precondition_RegisterOnHMIStatusNotifications()
  self.mobileSession:ExpectNotification("OnHMIStatus")
  :Do(function(_, d)
      log("SDL->MOB: OnHMIStatus, App_1('".. tostring(d.payload.hmiLevel) .. "')")
      hmiLevels[1] = tostring(d.payload.hmiLevel)
    end)
  :Times(AnyNumber())
  :Pin()
  for i = 2, 4 do
    self["mobileSession" .. i]:ExpectNotification("OnHMIStatus")
    :Do(function(_, d)
        log("SDL->MOB: OnHMIStatus, App_" .. i .. "('".. tostring(d.payload.hmiLevel) .. "')")
        hmiLevels[i] = tostring(d.payload.hmiLevel)
      end)
    :Times(AnyNumber())
    :Pin()
  end
end

-- Set particular HMILevel for each app
function Test:Precondition_ActivateApp_1()
  local requestId1 = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications["App_2"] })
  EXPECT_HMIRESPONSE(requestId1)
  :Do(function(_, data1)
      if data1.result.isSDLAllowed ~= true then
        local requestId2 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage",
          { language = "EN-US", messageCodes = { "DataConsent" } })
        EXPECT_HMIRESPONSE(requestId2)
        :Do(function(_, _)
            self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
              { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = "127.0.0.1" } })
            EXPECT_HMICALL("BasicCommunication.ActivateApp")
            :Do(function(_, data2)
                self.hmiConnection:SendResponse(data2.id,"BasicCommunication.ActivateApp", "SUCCESS", { })
              end)
            :Times(1)
          end)
      end
    end)
end

function Test:Precondition_ActivateApp_2()
  local requestId1 = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications["App_3"]})
  EXPECT_HMIRESPONSE(requestId1)
end

function Test:Precondition_ActivateApp_3()
  local requestId1 = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications["App_4"]})
  EXPECT_HMIRESPONSE(requestId1)
end

function Test.Precondition_ShowHMILevels_All()
  if hmiLevels[1] == nil then
    hmiLevels[1] = "NONE"
  end
  print("--- HMILevels (app: level) -----------------------")
  for k, v in pairs(hmiLevels) do
    print(k .. ": " .. v)
  end
  print("--------------------------------------------------")
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_RegisterOnSystemRequestNotifications()
  self.mobileSession:ExpectNotification("OnSystemRequest")
  :Do(function(_, _)
      log("SDL->MOB: OnSystemRequest, App_1()")
      actualResult[#actualResult+1] = 1
    end)
  :Times(AnyNumber())
  :Pin()
  for i = 2, 4 do
    self["mobileSession" .. i]:ExpectNotification("OnSystemRequest")
    :Do(function(_, _)
        log("SDL->MOB: OnSystemRequest, App_" .. i)
        actualResult[#actualResult+1] = i
      end)
    :Times(AnyNumber())
    :Pin()
  end
end

function Test:TestStep_StartPTU()
  local requestId = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  log("HMI->SDL: SDL.GetURLS")
  EXPECT_HMIRESPONSE(requestId)
  :Do(function(_, _)
      log("SDL->HMI: SDL.GetURLS")
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest", { requestType = "PROPRIETARY", fileName = "PolicyTableUpdate" })
      log("HMI->SDL: BC.OnSystemRequest")
      requestId = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", { language = "EN-US", messageCodes = { "StatusUpToDate" } })
      log("HMI->SDL: SDL.GetUserFriendlyMessage")
      EXPECT_HMIRESPONSE(requestId)
      log("SDL->HMI: SDL.GetUserFriendlyMessage")
    end)
end

function Test.TestStep_ShowSequence()
  print("--- Sequence -------------------------------------")
  for k, v in pairs(sequence) do
    print(k .. ": " .. v)
  end
  print("--------------------------------------------------")
end

function Test.TestStep_ValidateResult()
  EXPECT_ANY()
  :ValidIf(function(_, _)
      if #actualResult ~= 1 then
        return false, "Expected occurance of OnSystemRequest() is 1, got: " .. tostring(#actualResult)
      else
        if not contains(expectedResult, actualResult[1]) then
          return false, "Expected OnSystemRequest() from Apps: " .. table.concat(expectedResult, ", ") .. ", got: " .. tostring(actualResult[1])
        end
      end
      return true
    end)
  :Times(1)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
function Test.Postcondition_Stop_SDL()
  StopSDL()
end

