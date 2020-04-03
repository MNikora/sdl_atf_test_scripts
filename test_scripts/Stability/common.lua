---------------------------------------------------------------------------------------------------
-- Stability common module
---------------------------------------------------------------------------------------------------
local actions = require("user_modules/sequences/actions")
local utils = require('user_modules/utils')
local runner = require('user_modules/script_runner')
local SDL = require("SDL")
local ATF = require("ATF")
local commonSmoke = require('test_scripts/Smoke/commonSmoke')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
config.defaultProtocolVersion = 3

--[[ Module ]]
local common = {}
local appData = utils.cloneTable(actions.app.getParams(1))
local deviceData = { interface = nil, device = { }}

--[[ Proxy Functions ]]
common.Title = runner.Title
common.Step = runner.Step
common.preconditions = actions.preconditions
common.activateApp = actions.activateApp
common.registerApp = actions.app.register
common.policyTableUpdate = actions.ptu.policyTableUpdate
common.getConfigAppParams = actions.app.getParams
common.getMobileSession = actions.getMobileSession
common.getHMIConnection = actions.getHMIConnection
common.getHMIAppId = actions.getHMIAppId
common.runAfter = actions.run.runAfter
common.cloneTable = utils.cloneTable
common.delay = actions.run.wait
common.unregisterApp = actions.app.unRegister

--[[ Common Functions ]]
local function execCmd(pCmd)
  local handle = io.popen(pCmd)
  local result = handle:read("*a")
  handle:close()
  return string.gsub(result, "[\n\r]+", "")
end

local createSession_Orig = actions.mobile.createSession
function actions.mobile.createSession(pAppId, pMobConnId)
  local sessionConfig = {
    activateHeartbeat = false,
    sendHeartbeatToSDL = false,
    answerHeartbeatFromSDL = false,
    ignoreSDLHeartBeatACK = false
  }
  return createSession_Orig(pAppId, pMobConnId, sessionConfig)
end

local function setAppData(pAppId)
  config["application" .. pAppId] = { registerAppInterfaceParams = utils.cloneTable(appData) }
  config["application" .. pAppId].registerAppInterfaceParams.appName = "Test Application " .. pAppId
  config["application" .. pAppId].registerAppInterfaceParams.appID = "000 " .. pAppId
  config["application" .. pAppId].registerAppInterfaceParams.fullAppID = "000000 " .. pAppId
end
function common.registerApp(pAppId, pDeviceId)
  if not pAppId then pAppId = 1 end
  setAppData(pAppId)
  actions.app.register(pAppId, pDeviceId)
end

function common.registerNoPTU(pAppId, pDeviceId)
  if not pAppId then pAppId = 1 end
  setAppData(pAppId)
  actions.app.registerNoPTU(pAppId, pDeviceId)
end

function common.wait(msec, count, title)
  if count == nil then
    count = 1
  end
  if title == nil then
    title = 'Will Wait for '
  end
  print(title .. msec * count .. " ms")
  local wait_step = function()
    return actions.run.wait(msec)
  end
  local i = 0
  local step_waiting = function(post_func)
    if i < count then
      print("Wait iteration ".. i.. " for " .. msec .. " ms")
      wait_step():Do(function() post_func(post_func) end)
      i = i + 1
    end
  end
  step_waiting(step_waiting)
end

function common.IDLE(msec, count)
  common.wait(msec, count, "IDLE for ")
end

function common.collect_metrics(filename)
  local cmd = "bash ./tools/measure_sdl.sh " .. filename.."_stat"
  if config.remoteConnection.enabled == true then
    cmd = "cd .. && " .. cmd .. " --remote &"
    ATF.remoteUtils.app:ExecuteCommand(cmd)
  else
    os.execute(cmd .. " &")
  end
end

local function fsize(file)
  file = io.open(file,"r")
  local current = file:seek()      -- get current position
  local size = file:seek("end")    -- get file size
  file:seek("set", current)        -- restore position
  return size
end

function common.startVideoStreaming(pFile, pAppId, bandwith, wait)
  if wait == nil then wait = true end
  local function round(value)
    return math.floor(value + 0.5)
  end
  if not pAppId then pAppId = 1 end
  actions.mobile.getSession(pAppId):StartService(11)
  :Do(function()
      utils.cprint(33, "Bandwith : " .. bandwith/1000000 .. " mb/s")
      local filesize = fsize(pFile)
      utils.cprint(33, "File size : " .. round(filesize/1000/1000) .. " mb")
      local estimated_time = round(filesize/bandwith)
      utils.cprint(33, "Estimated time : " .. estimated_time .. " s")
      actions.getMobileSession(pAppId):StartStreaming(11, pFile, bandwith)
      actions.getHMIConnection():ExpectNotification("Navigation.OnVideoDataStreaming"):Times(AnyNumber())
      actions.hmi.getConnection():ExpectRequest("Navigation.StartStream", { appID = actions.app.getHMIId(pAppId) })
      :Do(function(_, data)
          actions.hmi.getConnection():SendResponse(data.id, data.method, "SUCCESS", { })
        end)
      utils.cprint(33, "Streaming...")
      if wait == true then
        common.wait(1000*10, estimated_time/10, "Wait for file streaming ")
      end
    end)
