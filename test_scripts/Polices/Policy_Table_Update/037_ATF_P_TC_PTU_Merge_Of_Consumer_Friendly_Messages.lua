---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [PolicyTableUpdate] PTU merge into Local Policy Table (consumer_friendly_messages)
--
-- Description:
-- If the 'consumer_friendly_messages' section of PTU contains a 'messages' subsection,
-- SDL must replace the consumer_friendly_messages portion of the Local Policy Table with the same section from PTU.
--
-- Preconditions
-- 1. LPT has non empty 'consumer_friendly_messages'
-- 2. Register new app
-- 3. Activate app
-- Steps:
-- 1. Perform PTU with specific data in 'consumer_friendly_messages' section
-- 2. After PTU is finished verify consumer_friendly_messages.messages section in LPT
--
-- Expected result:
-- Previous version of consumer_friendly_messages.messages section in LPT has to be replaced by a new one.
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local mobileSession = require("mobile_session")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local testCasesForPolicyTable = require("user_modules/shared_testcases/testCasesForPolicyTable")

--[[ Local Variables ]]
--local db_file = config.pathToSDL .. "/" .. commonFunctions:read_parameter_from_smart_device_link_ini("AppStorageFolder") .. "/policy.sqlite"
local policy_file_path = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath")
local ServerAddress = commonFunctions:read_parameter_from_smart_device_link_ini("ServerAddress")
local ptu_file = "files/jsons/Policies/Policy_Table_Update/ptu_18192.json"

--[[ Local Functions ]]
local function is_table_equal(t1, t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  for k1, v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not is_table_equal(v1, v2) then return false end
  end
  for k2, v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not is_table_equal(v1, v2) then return false end
  end
  return true
end

-- local function execute_sqlite_query(file_db, query)
--   if not file_db then
--     return nil
--   end
--   local res = {}
--   local file = io.popen(table.concat({"sqlite3 ", file_db, " '", query, "'"}), 'r')
--   if file then
--     for line in file:lines() do
--       res[#res + 1] = line
--     end
--     file:close()
--     print("res")
--     return res
--   else
--     print("nil")
--     return nil
--   end
-- end

--[[ General Precondition before ATF start ]]
testCasesForPolicyTable:Precondition_updatePolicy_By_overwriting_preloaded_pt("files/jsons/Policies/Policy_Table_Update/preloaded_18192.json")
commonSteps:DeleteLogsFileAndPolicyTable()
testCasesForPolicyTable.Delete_Policy_table_snapshot()

--[[ General Settings for configuration ]]
Test = require("connecttest")
require("user_modules/AppTypes")

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test.Precondition_DeleteSnapshot()
  os.remove(policy_file_path .. "/sdl_snapshot.json")
end

function Test:Precondition_ActivateApp()
  local requestId1 = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications["Test Application"] })
  EXPECT_HMIRESPONSE(requestId1)
  :Do(function(_, data1)
      if data1.result.isSDLAllowed ~= true then
        local requestId2 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage",
          { language = "EN-US", messageCodes = { "DataConsent" } })
        EXPECT_HMIRESPONSE(requestId2)
        :Do(function(_, _)
            self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
              { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = ServerAddress } })
            EXPECT_HMICALL("BasicCommunication.ActivateApp")
            :Do(function(_, data2)
                self.hmiConnection:SendResponse(data2.id,"BasicCommunication.ActivateApp", "SUCCESS", { })
              end)
            :Times(1)
          end)
      end
    end)
end

function Test.Precondition_ValidateResultBeforePTU()
  EXPECT_ANY()
  :ValidIf(function(_, _)
      local r_expected = {
            "1|TTS1_AppPermissions|LABEL_AppPermissions|LINE1_AppPermissions|LINE2_AppPermissions|TEXTBODY_AppPermissions|en-us|AppPermissions",
            "2|||LINE1_DataConsent|LINE2_DataConsent|TEXTBODY_DataConsent|en-us|DataConsent" }
      local query = "select id, tts, label, line1, line2, textBody, language_code, message_type_name from message"
      --TODO: function is not working correctly. To be used common one
      --local r_actual = execute_sqlite_query(db_file, query)
      local r_actual = commonFunctions:get_data_policy_sql(config.pathToSDL.."/storage/policy.sqlite", query)
      if not is_table_equal(r_expected, r_actual) then
        return false, "\nExpected:\n" .. commonFunctions:convertTableToString(r_expected, 1) .. "\nActual:\n" .. commonFunctions:convertTableToString(r_actual, 1)
      end
      return true
    end)
  :Times(1)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")


function Test:TestStep_PTU_Up_To_Date()
  local policy_file_name = "PolicyTableUpdate"
  local requestId = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(requestId)
  :Do(function(_, _)
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest", { requestType = "PROPRIETARY", fileName = policy_file_name })
      EXPECT_NOTIFICATION("OnSystemRequest", { requestType = "PROPRIETARY" })
      :Do(function(_, _)
          local corIdSystemRequest = self.mobileSession:SendRPC("SystemRequest", { requestType = "PROPRIETARY", fileName = policy_file_name }, ptu_file)
          EXPECT_HMICALL("BasicCommunication.SystemRequest")
          :Do(function(_, data)
              self.hmiConnection:SendResponse(data.id, "BasicCommunication.SystemRequest", "SUCCESS", { })
              self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = policy_file_path .. "/" .. policy_file_name })
            end)
          EXPECT_RESPONSE(corIdSystemRequest, { success = true, resultCode = "SUCCESS" })
          :Do(function(_, _)
              requestId = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", { language = "EN-US", messageCodes = { "StatusUpToDate" } })
              EXPECT_HMIRESPONSE(requestId)
            end)
        end)
    end)
    EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
        {status = "UPDATING"}, {status = "UP_TO_DATE"}):Times(2)
end

function Test:StartNewMobileSession()
  self.mobileSession2 = mobileSession.MobileSession(self, self.mobileConnection)
  self.mobileSession2:StartService(7)
end

function Test:TestStep_RegisterNewApp()
  EXPECT_HMICALL("BasicCommunication.UpdateAppList")
  :Do(function(_, d)
      self.hmiConnection:SendResponse(d.id, d.method, "SUCCESS", { })
      self.applications = { }
      for _, app in pairs(d.params.applications) do
        self.applications[app.appName] = app.appID
      end
    end)
  local corId = self.mobileSession2:SendRPC("RegisterAppInterface", config.application2.registerAppInterfaceParams)
  self.mobileSession2:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
end

function Test.TestStep_ValidateResultAfterPTU()
  EXPECT_ANY()
  :ValidIf(function(_, _)
      local r_expected = { "1|TTS1|LABEL|LINE1|LINE2|TEXTBODY|en-us|AppPermissions", "2|TTS2|||||en-us|AppPermissionsHelp" }
      local query = "select id, tts, label, line1, line2, textBody, language_code, message_type_name from message"
      --TODO: function is not working correctly. To be used common one
      --local r_actual = execute_sqlite_query(db_file, query)
      local r_actual = commonFunctions:get_data_policy_sql(config.pathToSDL.."/storage/policy.sqlite", query)
      if not is_table_equal(r_expected, r_actual) then
        return false, "\nExpected:\n" .. commonFunctions:convertTableToString(r_expected, 1) .. "\nActual:\n" .. commonFunctions:convertTableToString(r_actual, 1)
      end
      return true
    end)
  :Times(1)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")
testCasesForPolicyTable:Restore_preloaded_pt()
function Test.Postcondition_StopSDL()
  StopSDL()
end

return Test