---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies] PTU "RequestType" array is ommited
--
-- Check SDL behavior in case optional parameter ith invalid type in received PTU
-- 1. Used preconditions:
-- Do not start default SDL
-- Prepare PTU file with "<appID>" policies and "RequestType" array is omitted at all
-- Start SDL
-- InitHMI register MobileApp
-- Perform PT update
--
-- 2. Performed steps:
-- Check LocalPT changes
--
-- Expected result:
-- SDL must:
-- a) assign "RequestType" field from "default" section of PolicyDataBase to such app
-- b) copy "RequestType" field from "default" section to "<appID>" section of PolicyDataBase
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local json = require("modules/json")
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
local mobile_session = require('mobile_session')
local config = require('config')
local utils = require ('user_modules/utils')

--[[ General Precondition before ATF start ]]
commonFunctions:SDLForceStop()
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General configuration parameters ]]
Test = require('connecttest')

require('cardinalities')
require('user_modules/AppTypes')

--[[ Local Variables ]]
local basePtuFile = "files/ptu.json"
local ptuAppRegistered = "files/ptu_app.json"
local PRELOADED_PT_FILE_NAME = "sdl_preloaded_pt.json"
local HMIAppId

local TESTED_DATA = {
  preloaded = {
    policy_table = {
      app_policies = {
        default = {
          keep_context = true,
          steal_focus = false,
          priority = "NONE",
          default_hmi = "NONE",
          RequestType = {
            "TRAFFIC_MESSAGE_CHANNEL",
            "PROPRIETARY",
            "QUERY_APPS"
          },
          groups = {"Base-4"}
        },
        device = {
          keep_context = false,
          steal_focus = false,
          priority = "NONE",
          default_hmi = "NONE",
          RequestType = {
            "TRAFFIC_MESSAGE_CHANNEL",
            "PROPRIETARY",
            "HTTP"
          },
          groups = {"BaseBeforeDataConsent"}
        }
      }
    }
  },
  update = {
    policy_table = {
      app_policies = {
        default = {
          keep_context = true,
          steal_focus = false,
          priority = "NONE",
          default_hmi = "LIMITED",
          RequestType = {
            "TRAFFIC_MESSAGE_CHANNEL",
            "HTTP",
            "QUERY_APPS"
          },
          groups = {"Base-6"}
        }
      }
    }
  }
}

local TestData = {
  path = config.pathToSDL .. "TestData",
  isExist = false,
  init = function(self)
    if not self.isExist then
      os.execute("mkdir ".. self.path)
      os.execute("echo 'List test data files files:' > " .. self.path .. "/index.txt")
      self.isExist = true
    end
  end,
  store = function(self, message, pathToFile, fileName)
    if self.isExist then
      local dataToWrite = message

      if pathToFile and fileName then
        os.execute(table.concat({"cp ", pathToFile, " ", self.path, "/", fileName}))
        dataToWrite = table.concat({dataToWrite, " File: ", fileName})
      end

      dataToWrite = dataToWrite .. "\n"
      local file = io.open(self.path .. "/index.txt", "a+")
      file:write(dataToWrite)
      file:close()
    end
  end,
  delete = function(self)
    if self.isExist then
      os.execute("rm -r -f " .. self.path)
      self.isExist = false
    end
  end,
  info = function(self)
    if self.isExist then
      commonFunctions:userPrint(35, "All test data generated by this test were stored to folder: " .. self.path)
    else
      commonFunctions:userPrint(35, "No test data were stored" )
    end
  end
}

--[[ Local Functions ]]

local function addApplicationToPTJsonFile(basicFile, newPtFile, appName, app)
  local pt = io.open(basicFile, "r")
  if pt == nil then
    error("PTU file not found")
  end
  local ptString = pt:read("*all")
  pt:close()

  local ptTable = json.decode(ptString)
  ptTable["policy_table"]["app_policies"][appName] = app
  -- Workaround. null value in lua table == not existing value. But in json file it has to be
  ptTable["policy_table"]["functional_groupings"]["DataConsent-2"]["rpcs"] = json.null
  local ptJson = json.encode(ptTable)
  local newPtu = io.open(newPtFile, "w")
  newPtu:write(ptJson)
  newPtu:close()
end