end

function common.stopVideoStreaming(pFile, pAppId)
  if not pAppId then pAppId = 1 end
  actions.mobile.getSession(pAppId):StopStreaming(pFile)
  utils.cprint(33, "App " .. pAppId .. " stops streaming")
  os.remove(pFile)
end

function common.start(filename)
  common.collect_metrics(filename)
  actions.init.SDL()
  :Do(function()
      actions.init.HMI()
      :Do(function()
          actions.init.HMI_onReady()
        end)
    end)
end

function common.connectMobile(pMobConnId)
  local event = actions.run.createEvent()
  actions.mobile.connect(pMobConnId)
  :Do(function()
      actions.mobile.allowSDL(pMobConnId)
      :Do(function()
          actions.hmi.getConnection():RaiseEvent(event, "Start event")
        end)
    end)
  return actions.hmi.getConnection():ExpectEvent(event, "Start event")
end

function common.connectMobileEx(pMobConnId)
  local function generateDeviceData(pId)
    local interface = execCmd("ip addr | grep " .. config.mobileHost ..  " | rev | awk '{print $1}' | rev")
    utils.cprint(35, "Interface:", interface)
    local device = string.match(config.mobileHost, ".+%.") .. 50 + pId
    utils.cprint(35, "IP-address:", device)
    deviceData.interface = interface
    deviceData.device[pId] = device
  end
  generateDeviceData(pMobConnId)

  local function addDevice(pId)
    if execCmd("ip addr | grep " .. deviceData.device[pId]) == "" then
      os.execute("ip addr add " .. deviceData.device[pId] .. "/24 dev " .. deviceData.interface)
    end
  end
  addDevice(pMobConnId)

  actions.mobile.connect = function(pId)
    return commonSmoke.createConnection(pId, deviceData.device[pId])
  end
  return common.connectMobile(pMobConnId)
end

function common.postconditions()
  actions.postconditions()
  local function removeDevice(pId)
    if execCmd("ip addr | grep " .. deviceData.device[pId]) ~= "" then
      os.execute("ip addr del " .. deviceData.device[pId] .. "/24 dev " .. deviceData.interface)
    end
  end
  for i = 1, 5 do
    if deviceData.device[i] then removeDevice(i) end
  end
  actions.run.wait(2000)
end

function common.ptuViaHMI()
  local function getPathAndName(pPathToFile)
    local pos = string.find(pPathToFile, "/[^/]*$")
    local path = string.sub(pPathToFile, 1, pos)
    local name = string.sub(pPathToFile, pos + 1)
    return path, name
  end
  local function getPTUFromPTS()
    local pTbl = actions.sdl.getPTS()
    if type(pTbl.policy_table) == "table" then
      pTbl.policy_table.consumer_friendly_messages = nil
      pTbl.policy_table.device_data = nil
      pTbl.policy_table.module_meta = nil
      pTbl.policy_table.usage_and_error_counts = nil
      pTbl.policy_table.functional_groupings["DataConsent-2"].rpcs = utils.json.null
      pTbl.policy_table.module_config.preloaded_pt = nil
      pTbl.policy_table.module_config.preloaded_date = nil
      pTbl.policy_table.vehicle_data = nil
    else
      utils.cprint(35, "PTU file has incorrect structure")
    end
    return pTbl
  end
  local ptuFileName = os.tmpname()
  local requestId = actions.hmi.getConnection():SendRequest("SDL.GetPolicyConfigurationData",
      { policyType = "module_config", property = "endpoints" })
  actions.hmi.getConnection():ExpectResponse(requestId)
  :Do(function()
      local ptuTable = getPTUFromPTS()
      for i, _ in pairs(actions.mobile.getApps()) do
        ptuTable.policy_table.app_policies[actions.app.getParams(i).fullAppID] = actions.ptu.getAppData(i)
      end
      utils.tableToJsonFile(ptuTable, ptuFileName)
      actions.hmi.getConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
      actions.hmi.getConnection():ExpectNotification("SDL.OnStatusUpdate", { status = "UP_TO_DATE" })
      if config.remoteConnection.enabled then
        local c = utils.readFile(ptuFileName)
        local p, n = getPathAndName(ptuFileName)
        ATF.remoteUtils.file:UpdateFileContent(p, n, c)
      end
      actions.hmi.getConnection():SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = ptuFileName })
      actions.run.runAfter(function() os.remove(ptuFileName) end, 250)
      for _, session in pairs(actions.mobile.getApps()) do
        session:ExpectNotification("OnPermissionsChange")
      end
    end)
end

function common.putFile(pRequestParams, pFilePath)
  local cid = actions.getMobileSession():SendRPC("PutFile", pRequestParams, pFilePath)
  actions.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  actions.run.wait(500)
end

function common.getPathToFileInAppStorage(pFileName)
  return SDL.AppStorage.path() .. common.getConfigAppParams().fullAppID .. "_"
    .. utils.getDeviceMAC() .. "/" .. pFileName
end

return common