local function activateApp(self, HMIAppID)
  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = HMIAppID})

  --hmi side: expect SDL.ActivateApp response
  EXPECT_HMIRESPONSE(RequestId)
  :Do(function(_,data)
      --In case when app is not allowed, it is needed to allow app
      if data.result.isSDLAllowed ~= true then
        --hmi side: sending SDL.GetUserFriendlyMessage request
        RequestId = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage",
          {language = "EN-US", messageCodes = {"DataConsent"}})

        EXPECT_HMIRESPONSE(RequestId)
        :Do(function(_,_)

            --hmi side: send request SDL.OnAllowSDLFunctionality
            self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
              {allowed = true, source = "GUI", device = {id = utils.getDeviceMAC(), name = utils.getDeviceName()}})

            --hmi side: expect BasicCommunication.ActivateApp request
            EXPECT_HMICALL("BasicCommunication.ActivateApp")
            :Do(function(_,data2)

                --hmi side: sending BasicCommunication.ActivateApp response
                self.hmiConnection:SendResponse(data2.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
              end)
            -- :Times()
          end)
        EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN" })
      end
    end)
end

function Test:updatePolicyInDifferentSessions(PTName, appName, mobileSession)

  local iappID = self.applications[appName]
  local requestId = self.hmiConnection:SendRequest("SDL.GetPolicyConfigurationData",
      { policyType = "module_config", property = "endpoints" })
  EXPECT_HMIRESPONSE(requestId)
  :Do(function(_,_)
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
        {
          requestType = "PROPRIETARY",
          fileName = "filename",
        }
      )
      mobileSession:ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
      :Do(function(_,_)
          local CorIdSystemRequest = mobileSession:SendRPC("SystemRequest",
            {
              fileName = "PolicyTableUpdate",
              requestType = "PROPRIETARY",
              appID = iappID
            },
            PTName)

          local systemRequestId
          EXPECT_HMICALL("BasicCommunication.SystemRequest")
          :Do(function(_,_data1)
              systemRequestId = _data1.id
              self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate",
                {
                  policyfile = "/tmp/fs/mp/images/ivsu_cache/PolicyTableUpdate"
                }
              )
              local function to_run()
                self.hmiConnection:SendResponse(systemRequestId,"BasicCommunication.SystemRequest", "SUCCESS", {})
              end

              RUN_AFTER(to_run, 500)
            end)

          EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate")
          :ValidIf(function(exp,data)
              if
              exp.occurences == 1 and
              (data.params.status == "UP_TO_DATE" or data.params.status == "UPDATING"
                or data.params.status == "UPDATE_NEEDED") then
                return true
              elseif
                exp.occurences == 2 and
                data.params.status == "UP_TO_DATE" then
                  return true
                else
                  if exp.occurences == 2 then
                    print ("\27[31m SDL.OnStatusUpdate came with wrong values. Expected in second occurrences status 'UP_TO_DATE', got '" .. tostring(data.params.status) .. "' \27[0m")
                    return false
                  end
                end
              end)
            :Times(Between(1,2))

            mobileSession:ExpectResponse(CorIdSystemRequest, { success = true, resultCode = "SUCCESS"})
            :Do(function(_,_)
                local RequestIdGetUserFriendlyMessage = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"StatusUpToDate"}})
                EXPECT_HMIRESPONSE(RequestIdGetUserFriendlyMessage,{result = {code = 0, method = "SDL.GetUserFriendlyMessage"}})
              end)

          end)
      end)
  end

  local function constructPathToDatabase()
    if commonSteps:file_exists(config.pathToSDL .. "storage/policy.sqlite") then
      return config.pathToSDL .. "storage/policy.sqlite"
    elseif commonSteps:file_exists(config.pathToSDL .. "policy.sqlite") then
      return config.pathToSDL .. "policy.sqlite"
    else
      commonFunctions:userPrint(31, "policy.sqlite is not found" )
      return nil
    end
  end

  local function executeSqliteQuery(rawQueryString, dbFilePath)
    if not dbFilePath then
      return nil
    end
    local queryExecutionResult = {}
    local queryString = table.concat({"sqlite3 ", dbFilePath, " '", rawQueryString, "'"})
    local file = io.popen(queryString, 'r')
    if file then
      local index = 1
      for line in file:lines() do
        queryExecutionResult[index] = line
        index = index + 1
      end
      file:close()
      return queryExecutionResult
    else
      return nil
    end
  end

  local function isValuesCorrect(actualValues, expectedValues)
    if #actualValues ~= #expectedValues then
      return false
    end

    local tmpExpectedValues = {}
    for i = 1, #expectedValues do
      tmpExpectedValues[i] = expectedValues[i]
    end

    local isFound
    for j = 1, #actualValues do
      isFound = false
      for key, value in pairs(tmpExpectedValues) do
        if value == actualValues[j] then
          isFound = true
          tmpExpectedValues[key] = nil
          break
        end
      end
      if not isFound then
        return false
      end
    end
    if next(tmpExpectedValues) then
      return false
    end
    return true
  end

  function Test.checkLocalPT(checkTable)
    local expectedLocalPtValues
    local queryString
    local actualLocalPtValues
    local comparationResult
    local isTestPass = true
    for _, check in pairs(checkTable) do
      expectedLocalPtValues = check.expectedValues
      queryString = check.query
      actualLocalPtValues = executeSqliteQuery(queryString, constructPathToDatabase())
      if actualLocalPtValues then
        comparationResult = isValuesCorrect(actualLocalPtValues, expectedLocalPtValues)
        if not comparationResult then
          TestData:store(table.concat({"Test ", queryString, " failed: SDL has wrong values in LocalPT"}))
          TestData:store("ExpectedLocalPtValues")
          commonFunctions:userPrint(31, table.concat({"Test ", queryString, " failed: SDL has wrong values in LocalPT"}))
          commonFunctions:userPrint(35, "ExpectedLocalPtValues")
          for _, values in pairs(expectedLocalPtValues) do
            TestData:store(values)
            print(values)
          end
          TestData:store("ActualLocalPtValues")
          commonFunctions:userPrint(35, "ActualLocalPtValues")
          for _, values in pairs(actualLocalPtValues) do
            TestData:store(values)
            print(values)
          end
          isTestPass = false
        end
      else
        TestData:store("Test failed: Can't get data from LocalPT")
        commonFunctions:userPrint(31, "Test failed: Can't get data from LocalPT")
        isTestPass = false
      end
    end
    return isTestPass
  end

  local function prepareJsonPTU(name, newPTUfile)
    local json_app = [[ {
      "keep_context": false,
      "steal_focus": false,
      "priority": "NONE",
      "default_hmi": "NONE",
      "groups": ["Location-1"]
    }]]
    local app = json.decode(json_app)
    -- ToDo (aderiabin): This function must be replaced by call
    -- testCasesForPolicyTable:AddApplicationToPTJsonFile(basePtuFile, newPTUfile, name, app)
    -- after merge of pull request #227
    addApplicationToPTJsonFile(basePtuFile, newPTUfile, name, app)
  end

  function Test.backupPreloadedPT(backupPrefix)
    os.execute(table.concat({"cp ", config.pathToSDL, PRELOADED_PT_FILE_NAME, " ", config.pathToSDL, backupPrefix, PRELOADED_PT_FILE_NAME}))
  end

  function Test.restorePreloadedPT(backupPrefix)
    os.execute(table.concat({"mv ", config.pathToSDL, backupPrefix, PRELOADED_PT_FILE_NAME, " ", config.pathToSDL, PRELOADED_PT_FILE_NAME}))
  end

  local function updateJSON(pathToFile, updaters)
    local file = io.open(pathToFile, "r")
    local json_data = file:read("*a")
    file:close()

    local data = json.decode(json_data)
    if data then
      for _, updateFunc in pairs(updaters) do
        updateFunc(data)
      end
      -- Workaround. null value in lua table == not existing value. But in json file it has to be
      data.policy_table.functional_groupings["DataConsent-2"].rpcs = "tobedeletedinjsonfile"
      local dataToWrite = json.encode(data)
      dataToWrite = string.gsub(dataToWrite, "\"tobedeletedinjsonfile\"", "null")
      file = io.open(pathToFile, "w")
      file:write(dataToWrite)
      file:close()
    end

  end

  function Test.preparePreloadedPT()
    local preloadedUpdaters = {
      function(data)
        data.policy_table.app_policies.default = TESTED_DATA.preloaded.policy_table.app_policies.default
        data.policy_table.app_policies.device = TESTED_DATA.preloaded.policy_table.app_policies.device
      end
    }
    updateJSON(config.pathToSDL .. PRELOADED_PT_FILE_NAME, preloadedUpdaters)
  end

  function Test.preparePTUpdate()
    local PTUpdaters = {
      function(data)
        data.policy_table.app_policies.default = TESTED_DATA.update.policy_table.app_policies.default
      end
    }
    updateJSON(ptuAppRegistered, PTUpdaters)
  end

  --[[ Preconditions ]]
  commonFunctions:newTestCasesGroup("Preconditions")

  function Test:Precondition_StopSDL()
    TestData:init(self)
    StopSDL()
  end

  function Test:Precondition_PreparePreloadedPT()
    commonSteps:DeleteLogsFileAndPolicyTable()
    TestData:store("Store initial PreloadedPT", config.pathToSDL .. PRELOADED_PT_FILE_NAME, "initial_" .. PRELOADED_PT_FILE_NAME)
    self.backupPreloadedPT("backup_")
    self:preparePreloadedPT()
    TestData:store("Store updated PreloadedPT", config.pathToSDL .. PRELOADED_PT_FILE_NAME, "updated_" .. PRELOADED_PT_FILE_NAME)
  end

  function Test:Precondition_PreparePTUfile()
    prepareJsonPTU(config.application1.registerAppInterfaceParams.fullAppID, ptuAppRegistered)
    self:preparePTUpdate()
    TestData:store("Store prepared PTU", ptuAppRegistered, "prepared_ptu.json" )
  end

  function Test:Precondition_StartSDL()
    StartSDL(config.pathToSDL, config.ExitOnCrash, self)
  end

  function Test:Precondition_InitHMI()
    self:initHMI()
  end

  function Test:Precondition_InitHMI_onReady()
    self:initHMI_onReady()
  end

  function Test:ConnectMobile()
    self:connectMobile()
  end

  function Test:StartMobileSession()
    self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
    self.mobileSession:StartService(7)
  end

  --[[ Test ]]
  commonFunctions:newTestCasesGroup("Test")

  function Test:RegisterApp()
    local correlationId = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)
    EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered")
    :Do(function(_,data)
        HMIAppId = data.params.application.appID
      end)
    EXPECT_RESPONSE(correlationId, { success = true })
    -- EXPECT_NOTIFICATION("OnPermissionsChange")
  end

  function Test:ActivateApp()
    EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
    activateApp(self, HMIAppId)
    TestData:store("Store LocalPT before PTU", constructPathToDatabase(), "beforePTU_policy.sqlite" )
  end

  function Test:UpdatePolicy_ExpectOnAppPermissionChangedWithAppID()
    -- ToDo (aderiabin): This function must be replaced by call
    -- testCasesForPolicyTable:updatePolicyInDifferentSessions(Test, ptuAppRegistered,
    -- config.application1.registerAppInterfaceParams.appName,
    -- self.mobileSession)
    -- after merge of pull request #227
    self:updatePolicyInDifferentSessions(ptuAppRegistered,
      config.application1.registerAppInterfaceParams.appName,
      self.mobileSession)
  end

  function Test:CheckPTUinLocalPT()
    os.execute("sleep 5")
    -- TestData:store("Store PT snapshot before its testing", realPathToSnapshot, CORRECT_LINUX_PATH_TO_POLICY_SNAPSHOT_FILE)
    -- if (not self:checkPtsFile()) or (not self:checkSdl()) then
    -- self:FailTestCase()
    -- end

    -- Check that that PTU correctly performed and omitted parameters were ignored
    TestData:store("Store LocalPT after PTU", constructPathToDatabase(), "afterPTU_policy.sqlite" )
    local checks = {
      {
        query = table.concat({'select request_type from request_type a where application_id = "', config.application1.registerAppInterfaceParams.fullAppID, '"'}),
        expectedValues = TESTED_DATA.update.policy_table.app_policies.default.RequestType
      }
    }
    if not self.checkLocalPT(checks) then
      self:FailTestCase("SDL has wrong values in LocalPT")
    end
  end

  --[[ Postconditions ]]
  commonFunctions:newTestCasesGroup("Postconditions")

  function Test:Postcondition()
    commonSteps:DeletePolicyTable()
    self.restorePreloadedPT("backup_")
    os.remove(ptuAppRegistered)
    TestData:info()
  end

  function Test:Postcondition_StopSDL()
    StopSDL(self)
  end

  return Test
