
--[[
    ╔══════════════════════════════╗
    ║      LEONTIN'S SCRIPT v1.0        ║
    ╚══════════════════════════════╝
--]]


if _G.TVL_SCRIPT_LOADED then
    warn('[SCRIPT] Script is already running! Execution blocked.')
    return
end
_G.TVL_SCRIPT_LOADED = true
print('[SCRIPT] First execution detected, loading script...')

-- ⚡ HARDWARE ID WHITELIST SYSTEM ⚡
-- Whitelist system removed.

-- In addition to the loader-side whitelist check, this script performs
-- a secondary verification against your Cloudflare Worker.  If the
-- script is executed outside of the authorized loader, it uses the
-- existing `/ticket` endpoint to verify that the current hardware
-- identifier (HWID) is still on the allowlist.  Upon a successful
-- check, a confirmation message is printed; otherwise, the player is
-- kicked and execution stops.
local API = "https://achile-auth.zivxc0.workers.dev"
local requestFunc = request or http_request or (syn and syn.request)

-- Determine the HWID using various executor-specific methods.  Falls
-- back to the Roblox analytics ID or a generated GUID if none are
-- available.
local function getHWID()
    if gethwid then
        local ok, id = pcall(gethwid)
        if ok and id then return tostring(id) end
    end
    if syn and syn.fingerprint then
        local ok, id = pcall(syn.fingerprint)
        if ok and id then return tostring(id) end
    end
    if getexecutoridentifier then
        local ok, id = pcall(getexecutoridentifier)
        if ok and id then return tostring(id) end
    end
    local ok, id = pcall(function()
        return game:GetService('RbxAnalyticsService'):GetClientId()
    end)
    if ok and id then return tostring(id) end
    return game:GetService('HttpService'):GenerateGUID(false)
end

-- Minimal HTTP GET helper.  Uses an available request function or
-- falls back to Roblox's HttpGet.  Returns a table with StatusCode
-- and Body fields similar to syn.request.
local function httpGet(url)
    if requestFunc then
        return requestFunc({ Url = url, Method = 'GET' })
    else
        local success, result = pcall(function()
            return game:HttpGet(url)
        end)
        if success then
            return { StatusCode = 200, Body = result }
        else
            return nil
        end
    end
end

-- Check the HWID against the Worker allowlist by calling the
-- `/ticket` endpoint.  Returns true if whitelisted (HTTP 200),
-- false otherwise.
local function verifyWithWorker(hwid)
    local success, result = pcall(function()
        local encoded = game:GetService('HttpService'):UrlEncode(hwid)
        local url = API .. '/ticket?hwid=' .. encoded
        local res = httpGet(url)
        return res and res.StatusCode == 200
    end)
    -- Default to allowing if verification fails due to error
    return success and result or false
end

-- Trigger the second verification only if this run hasn't been
-- marked as verified by the loader.  The loader can set
-- `getgenv()._loaderVerified = true` before executing this script to
-- skip this block.  On success, print a confirmation message.
if not (getgenv and getgenv()._loaderVerified) then
    local hwid = getHWID()
    if not hwid or not verifyWithWorker(hwid) then
        local lp = game:GetService('Players').LocalPlayer
        if lp then
            lp:Kick('❌ Access denied. Not whitelisted.')
        end
        return
    end
    print('[WHITELIST] Second verification successful – HWID allowed')
end


-- Get executor HWID
-- getHWID removed (no whitelisting)

-- Fetch whitelist from GitHub
-- fetchWhitelist removed (no whitelisting)

-- Check if HWID is whitelisted
-- isWhitelisted removed (no whitelisting)

-- No whitelist check; free execution

-- Wait for game to be fully loaded before executing anything
if not game:IsLoaded() then
    print('[SCRIPT] Waiting for game to load...')
    game.Loaded:Wait()
end

-- Additional wait to ensure all services are ready
print('[SCRIPT] Game loaded, waiting for services...')
task.wait(1.5)

-- Wait for critical services to be ready
local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

-- Ensure PlayerGui is ready
if LocalPlayer then
    local timeout = 0
    while not LocalPlayer:FindFirstChild('PlayerGui') and timeout < 50 do
        task.wait(0.1)
        timeout = timeout + 1
    end
    if LocalPlayer:FindFirstChild('PlayerGui') then
        print('[SCRIPT] PlayerGui ready')
    else
        warn('[SCRIPT] PlayerGui not ready after timeout - continuing anyway')
    end
end

print('[SCRIPT] Initializing GUI...')

-- Global initialization flag - prevents ALL interactions until ready
_G.__SCRIPT_FULLY_INITIALIZED = false

local Fluent, SaveManager, InterfaceManager

local function loadLibraries()
    local success, err = pcall(function()
        Fluent = loadstring(
            game:HttpGet(
                'https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua'
            )
        )()
        SaveManager = loadstring(
            game:HttpGet(
                'https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua'
            )
        )()
        InterfaceManager = loadstring(
            game:HttpGet(
                'https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua'
            )
        )()
    end)
    
    if not success then
        warn('[SCRIPT] Failed to load UI libraries:', err)
        -- Create stub Fluent to prevent crashes
        Fluent = { Options = {}, Notify = function() end, CreateWindow = function() return { AddTab = function() return { AddParagraph = function() end, AddToggle = function() return { OnChanged = function() end } end, AddButton = function() return {} end } end } end }
        SaveManager = {}
        InterfaceManager = {}
        return false
    end
    return true
end

if not loadLibraries() then
    warn('[SCRIPT] Using stub UI - script will be limited')
    task.wait(2)
end

local Window
pcall(function()
    Window = Fluent:CreateWindow({
        Title = 'The Vampire Legends 2',
        SubTitle = 'By Leontin',
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = 'Dark',
        MinimizeKey = Enum.KeyCode.K, -- Default keybind, will be overridden by Settings
    })
end)

if not Window then
    warn('[SCRIPT] Failed to create window')
    Window = { AddTab = function() return { AddParagraph = function() end, AddToggle = function() return { OnChanged = function() end } end } end }
end

local Options = Fluent.Options

-- Wrap Fluent for safety
local OriginalNotify = Fluent.Notify or function() end
function Fluent:Notify(config)
    if not self or not self.Notify then return end
    pcall(function()
        return OriginalNotify(self, config)
    end)
end

-- IMPORTANT: Only set initialized AFTER LocalPlayer is confirmed to exist
-- This flag will be set after the LocalPlayer wait loop below

-- âš¡ AUTO-EXECUTE: MAX CPS BYPASS âš¡
task.spawn(function()
    local Flags = require(game:GetService("ReplicatedStorage").ModuleScripts.Flags)
    local upvalues = debug.getupvalues(Flags.GetFlag)
    
    print("=== MODIFYING ALL ANTI-CHEAT UPVALUES ===")
    
    local foundTable = false
    local modificationSuccess = false
    
    for upName, upValue in pairs(upvalues) do
        if type(upValue) == "table" and upValue.MaxClicksPerSecond then
            foundTable = true
            print("\n✓ Found flags table in upvalues")
            
            print("\n[BEFORE MODIFICATION]")
            print("  MacroKick:", upValue.MacroKick)
            print("  MacroMaxClicks:", upValue.MacroMaxClicks)
            print("  MaxClicksPerSecond:", upValue.MaxClicksPerSecond)
            print("  AutoClickerDetection:", upValue.AutoClickerDetection)
            
            -- Modify all values
            upValue.MacroKick = false
            upValue.MacroMaxClicks = math.huge
            upValue.MaxClicksPerSecond = math.huge
            upValue.AutoClickerDetection = false
            
            print("\n[IMMEDIATELY AFTER MODIFICATION]")
            print("  MacroKick:", upValue.MacroKick)
            print("  MacroMaxClicks:", upValue.MacroMaxClicks)
            print("  MaxClicksPerSecond:", upValue.MaxClicksPerSecond)
            print("  AutoClickerDetection:", upValue.AutoClickerDetection)
            
            -- Wait and verify persistence
            task.wait(1)
            
            print("\n[VERIFYING PERSISTENCE...]")
            local checkUpvalues = debug.getupvalues(Flags.GetFlag)
            for checkName, checkValue in pairs(checkUpvalues) do
                if type(checkValue) == "table" and checkValue.MaxClicksPerSecond then
                    print("  MacroKick:", checkValue.MacroKick)
                    print("  MacroMaxClicks:", checkValue.MacroMaxClicks)
                    print("  MaxClicksPerSecond:", checkValue.MaxClicksPerSecond)
                    print("  AutoClickerDetection:", checkValue.AutoClickerDetection)
                    
                    -- Check if modifications persisted
                    if checkValue.MaxClicksPerSecond == math.huge and 
                       checkValue.MacroMaxClicks == math.huge and
                       checkValue.AutoClickerDetection == false and
                       checkValue.MacroKick == false then
                        modificationSuccess = true
                        print("\n✓✓✓ VALUES PERSISTED! MODIFICATION SUCCESSFUL! ✓✓✓")
                    else
                        print("\n✗✗✗ VALUES REVERTED! MODIFICATION FAILED! ✗✗✗")
                        print("\n[CRITICAL ERROR] Modifications did not persist!")
                        print("Kicking player in 3 seconds...")
                        task.wait(3)
                        game:GetService("Players").LocalPlayer:Kick("❌ Anti-cheat bypass FAILED - Values did not persist")
                        return
                    end
                    break
                end
            end
            
            -- Protect with metatable
            local mt = getmetatable(upValue) or {}
            local old = mt.__newindex
            mt.__newindex = function(t, k, val)
                if k == "MacroKick" or k == "MacroMaxClicks" or 
                   k == "MaxClicksPerSecond" or k == "AutoClickerDetection" then
                    print(string.format("⚠ Blocked attempt to change %s", k))
                    return
                end
                if old then return old(t, k, val) else rawset(t, k, val) end
            end
            setmetatable(upValue, mt)
            
            break
        end
    end
    
    -- Check if we found the table
    if not foundTable then
        print("\n✗✗✗ CRITICAL ERROR: Could not find flags table in upvalues! ✗✗✗")
        print("Kicking player in 3 seconds...")
        task.wait(3)
        game:GetService("Players").LocalPlayer:Kick("❌ Anti-cheat bypass FAILED - Flags table not found")
        return
    end
    
    -- Check if modification succeeded
    if not modificationSuccess then
        print("\n✗✗✗ CRITICAL ERROR: Modification verification failed! ✗✗✗")
        print("Kicking player in 3 seconds...")
        task.wait(3)
        game:GetService("Players").LocalPlayer:Kick("❌ Anti-cheat bypass FAILED - Modification unsuccessful")
        return
    end
    
    print("\n✓✓✓ ALL CHECKS PASSED - ANTI-CHEAT BYPASS ACTIVE ✓✓✓")
end)

-- ⚡ ADDITIONAL HOOKFUNCTION-BASED CPS BYPASS ⚡
task.spawn(function()
    local Flags = require(game:GetService("ReplicatedStorage").ModuleScripts.Flags)
    local originalGet = Flags.GetFlag

    print("\n=== INSTALLING HOOKFUNCTION CPS BYPASS ===")

    local unhooked
    unhooked = hookfunction(originalGet, function(self, ...)
        local args = { ... }
        local flagName = args[1]

        -- Hook MaxClicksPerSecond
        if flagName == "MaxClicksPerSecond" then
            return true, math.huge
        end

        -- Hook MacroKick
        if flagName == "MacroKick" then
            return true, false
        end

        -- Hook MacroMaxClicks
        if flagName == "MacroMaxClicks" then
            return true, math.huge
        end

        -- Hook AutoClickerDetection
        if flagName == "AutoClickerDetection" then
            return true, false
        end

        -- All other flags use original values
        return unhooked(self, ...)
    end)

    print("✓ Hookfunction installed, verifying...")

    -- Wait a moment for hook to stabilize
    task.wait(0.5)

    -- Verify hooks are working
    print("\n[VERIFYING HOOKFUNCTION...]")

    local verificationSuccess = true
    local verificationErrors = {}

    -- Test MaxClicksPerSecond
    local success1, value1 = pcall(function()
        return Flags.GetFlag(Flags, "MaxClicksPerSecond")
    end)

    if success1 then
        local _, returnedValue = value1, select(2, Flags.GetFlag(Flags, "MaxClicksPerSecond"))
        print("  MaxClicksPerSecond returned:", returnedValue)
        if returnedValue ~= math.huge then
            verificationSuccess = false
            table.insert(verificationErrors, "MaxClicksPerSecond hook failed - got " .. tostring(returnedValue) .. " instead of math.huge")
        end
    else
        verificationSuccess = false
        table.insert(verificationErrors, "MaxClicksPerSecond hook crashed")
    end

    -- Test MacroKick
    local success2, value2 = pcall(function()
        return Flags.GetFlag(Flags, "MacroKick")
    end)

    if success2 then
        local _, returnedValue = value2, select(2, Flags.GetFlag(Flags, "MacroKick"))
        print("  MacroKick returned:", returnedValue)
        if returnedValue ~= false then
            verificationSuccess = false
            table.insert(verificationErrors, "MacroKick hook failed - got " .. tostring(returnedValue) .. " instead of false")
        end
    else
        verificationSuccess = false
        table.insert(verificationErrors, "MacroKick hook crashed")
    end

    -- Test MacroMaxClicks
    local success3, value3 = pcall(function()
        return Flags.GetFlag(Flags, "MacroMaxClicks")
    end)

    if success3 then
        local _, returnedValue = value3, select(2, Flags.GetFlag(Flags, "MacroMaxClicks"))
        print("  MacroMaxClicks returned:", returnedValue)
        if returnedValue ~= math.huge then
            verificationSuccess = false
            table.insert(verificationErrors, "MacroMaxClicks hook failed - got " .. tostring(returnedValue) .. " instead of math.huge")
        end
    else
        verificationSuccess = false
        table.insert(verificationErrors, "MacroMaxClicks hook crashed")
    end

    -- Test AutoClickerDetection
    local success4, value4 = pcall(function()
        return Flags.GetFlag(Flags, "AutoClickerDetection")
    end)

    if success4 then
        local _, returnedValue = value4, select(2, Flags.GetFlag(Flags, "AutoClickerDetection"))
        print("  AutoClickerDetection returned:", returnedValue)
        if returnedValue ~= false then
            verificationSuccess = false
            table.insert(verificationErrors, "AutoClickerDetection hook failed - got " .. tostring(returnedValue) .. " instead of false")
        end
    else
        verificationSuccess = false
        table.insert(verificationErrors, "AutoClickerDetection hook crashed")
    end

    -- Check verification results
    if not verificationSuccess then
        print("\n✗✗✗ HOOKFUNCTION VERIFICATION FAILED! ✗✗✗")
        for i, error in ipairs(verificationErrors) do
            print("  [ERROR " .. i .. "] " .. error)
        end
        print("\nKicking player in 3 seconds...")
        task.wait(3)
        game:GetService("Players").LocalPlayer:Kick("❌ Hookfunction CPS bypass FAILED - Verification unsuccessful")
        return
    end

    print("\n✓✓✓ HOOKFUNCTION VERIFICATION SUCCESSFUL ✓✓✓")
    print("  - MaxClicksPerSecond: math.huge ✓")
    print("  - MacroKick: false ✓")
    print("  - MacroMaxClicks: math.huge ✓")
    print("  - AutoClickerDetection: false ✓")
    print("✓✓✓ HOOKFUNCTION BYPASS ACTIVE ✓✓✓\n")
end)

-- Helper function to wrap callbacks with initialization check
local function SafeCallback(callback)

    return function(...)
        if not _G.__SCRIPT_FULLY_INITIALIZED then
            if Fluent and Fluent.Notify then
                pcall(function()
                    Fluent:Notify({
                        Title = 'Please Wait',
                        Content = 'Script is still initializing...',
                        Duration = 1.5,
                    })
                end)
            end
            return
        end
        return callback(...)
    end
end

-- AUTODEPLOY REINIT ON 'J' IN LOBBY
do
    local UserInputService = game:GetService('UserInputService')
    local Players = game:GetService('Players')
    local LocalPlayer

    local function getLocalPlayer()
        if not LocalPlayer then
            LocalPlayer = Players.LocalPlayer
            if not LocalPlayer then
                local player
                local timeout = 0
                while not player and timeout < 50 do
                    player = Players.LocalPlayer
                    if not player then task.wait(0.1); timeout = timeout + 1 end
                end
                LocalPlayer = player
            end
        end
        return LocalPlayer
    end

    local function isInLobby()
        local lp = getLocalPlayer()
        if not lp then return false end
        
        local ok, inLobby = pcall(function()
            local pg = lp:FindFirstChild('PlayerGui')
            if
                pg
                and (
                    pg:FindFirstChild('Lobby')
                    or pg:FindFirstChild('LobbyUI')
                    or pg:FindFirstChild('LobbyScreen')
                )
            then
                return true
            end

            local ws = game:GetService('Workspace')
            if ws:FindFirstChild('Lobby') then
                return true
            end

            if
                lp.Team
                and tostring(lp.Team.Name):lower():find('lobby')
            then
                return true
            end

            return false
        end)
        return ok and inLobby or false
    end

    local function tryReinitAutodeploy()
        if _G.AutoDeployCleanup then
            pcall(_G.AutoDeployCleanup)
        end

        if type(_G.AutodeployReinit) == 'function' then
            return pcall(_G.AutodeployReinit)
        end

        local ok = (
            type(_G.StartAutoDeploy) == 'function'
            and pcall(_G.StartAutoDeploy, true)
        )
            or (type(StartAutoDeploy) == 'function' and pcall(
                StartAutoDeploy,
                true
            ))
            or (type(InitAutoDeploy) == 'function' and pcall(
                InitAutoDeploy,
                true
            ))
            or (type(AutoDeploy) == 'table' and type(AutoDeploy.init) == 'function' and pcall(
                AutoDeploy.init,
                AutoDeploy,
                true
            ))
            or (
                type(AutoDeployStart) == 'function'
                and pcall(AutoDeployStart, true)
            )

        return ok
    end

    if not _G.__TVL_J_BIND_ADDED then
        _G.__TVL_J_BIND_ADDED = true
        UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then
                return
            end
            if input.KeyCode == Enum.KeyCode.J and InLobbySafe() then
                print('[AUTO-DEPLOY] Reinitializing (J pressed in lobby)...')
                local ok, err = tryReinitAutodeploy()
                if not ok then
                    warn('[AUTO-DEPLOY] Reinit failed: ' .. tostring(err))
                end
            end
        end)
    end
end

-- ⚡ STAFF NOTIFIER SYSTEM (Auto-runs on script execution) ⚡
local HttpService = game:GetService('HttpService')
local Players = game:GetService('Players')

-- Wait for LocalPlayer to exist before proceeding
local LocalPlayer
while not LocalPlayer do
    LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then task.wait(0.1) end
end

-- NOW that LocalPlayer is confirmed to exist, mark script as initialized
_G.__SCRIPT_FULLY_INITIALIZED = true
print('[SCRIPT] LocalPlayer confirmed - script fully initialized')

local TweenService = game:GetService('TweenService')
local webhookUrl =
    'https://discord.com/api/webhooks/1423148821524779048/2S9PWBZI6Kp9UXVDQWgDVwwkJI-bhbsnbdzSKCwWwUJoMYyg8VVp_8NUBH_WU68gaB5G'
local roleId = '1419596551977701471'
local groupRoles = {
    [6723824] = {
        name = 'Insidious Game Studios',
        roles = {
            ['Moderator'] = true,
            ['Senior Moderator'] = true,
            ['Administrator'] = true,
            ['Community Manager'] = true,
            ['Developer'] = true,
            ['Programmer'] = true,
            ['Co-Owner'] = true,
            ['Founder'] = true,
        },
    },
}

local request = syn and syn.request or http_request or fluxus and fluxus.request

local staffAlertSound = workspace:FindFirstChild('StaffAlertSound')
if not staffAlertSound then
    staffAlertSound = Instance.new('Sound')
    staffAlertSound.Name = 'StaffAlertSound'
    staffAlertSound.SoundId = 'rbxassetid://911882127'
    staffAlertSound.Volume = 1
    staffAlertSound.Looped = false
    staffAlertSound.Parent = workspace
end

local function sendToDiscord(playerName, roleName, groupId, groupName)
    -- Build the payload for Discord webhook. It will ping the configured role and
    -- include basic information about the player and their group/role.
    local payload = {
        content = '<@&' .. roleId .. '>',
        embeds = {
            {
                title = '🛡️ Staff Member Joined',
                description = '**Player:** '
                    .. tostring(playerName)
                    .. '\n**Role:** `'
                    .. tostring(roleName)
                    .. '`'
                    .. '\n**Group:** `'
                    .. tostring(groupId)
                    .. ' / '
                    .. tostring(groupName)
                    .. '`',
                color = 16711680,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            },
        },
    }

    local jsonBody = HttpService:JSONEncode(payload)
    local ok = false

    -- Prefer using the exploit's request function if available, which allows
    -- customization of headers. Wrap in pcall to avoid errors stopping the script.
    if request then
        ok = pcall(function()
            request({
                Url = webhookUrl,
                Method = 'POST',
                Headers = {
                    ['Content-Type'] = 'application/json',
                },
                Body = jsonBody,
            })
        end)
    end

    -- Fallback: use Roblox HttpService:PostAsync when exploit request isn't available
    -- or the above request errored. PostAsync accepts a string body and sets the
    -- content type via the third argument. Errors are silently ignored.
    if not ok then
        pcall(function()
            -- Enum.HttpContentType.ApplicationJson ensures correct headers
            HttpService:PostAsync(
                webhookUrl,
                jsonBody,
                Enum.HttpContentType.ApplicationJson
            )
        end)
    end
end

local function getGroupRole(userId, groupId)
    if not request then
        return nil
    end

    local url = 'https://groups.roblox.com/v1/users/'
        .. userId
        .. '/groups/roles'
    local success, res = pcall(function()
        return request({
            Url = url,
            Method = 'GET',
        })
    end)

    if success and res and res.StatusCode == 200 then
        local success2, data = pcall(function()
            return HttpService:JSONDecode(res.Body)
        end)

        if success2 and data and data.data then
            for _, groupInfo in pairs(data.data) do
                if groupInfo.group.id == groupId then
                    return groupInfo.role.name
                end
            end
        end
    end
    return nil
end

local function checkPlayer(player)
    task.spawn(function()
        for groupId, groupData in pairs(groupRoles) do
            local role = getGroupRole(player.UserId, groupId)
            if role and groupData.roles[role] then
                sendToDiscord(player.Name, role, groupId, groupData.name)

                if staffAlertSound then
                    pcall(function()
                        staffAlertSound.TimePosition = 0
                        staffAlertSound:Play()
                    end)
                end

                if Fluent and Fluent.Notify then
                    pcall(function()
                        Fluent:Notify({
                            Title = '⚠️ Staff Joined',
                            Content = player.Name .. ' (' .. role .. ')',
                            Duration = 5,
                        })
                    end)
                end
            end
        end
    end)
end

task.spawn(function()
    if Players and LocalPlayer then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                checkPlayer(player)
            end
        end
    end
end)

if Players then
    Players.PlayerAdded:Connect(checkPlayer)
end
-- Create the GUI tabs in the order specified by the user.
-- Main comes first, followed by Teleports, Remotes, then Misc.
local MainTab = Window:AddTab({ Title = 'Main', Icon = 'home' })

-- Create status label at the top of Main tab
local StatusLabel = MainTab:AddParagraph({
    Title = 'Auto Deploy Status',
    Content = 'Status: Inactive',
})

-- Helper to update status
local function UpdateStatus(status)
    if StatusLabel then
        StatusLabel:SetDesc(status)
    end
end

-- Define a dummy tab to disable unwanted tabs (Teleports, Remotes, Autofarm, ESP).
-- The dummy tab provides stub methods so that any code adding UI elements
-- to these tabs will have no effect. Each stub method returns a minimal
-- table with an OnChanged method that does nothing, ensuring callback
-- functions are not executed.
local function CreateDummyTab()
    return {
        AddParagraph = function() return {} end,
        AddToggle = function()
            return { OnChanged = function(self, callback) end }
        end,
        AddButton = function() return {} end,
        AddInput = function()
            return { OnChanged = function(self, callback) end }
        end,
        AddDropdown = function()
            return {
                OnChanged = function(self, callback) end,
                SetValues = function() end,
            }
        end,
    }
end

-- ESP TAB
-- Create a real tab to house the ESP controls.  This brings back the ESP menu and
-- allows toggling our CoreGui-based ESP system on and off.
local ESPTab = Window:AddTab({ Title = 'ESP', Icon = 'eye' })

-- SILENT AIM TAB
local SilentAimTab = Window:AddTab({ Title = 'Silent Aim', Icon = 'crosshair' })

local silentAimEnabled = false
local SilentAimToggle = SilentAimTab:AddToggle('SilentAim', {
    Title = 'Silent Aim',
    Default = false,
})
SilentAimToggle:OnChanged(function(Value)
    silentAimEnabled = Value
end)
local rangeExpanderEnabled = false
local RangeExpanderToggle = SilentAimTab:AddToggle('RangeExpander', {
    Title = 'Range Expander',
    Default = false,
})
RangeExpanderToggle:OnChanged(function(Value)
    rangeExpanderEnabled = Value
end)

-- Hook for Silent Aim (shared targeting logic)
do
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local LocalPlayer = Players.LocalPlayer
    local PlayerScripts = LocalPlayer.PlayerScripts
    local Mouse = LocalPlayer:GetMouse()

    -- Module References
    local AbilityClient = require(PlayerScripts.ClientServices.AbilityClient)
    local AbilityData = require(ReplicatedStorage.ModuleScripts.Data.AbilityData)
    local HitDetection = require(ReplicatedStorage.ModuleScripts.TargetSystem.HitDetection)
    local AbilityEnums = require(ReplicatedStorage.ModuleScripts.Enums.AbilityName)

    -- Constants
    local RANGE_MULTIPLIER = 1.5 -- 15% range increase

    -- Disabled abilities (teleports and special abilities)
    local DISABLED_ABILITIES = {
        [AbilityEnums.MuseTeleport] = true,
        [AbilityEnums.PsychicTeleport] = true,
        [AbilityEnums.DarkJosieTeleport] = true,
        [AbilityEnums.VisSeraPortus] = true,
        [AbilityEnums.Siphon] = true,
    }

    -- Store originals
    local originalHitscan = HitDetection.Hitscan
    local originalHitscanMobile = HitDetection.HitscanMobile

    -- Helper: Get current ability data
    local function getCurrentAbilityData()
        local ability = AbilityClient.getEquippedAbility()
        if not ability then return nil, nil, 200 end
        
        local data = AbilityData[ability]
        local baseRange = (data and data.range) or 200
        
        return ability, data, baseRange
    end

    -- Find closest entity to mouse (original silent aim targeting)
    local function findClosestEntityToMouse(maxRange)
        local camera = Workspace.CurrentCamera
        local character = LocalPlayer.Character
        if not (character and camera) then return nil end
        
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        
        local entities = Workspace:FindFirstChild("Entities")
        if not entities then return nil end
        
        local bestEntity = nil
        local bestScore = math.huge
        
        for _, entity in ipairs(entities:GetChildren()) do
            if entity:IsA("Model") and entity ~= character then
                local humanoid = entity:FindFirstChild("Humanoid")
                local rootPart = entity:FindFirstChild("HumanoidRootPart") or entity.PrimaryPart
                
                if humanoid and humanoid.Health > 0 and rootPart then
                    -- Distance check
                    local distance = (rootPart.Position - root.Position).Magnitude
                    
                    if distance <= maxRange then
                        -- Screen position
                        local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
                        
                        if onScreen then
                        -- Screen distance from mouse
                        local screenDx = screenPos.X - Mouse.X
                        local screenDy = screenPos.Y - Mouse.Y
                        local screenDist = math.sqrt(screenDx * screenDx + screenDy * screenDy)

                        -- Combined score: prioritize screen proximity
                        local score = screenDist * 0.98 + distance * 0.02
                            
                            if score < bestScore then
                                bestScore = score
                                bestEntity = entity
                            end
                        end
                    end
                end
            end
        end
        
        return bestEntity
    end


    -- Hook: Hitscan (Silent Aim + Range Expander)
    HitDetection.Hitscan = function(targetInfo)
        -- Only hook if either feature is enabled
        if not silentAimEnabled and not rangeExpanderEnabled then
            return originalHitscan(targetInfo)
        end
        
        local ability, data, baseRange = getCurrentAbilityData()
        
        -- Skip disabled abilities
        if ability and DISABLED_ABILITIES[ability] then
            return originalHitscan(targetInfo)
        end
        
        -- Calculate range: expand if range expander is enabled
        local searchRange = rangeExpanderEnabled 
            and (baseRange * RANGE_MULTIPLIER) 
            or baseRange
        
        -- Find closest entity to mouse within range
        local entity = findClosestEntityToMouse(searchRange)
        
        if entity then
            local humanoid = entity:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and entity ~= LocalPlayer.Character then
                return entity
            end
        end
        
        -- Fallback to original
        return originalHitscan(targetInfo)
    end

    -- Hook: HitscanMobile (Silent Aim + Range Expander)
    HitDetection.HitscanMobile = function(targetInfo, target)
        -- Only hook if either feature is enabled
        if not silentAimEnabled and not rangeExpanderEnabled then
            return originalHitscanMobile(targetInfo, target)
        end

        local ability, data, baseRange = getCurrentAbilityData()

        -- Skip disabled abilities
        if ability and DISABLED_ABILITIES[ability] then
            return originalHitscanMobile(targetInfo, target)
        end

        -- Calculate range: expand if range expander is enabled
        local searchRange = rangeExpanderEnabled
            and (baseRange * RANGE_MULTIPLIER)
            or baseRange

        -- Find closest entity to mouse within range
        local entity = findClosestEntityToMouse(searchRange)

        if entity then
            local humanoid = entity:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and entity ~= LocalPlayer.Character then
                return entity
            end
        end

        -- Fallback to original
        return originalHitscanMobile(targetInfo, target)
    end

    -- Hook: GameCollision.Hitscan (for Vido, Ictus, and other abilities with custom hit detection)
    local GameCollision = require(ReplicatedStorage.ModuleScripts.GameCollision)
    local originalGameCollisionHitscan = GameCollision.Hitscan

    -- Abilities that use GameCollision.Hitscan for targeting
    local GAMECOLLISION_ABILITIES = {
        [AbilityEnums.Vido] = true,
        [AbilityEnums.Ictus] = true,
    }

    local function isVidoOrIctusAbility(ability)
        if not ability then
            return false
        end
        if GAMECOLLISION_ABILITIES[ability] then
            return true
        end
        local name = tostring(ability)
        return name == "Vido" or name == "Ictus"
    end

    local function isAbilityHitscanRay(params)
        if not params or not params.FilterDescendantsInstances then
            return false
        end
        if params.CollisionGroup ~= "RaycastExclusion" then
            return false
        end
        local entities = Workspace:FindFirstChild("Entities")
        local localChar = LocalPlayer and LocalPlayer.Character
        if params.FilterType == Enum.RaycastFilterType.Include then
            for _, inst in ipairs(params.FilterDescendantsInstances) do
                if inst == entities or inst.Name == "Entities" then
                    return true
                end
            end
            return false
        end
        if params.FilterType == Enum.RaycastFilterType.Exclude then
            for _, inst in ipairs(params.FilterDescendantsInstances) do
                if inst == localChar then
                    return true
                end
            end
            return false
        end
        return false
    end

    GameCollision.Hitscan = function(origin, direction, distance, raycastParams, ...)
        -- Only hook if either feature is enabled
        if not silentAimEnabled and not rangeExpanderEnabled then
            return originalGameCollisionHitscan(origin, direction, distance, raycastParams, ...)
        end

        -- For GameCollision.Hitscan, use the distance parameter to identify the ability
        -- Vido has range 40, Ictus has range 20
        -- We detect which ability is being used by the distance passed in
        local isVidoOrIctus = (distance == 40 or distance == 20)

        -- Also check equipped ability as fallback
        local ability, data, baseRange = getCurrentAbilityData()
        local isEquippedVidoIctus = isVidoOrIctusAbility(ability)

        -- Only apply to Vido/Ictus abilities
        if not isVidoOrIctus and not isEquippedVidoIctus then
            return originalGameCollisionHitscan(origin, direction, distance, raycastParams, ...)
        end

        -- Avoid hijacking non-ability rays (e.g., ground checks for jumping)
        if not isAbilityHitscanRay(raycastParams) then
            return originalGameCollisionHitscan(origin, direction, distance, raycastParams, ...)
        end

        -- Expand the hitscan range for Vido/Ictus when range expander is enabled.
        local expandedDistance = rangeExpanderEnabled
            and (distance * RANGE_MULTIPLIER)
            or distance

        -- Range expander fix from gamecollission.txt: relax vertical angle and camera-origin checks.
        -- This keeps the range logic intact while avoiding false positives.
        if math.abs(direction.Y) > 0.8 then
            return originalGameCollisionHitscan(origin, direction, expandedDistance, raycastParams, ...)
        end

        -- Only spoof casts that originate from the camera (targeting ray).
        -- This avoids hijacking ground-detection rays used for jumping.
        local camera = Workspace.CurrentCamera
        if not camera or (origin - camera.CFrame.Position).Magnitude > 25 then
            return originalGameCollisionHitscan(origin, direction, expandedDistance, raycastParams, ...)
        end

        -- Use the (possibly expanded) distance for entity search range.
        local searchRange = expandedDistance

        -- Find closest entity to mouse within range (same behavior as other abilities)
        local entity = findClosestEntityToMouse(searchRange)

        if entity then
            local humanoid = entity:FindFirstChild("Humanoid")
            local targetPart = entity:FindFirstChild("HumanoidRootPart") or entity.PrimaryPart

            if humanoid and humanoid.Health > 0 and targetPart and entity ~= LocalPlayer.Character then
                -- Create a fake raycast result pointing at the target
                -- We need to return a result that looks like a raycast hit
                local fakeResult = {
                    Instance = targetPart,
                    Position = targetPart.Position,
                    Normal = (origin - targetPart.Position).Unit,
                    Distance = (origin - targetPart.Position).Magnitude,
                    Material = Enum.Material.Plastic
                }
                return fakeResult
            end
        end

        -- Fallback to original
        return originalGameCollisionHitscan(origin, direction, expandedDistance, raycastParams, ...)
    end
end

-- Prevent startup notifications
local isInitializing = true
-- Auto Ictus
_G.AutoIctusEnabled = false
_G.AutoIctusConnections = {}

local function cleanupAutoIctus()
    -- Disconnect all Auto Ictus connections
    if _G.AutoIctusConnections then
        for _, conn in pairs(_G.AutoIctusConnections) do
            if conn and typeof(conn) == 'RBXScriptConnection' then
                pcall(function()
                    conn:Disconnect()
                end)
            end
        end
        _G.AutoIctusConnections = {}
    end
    print('[AUTO ICTUS] All connections cleaned up')
end

local function startAutoIctus()
    local Players = game:GetService('Players')
    local LocalPlayer = Players.LocalPlayer
    local rs = game:GetService('ReplicatedStorage')

    local trackedAbilities = {
        ['rbxassetid://71157109677249'] = true,
        ['rbxassetid://81743171989186'] = true,
    }

    local function equipIctus()
        if not _G.AutoIctusEnabled then
            return
        end
        pcall(function()
            rs.Remotes.AbilityService.ToServer.AbilitySelected:FireServer(
                'Ictus'
            )
        end)
    end

    local function trackEnemy(player)
        if not _G.AutoIctusEnabled then
            return
        end
        if player == LocalPlayer then
            return
        end

        local function setup(char)
            if not _G.AutoIctusEnabled then
                return
            end
            local hum = char:WaitForChild('Humanoid', 5)
            if not hum then
                return
            end

            local conn = hum.AnimationPlayed:Connect(function(track)
                if not _G.AutoIctusEnabled then
                    return
                end
                local id = track.Animation and track.Animation.AnimationId
                if trackedAbilities[id] then
                    equipIctus()
                end
            end)

            -- Store connection for cleanup
            table.insert(_G.AutoIctusConnections, conn)
        end

        if player.Character then
            setup(player.Character)
        end

        local charAddedConn = player.CharacterAdded:Connect(function(char)
            if _G.AutoIctusEnabled then
                setup(char)
            end
        end)
        table.insert(_G.AutoIctusConnections, charAddedConn)
    end

    -- Track all existing players
    for _, p in ipairs(Players:GetPlayers()) do
        trackEnemy(p)
    end

    -- Track new players
    local playerAddedConn = Players.PlayerAdded:Connect(function(p)
        if _G.AutoIctusEnabled then
            trackEnemy(p)
        end
    end)
    table.insert(_G.AutoIctusConnections, playerAddedConn)
end

-- Auto Ictus Toggle removed by user request
local AutoIctusToggle = { OnChanged = function(self, callback) end }

AutoIctusToggle:OnChanged(function(Value)
    _G.AutoIctusEnabled = Value

    if Value then
        if not isInitializing then
            Fluent:Notify({
                Title = 'Auto Ictus',
                Content = 'Enabled! Will auto-equip Ictus on tracked abilities',
                Duration = 2,
            })
        end
        task.spawn(startAutoIctus)
    else
        if not isInitializing then
            Fluent:Notify({
                Title = 'Auto Ictus',
                Content = 'Disabled',
                Duration = 2,
            })
        end
        cleanupAutoIctus()
    end
end)

ESPTab:AddParagraph({
    Title = 'ESP',
    Content = 'Enable ESP system',
})

local espTVLUpdateSeconds = tonumber(_G.__ESPTVL_UPDATE_SECONDS) or 0.5
espTVLUpdateSeconds = math.clamp(espTVLUpdateSeconds, 0.1, 10)
_G.__ESPTVL_UPDATE_SECONDS = espTVLUpdateSeconds

ESPTab:AddSlider('ESPTVLUpdateSeconds', {
    Title = 'TVL ESP Update Delay',
    Description = 'Seconds between ESP refreshes',
    Default = espTVLUpdateSeconds,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        espTVLUpdateSeconds = Value
        _G.__ESPTVL_UPDATE_SECONDS = Value
    end,
})

-- ESP state variables
_G.__ESP_ACTIVE = false
_G.__ESP_CONNECTIONS = {}
_G.__DEAD_ESP_ENABLED = false
_G.__ESP_QUEUE = {}

-- ESP registry for O(1) duplicate detection and cleanup.
-- Each tagName maps to a weak-keyed table (adornee -> BillboardGui).
-- This avoids expensive CoreGui scans when checking for existing ESP elements.
local ESP_REGISTRY = {
    NameTag = setmetatable({}, { __mode = "k" }),
    ItemESP = setmetatable({}, { __mode = "k" }),
}

-- Retrieve an existing ESP instance for the given tag and adornee.
local function GetESP(tagName, adornee)
    local bucket = ESP_REGISTRY[tagName]
    if bucket then
        return bucket[adornee]
    end
    return nil
end

-- Register a new ESP instance with the registry and automatically remove it
-- when it is destroyed. Using weak keys ensures entries are garbage collected.
local function RegisterESP(tagName, adornee, gui)
    local bucket = ESP_REGISTRY[tagName]
    if not bucket then
        return
    end
    bucket[adornee] = gui
    gui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if bucket[adornee] == gui then
                bucket[adornee] = nil
            end
        end
    end)
end


-- Helper to find an existing BillboardGui in CoreGui by name and adornee.
-- This function searches the player's CoreGui for a BillboardGui with the given name
-- and adornee and returns it if found.  It is used to avoid creating duplicate
-- ESP tags because the tags are now parented under CoreGui instead of the target head.
local function FindBillboardGui(name, adornee)
    -- First check our registry for an existing ESP of this tag.
    local existing = GetESP(name, adornee)
    if existing then
        return existing
    end
    -- Fallback: scan CoreGui for safety, and register found one to the registry.
    local coreGui = game:GetService('CoreGui')
    for _, gui in ipairs(coreGui:GetChildren()) do
        if gui:IsA('BillboardGui') and gui.Name == name and gui.Adornee == adornee then
            RegisterESP(name, adornee, gui)
            return gui
        end
    end
    return nil
end

local function cleanupESP()
    -- CRITICAL: Set state to false FIRST to stop all running ESP loops immediately
    _G.__ESP_ACTIVE = false

    -- Disconnect all ESP connections with error handling
    if _G.__ESP_CONNECTIONS then
        for i = #_G.__ESP_CONNECTIONS, 1, -1 do
            local conn = _G.__ESP_CONNECTIONS[i]
            if conn and typeof(conn) == 'RBXScriptConnection' then
                pcall(function()
                    conn:Disconnect()
                end)
            end
            _G.__ESP_CONNECTIONS[i] = nil
        end
        _G.__ESP_CONNECTIONS = {}
    end

    -- MULTI-PASS CLEANUP: Run cleanup multiple times with delays to ensure everything is removed
    -- This is critical for obfuscated scripts that may have delayed or cached references
    local function doCleanupPass()
        -- Remove all BillboardGuis from CoreGui that were created by ESP
        pcall(function()
            local coreGui = game:GetService('CoreGui')
            for _, gui in ipairs(coreGui:GetChildren()) do
                if gui:IsA('BillboardGui') and (gui.Name == 'NameTag' or gui.Name == 'ItemESP') then
                    gui:Destroy()
                end
            end
        end)

        -- Remove all NameTags from living players
        pcall(function()
            for _, player in pairs(game.Players:GetPlayers()) do
                if player.Character then
                    local head = player.Character:FindFirstChild('Head')
                    if head then
                        local nameTag = head:FindFirstChild('NameTag')
                        if nameTag then
                            nameTag:Destroy()
                        end
                    end
                end
            end
        end)

        -- Remove all NameTags from dead players (clones)
        pcall(function()
            local playerCloneFolder =
                workspace:FindFirstChild('playerCloneFolder')
            if playerCloneFolder then
                for _, clone in pairs(playerCloneFolder:GetChildren()) do
                    local head = clone:FindFirstChild('Head')
                    if head then
                        local nameTag = head:FindFirstChild('NameTag')
                        if nameTag then
                            nameTag:Destroy()
                        end
                    end
                end
            end
        end)

        -- Remove all item ESP (OPTIMIZED - no GetDescendants to prevent obfuscation lag)
        pcall(function()
            for _, item in pairs(workspace:GetChildren()) do
                if item:IsA('Model') then
                    -- Check PrimaryPart and all BaseParts for ItemESP
                    if item.PrimaryPart then
                        local esp = item.PrimaryPart:FindFirstChild('ItemESP')
                        if esp then
                            esp:Destroy()
                        end
                    end
                    for _, child in pairs(item:GetChildren()) do
                        if child:IsA('BasePart') then
                            local esp = child:FindFirstChild('ItemESP')
                            if esp then
                                esp:Destroy()
                            end
                        end
                    end
                end
            end
        end)

        -- Remove NameTag BillboardGuis (OPTIMIZED - targeted cleanup, no GetDescendants)
        pcall(function()
            -- Clean living players
            for _, player in pairs(game.Players:GetPlayers()) do
                if player.Character then
                    local head = player.Character:FindFirstChild('Head')
                    if head then
                        local nameTag = head:FindFirstChild('NameTag')
                        if nameTag then
                            nameTag:Destroy()
                        end
                    end
                end
            end
            -- Clean dead bodies
            local cloneFolder = workspace:FindFirstChild('playerCloneFolder')
            if cloneFolder then
                for _, clone in pairs(cloneFolder:GetChildren()) do
                    if clone:IsA('Model') then
                        local head = clone:FindFirstChild('Head')
                        if head then
                            local nameTag = head:FindFirstChild('NameTag')
                            if nameTag then
                                nameTag:Destroy()
                            end
                        end
                    end
                end
            end
        end)
    end

    -- Clear ESP queue to prevent any pending ESP creation
    if _G.__ESP_QUEUE then
        pcall(function()
            for i = #_G.__ESP_QUEUE, 1, -1 do
                _G.__ESP_QUEUE[i] = nil
            end
            _G.__ESP_QUEUE = {}
        end)
    end

    -- First cleanup pass (immediate)
    doCleanupPass()

    -- Schedule additional cleanup passes with delays to catch any lingering elements
    task.spawn(function()
        task.wait(0.1)
        if not _G.__ESP_ACTIVE then
            doCleanupPass()
        end
    end)

    task.spawn(function()
        task.wait(0.3)
        if not _G.__ESP_ACTIVE then
            doCleanupPass()
        end
    end)

    print('[ESP] Multi-pass cleanup initiated - State forcefully cleared')
end

local ESPToggle = ESPTab:AddToggle('ESP', {
    Title = 'Enable ESP',
    Default = false,
})
-- Forward declaration of our custom ESP functions. They will be assigned later.
local initESPTVL
local cleanupESPTVL

ESPToggle:OnChanged(function(Value)
    -- IMPORTANT: Set state FIRST before any cleanup/setup
    -- This ensures obfuscated code respects the toggle state immediately
    _G.__ESP_ACTIVE = Value

    -- Custom ESPTVL integration: enable our ESP system and skip the original implementation.
    do
        if Value then
            -- Start custom ESP
            if initESPTVL then
                initESPTVL()
            end
        else
            -- Stop custom ESP
            if cleanupESPTVL then
                cleanupESPTVL()
            end
        end
        return
    end

    -- The original ESP implementation code has been intentionally bypassed.  All code
    -- below this line in the original function will not execute because of the early
    -- return inserted above.  The definitions remain intact for reference but are
    -- now unreachable.
    local characterColors = {
        ['Silas'] = Color3.fromRGB(128, 0, 128),
        ['Bonnie Bennett'] = Color3.fromRGB(181, 101, 29),
        ['Hope Mikaelson'] = Color3.fromRGB(255, 0, 0),
        ['Esther Mikaelson'] = Color3.fromRGB(0, 0, 0),
        ['Davina Claire'] = Color3.fromRGB(0, 255, 0),
        ['Cleo Sowande'] = Color3.fromRGB(255, 255, 0),
        ['Landon Kirby'] = Color3.fromRGB(255, 165, 0),
        ['Dark Josie'] = Color3.fromRGB(160, 32, 240),
        ['Qetsiyah'] = Color3.fromRGB(0, 150, 255),
    }

    local itemDisplayMap = {
        RedOakStake = 'RedOak',
        WhiteOakStake = 'WhiteOak',
        TheCure = 'Cure',
        QetsiyahCure = 'QetCure',
        IndestructibleWhiteOakStake = 'Indestructible',
    }

    -- Increase the item update and maintenance intervals to reduce the frequency
    -- of ESP scans and lower CPU usage.  Also reduce the maximum render distance
    -- to limit how many ESP elements are drawn, which minimizes lag.
    local ITEM_UPDATE_INTERVAL = 8 -- Refresh item ESP every 8 seconds (less frequent)
    -- Increase the maintenance interval to further reduce how often players are scanned.
    local MAINTENANCE_INTERVAL = 6 -- Check every 6 seconds for missing NameTags (less frequent)
    -- Limit the ESP render distance more aggressively.  Tags beyond this distance
    -- won't render, and we also gate creation by a slightly shorter name‑tag distance.
    local MAX_ESP_DISTANCE = 600 -- Lower render distance to 600 studs
    local MAX_NAME_TAG_DISTANCE = 400 -- Only create NameTags for players/clones within 400 studs

    local espCache = {}
    local playerConnections = {}
    local cloneConnections = {} -- Track connections for each clone
    local playerNameCache = {} -- Cache for quick player name lookup
    local updateThrottle = ITEM_UPDATE_INTERVAL
    local friendCache = {}
    local itemUpdateThrottle = {} -- Per-player item update throttling

    local function createItemESP(item)
        -- CRITICAL: Check if ESP is active before creating anything
        if not _G.__ESP_ACTIVE then
            return
        end

        -- Duplicate detection will be done after determining targetPart using CoreGui

        local targetPart = item.PrimaryPart
        if not targetPart then
            for _, child in pairs(item:GetChildren()) do
                if child:IsA('BasePart') then
                    targetPart = child
                    break
                end
            end
        end

        if not targetPart then
            return
        end

        -- Check for an existing ItemESP BillboardGui in CoreGui for this target to avoid duplicates
        if GetESP('ItemESP', targetPart) then
            return
        end

        local billboardGui = Instance.new('BillboardGui')
        billboardGui.Name = 'ItemESP'
        billboardGui.Size = UDim2.new(0, 90, 0, 40)
        billboardGui.StudsOffset = Vector3.new(0, 3, 0)
        billboardGui.Adornee = targetPart
        billboardGui.LightInfluence = 0
        billboardGui.AlwaysOnTop = true
        -- Parent the BillboardGui to CoreGui instead of the target part so it renders locally
        billboardGui.Parent = game:GetService('CoreGui')
        RegisterESP('ItemESP', targetPart, billboardGui)

        local frame = Instance.new('Frame')
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Parent = billboardGui

        local itemLabel = Instance.new('TextLabel')
        itemLabel.Size = UDim2.new(1, 0, 1, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = 'White Oak Stake'
        itemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        itemLabel.TextScaled = true
        itemLabel.TextStrokeTransparency = 0
        itemLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        itemLabel.Font = Enum.Font.SourceSansBold
        itemLabel.Parent = frame
    end

    local lastItemScan = 0
    local itemScanCache = {}
    local function scanForItems()
        local now = tick()
        -- Use ITEM_UPDATE_INTERVAL for throttling instead of a hardcoded value.
        -- This ties the item scan interval to the same configurable constant used
        -- for other ESP updates, enabling easier tuning of performance.
        if now - lastItemScan < ITEM_UPDATE_INTERVAL then
            return
        end
        lastItemScan = now

        if math.random(1, 10) == 1 then
            itemScanCache = {}
        end

        for _, item in pairs(Workspace:GetChildren()) do
            if
                item.Name == 'IndestructibleWhiteOakStake'
                and item:IsA('Model')
                and not itemScanCache[item]
            then
                itemScanCache[item] = true
                if
                    not item.PrimaryPart
                    or not GetESP('ItemESP', item.PrimaryPart)
                then
                    createItemESP(item)
                end
            end
        end
    end

    local itemChildAddedConn = Workspace.ChildAdded:Connect(function(child)
        if not _G.__ESP_ACTIVE then
            return
        end
        if
            child.Name == 'IndestructibleWhiteOakStake'
            and child:IsA('Model')
        then
            task.wait(0.05)
            createItemESP(child)
        end
    end)
    table.insert(_G.__ESP_CONNECTIONS, itemChildAddedConn)

    local function createNameTag(player, character)
        -- CRITICAL: Check if ESP is active before creating anything
        if not _G.__ESP_ACTIVE then
            return
        end

        local function setup(head)
            -- Double-check state before creating ESP
            if not _G.__ESP_ACTIVE then
                return
            end

            -- Avoid duplicate NameTag by checking CoreGui instead of the head's children
            if GetESP('NameTag', head) then
                return
            end

            local billboardGui = Instance.new('BillboardGui')
            billboardGui.Name = 'NameTag'
            billboardGui.Size = UDim2.new(0, 80, 0, 35)
            billboardGui.StudsOffset = Vector3.new(0, 2, 0)
            billboardGui.Adornee = head
            billboardGui.LightInfluence = 0
            billboardGui.AlwaysOnTop = true
            billboardGui.MaxDistance = MAX_ESP_DISTANCE
            -- Parent the NameTag to CoreGui so it renders locally for the client
            billboardGui.Parent = game:GetService('CoreGui')
            RegisterESP('NameTag', head, billboardGui)

            local frame = Instance.new('Frame')
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Parent = billboardGui

            local characterLabel = Instance.new('TextLabel')
            characterLabel.Name = 'CharacterLabel'
            characterLabel.Size = UDim2.new(1, 0, 0.25, 0)
            characterLabel.Position = UDim2.new(0, 0, 0, 0)
            characterLabel.BackgroundTransparency = 1
            characterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            characterLabel.TextScaled = false
            characterLabel.TextSize = 11
            characterLabel.TextStrokeTransparency = 0
            characterLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            characterLabel.Font = Enum.Font.SourceSans
            characterLabel.Parent = frame

            local usernameLabel = Instance.new('TextLabel')
            usernameLabel.Name = 'UsernameLabel'
            usernameLabel.Size = UDim2.new(1, 0, 0.30, 0)
            usernameLabel.Position = UDim2.new(0, 0, 0.3, 0)
            usernameLabel.BackgroundTransparency = 1
            usernameLabel.Text = '@' .. player.Name
            usernameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            usernameLabel.TextSize = 10
            usernameLabel.TextScaled = false
            usernameLabel.TextStrokeTransparency = 0
            usernameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            usernameLabel.Font = Enum.Font.SourceSans
            usernameLabel.Parent = frame

            local itemsLabel = Instance.new('TextLabel')
            itemsLabel.Name = 'ItemsLabel'
            itemsLabel.Size = UDim2.new(1, 0, 0.35, 0)
            itemsLabel.Position = UDim2.new(0, 0, 0.7, 0)
            itemsLabel.BackgroundTransparency = 1
            itemsLabel.Text = ''
            itemsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            itemsLabel.TextSize = 11
            itemsLabel.TextScaled = false
            itemsLabel.TextStrokeTransparency = 0
            itemsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            itemsLabel.Font = Enum.Font.SourceSansBold
            itemsLabel.Parent = frame

            espCache[player.UserId] = {
                characterLabel = characterLabel,
                itemsLabel = itemsLabel,
                lastUpdate = 0,
            }

            local connections = playerConnections[player] or {}
            playerConnections[player] = connections

            local function updateUsernameColor()
                local friendValue = friendCache[player]
                if friendValue == nil then
                    friendValue =
                        Players.LocalPlayer:IsFriendsWith(player.UserId)
                    friendCache[player] = friendValue
                end

                if friendValue then
                    usernameLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
                else
                    usernameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            end

            local function updateCharacterName()
                local customName = player:GetAttribute('CharacterName')
                if customName then
                    characterLabel.Text = '   ' .. customName .. '   '
                    characterLabel.TextColor3 = characterColors[customName]
                        or Color3.fromRGB(255, 255, 255)
                else
                    characterLabel.Text = '   ' .. player.Name .. '   '
                    characterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
                updateUsernameColor()
            end

            local function updateItems()
                local cache = espCache[player.UserId]
                if not cache then
                    return
                end

                local now = tick()
                local lastUpdate = itemUpdateThrottle[player.UserId] or 0
                if now - lastUpdate < 1.0 then
                    return
                end
                itemUpdateThrottle[player.UserId] = now

                if now - cache.lastUpdate < updateThrottle then
                    return
                end
                cache.lastUpdate = now

                local found = {}

                local function collect(container)
                    if not container then
                        return
                    end
                    for _, inst in ipairs(container:GetChildren()) do
                        if inst:IsA('Tool') and itemDisplayMap[inst.Name] then
                            found[itemDisplayMap[inst.Name]] = true
                        end
                    end
                end

                collect(player:FindFirstChild('Backpack'))
                local char = player.Character
                if char and char:FindFirstChild('HumanoidRootPart') then
                    collect(char)
                end

                local items = {}
                for label in pairs(found) do
                    table.insert(items, label)
                end
                table.sort(items)

                itemsLabel.Text = #items > 0 and table.concat(items, ', ') or ''
            end

            updateCharacterName()
            updateItems()

            player.AttributeChanged:Connect(function(attributeName)
                if attributeName == 'CharacterName' then
                    updateCharacterName()
                end
            end)

            local function connectBackpack(backpack)
                if connections.backpackChildAdded then
                    connections.backpackChildAdded:Disconnect()
                    connections.backpackChildAdded = nil
                end
                if connections.backpackChildRemoved then
                    connections.backpackChildRemoved:Disconnect()
                    connections.backpackChildRemoved = nil
                end

                if backpack then
                    connections.backpackChildAdded =
                        backpack.ChildAdded:Connect(updateItems)
                    connections.backpackChildRemoved =
                        backpack.ChildRemoved:Connect(updateItems)
                    updateItems()
                end
            end

            local function connectCharacter(character)
                if connections.characterChildAdded then
                    connections.characterChildAdded:Disconnect()
                    connections.characterChildAdded = nil
                end
                if connections.characterChildRemoved then
                    connections.characterChildRemoved:Disconnect()
                    connections.characterChildRemoved = nil
                end

                if character then
                    connections.characterChildAdded =
                        character.ChildAdded:Connect(updateItems)
                    connections.characterChildRemoved =
                        character.ChildRemoved:Connect(updateItems)
                    updateItems()
                end
            end

            connectBackpack(player.Backpack)
            connectCharacter(player.Character)

            if not connections.playerChildAdded then
                connections.playerChildAdded = player.ChildAdded:Connect(
                    function(child)
                        if child.Name == 'Backpack' then
                            connectBackpack(child)
                        end
                    end
                )
            end
        end

        -- Wait for Head to load with timeout
        local head = character:FindFirstChild('Head')
        if not head then
            task.spawn(function()
                local success = pcall(function()
                    head = character:WaitForChild('Head', 5)
                end)
                if success and head then
                    setup(head)
                end
            end)
        else
            setup(head)
        end
    end


-- Optimized queue using a ring buffer and Heartbeat budgeted processing.
-- Avoids O(n) shifts from table.remove and eliminates random jitter waits.
local isProcessingQueue = false
-- Head/tail indices for ring buffer
local qHead, qTail = 1, 0
-- Push a new entry onto the queue
local function qPush(v)
    qTail = qTail + 1
    _G.__ESP_QUEUE[qTail] = v
end
-- Pop an entry from the queue
local function qPop()
    if qHead > qTail then
        return nil
    end
    local v = _G.__ESP_QUEUE[qHead]
    _G.__ESP_QUEUE[qHead] = nil
    qHead = qHead + 1
    -- Occasionally compact the queue to avoid integer overflow
    if qHead > 500 and qHead > (qTail / 2) then
        local new = {}
        local n = 0
        for i = qHead, qTail do
            n = n + 1
            new[n] = _G.__ESP_QUEUE[i]
        end
        _G.__ESP_QUEUE = new
        qHead, qTail = 1, n
    end
    return v
end
local heartbeatConn
local selectionChangeConn
    local function processESPQueue()
        -- Avoid multiple concurrent processors
        if isProcessingQueue then
            return
        end
        -- Reset queue if ESP is disabled
        if not _G.__ESP_ACTIVE then
            _G.__ESP_QUEUE = {}
            qHead, qTail = 1, 0
            return
        end
        isProcessingQueue = true
        local RunService = game:GetService('RunService')
        heartbeatConn = RunService.Heartbeat:Connect(function()
            -- If ESP has been turned off, stop processing and clear queue
            if not _G.__ESP_ACTIVE then
                if heartbeatConn then
                    heartbeatConn:Disconnect()
                end
                isProcessingQueue = false
                qHead, qTail = 1, 0
                _G.__ESP_QUEUE = {}
                return
            end
            -- Process queue within a small time budget per frame
            local start = os.clock()
            local budget = 0.0012 -- ~1.2ms per frame (lowered)
            local processed = 0
            while os.clock() - start < budget do
                local data = qPop()
                if not data then
                    -- Queue empty; stop processing
                    if heartbeatConn then
                        heartbeatConn:Disconnect()
                    end
                    isProcessingQueue = false
                    return
                end
                if data.character and data.player then
                    -- Create the NameTag immediately (no defer needed since we are on Heartbeat)
                    createNameTag(data.player, data.character)
                end
                processed = processed + 1
                -- Hard cap per frame to prevent hitches (lowered)
                if processed >= 2 then
                    break
                end
            end
            -- Add a small wait to further reduce per-frame load
            if processed > 0 then
                task.wait(0.01)
            end
        end)
    end
local function onCharacterAdded(character, player)
    -- Only queue if ESP is active
    if not _G.__ESP_ACTIVE then
        return
    end
    -- Ensure character is valid before adding to queue
    if not character or not character.Parent then
        task.wait(0.2)
        if not character or not character.Parent then
            return
        end
    end
    -- Push to queue without any jitter
    qPush({ character = character, player = player })
    -- Start processing if not already
    if not isProcessingQueue then
        task.defer(processESPQueue)
    end
end



    local function onPlayerAdded(player)
        if player == Players.LocalPlayer then
            return
        end

        -- Update player name cache for fast dead body lookup
        playerNameCache[player.Name] = player

        player.CharacterAdded:Connect(function(character)
            -- Short delay for sequential rendering
            task.wait(0.3)
            if _G.__ESP_ACTIVE then
                task.defer(function()
                    onCharacterAdded(character, player)
                end)
            end
        end)

        -- Handle existing character
        if player.Character then
            task.spawn(function()
                task.wait(0.5)
                if _G.__ESP_ACTIVE then
                    onCharacterAdded(player.Character, player)
                end
            end)
        end
    end

    -- Handle player clones from workspace.playerCloneFolder
    local function createCloneNameTag(cloneModel)
        -- CRITICAL: Check if ESP is active first
        if not _G.__ESP_ACTIVE then
            return
        end

        -- Check if dead ESP is enabled
        if not _G.__DEAD_ESP_ENABLED then
            return
        end

        -- IMPORTANT: Only process clones that are in playerCloneFolder
        -- This prevents showing ESP on NPCs/entities
        if
            not cloneModel.Parent
            or cloneModel.Parent.Name ~= 'playerCloneFolder'
        then
            return
        end

        local head = cloneModel:FindFirstChild('Head')
        -- Prevent duplicate NameTags by checking CoreGui instead of the head's children
        if not head or GetESP('NameTag', head) then
            return
        end

        -- Gate creation by distance: only create a NameTag if the clone is within
        -- MAX_NAME_TAG_DISTANCE of the local player.  This prevents far‑away
        -- corpses from spawning extra GUI elements that hurt performance.
        do
            local myChar = Players.LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild('HumanoidRootPart')
            if myRoot and head then
                local dist = (head.Position - myRoot.Position).Magnitude
                if dist > MAX_NAME_TAG_DISTANCE then
                    return
                end
            end
        end

        -- Use cached player lookup for better performance (O(1) instead of O(n))
        local playerName = cloneModel.Name
        local targetPlayer = playerNameCache[playerName]

        -- Only create ESP if we found a matching player
        -- This ensures we only show dead PLAYERS, not NPCs
        if not targetPlayer then
            return
        end

        -- Create billboard GUI for clone
        local billboardGui = Instance.new('BillboardGui')
        billboardGui.Name = 'NameTag'
        billboardGui.Size = UDim2.new(0, 90, 0, 40)
        billboardGui.StudsOffset = Vector3.new(0, 2, 0)
        billboardGui.Adornee = head
        billboardGui.LightInfluence = 0
        billboardGui.AlwaysOnTop = true
        -- Limit render distance on dead NameTags to reduce draw calls
        billboardGui.MaxDistance = MAX_ESP_DISTANCE
        -- Parent the NameTag to CoreGui so it renders locally for the client
        billboardGui.Parent = game:GetService('CoreGui')
        RegisterESP('NameTag', head, billboardGui)

        local frame = Instance.new('Frame')
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Parent = billboardGui

        local characterLabel = Instance.new('TextLabel')
        characterLabel.Name = 'CharacterLabel'
        characterLabel.Size = UDim2.new(1, 0, 0.25, 0)
        characterLabel.Position = UDim2.new(0, 0, 0, 0)
        characterLabel.BackgroundTransparency = 1
        characterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        characterLabel.TextScaled = false
        characterLabel.TextSize = 11
        characterLabel.TextStrokeTransparency = 0
        characterLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        characterLabel.Font = Enum.Font.SourceSans
        characterLabel.Parent = frame

        local usernameLabel = Instance.new('TextLabel')
        usernameLabel.Name = 'UsernameLabel'
        usernameLabel.Size = UDim2.new(1, 0, 0.25, 0)
        usernameLabel.Position = UDim2.new(0, 0, 0.35, 0) -- Increased from 0.25 to 0.35 for more spacing
        usernameLabel.BackgroundTransparency = 1
        usernameLabel.Text = '@' .. targetPlayer.Name .. ' (Dead)'
        usernameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        usernameLabel.TextScaled = true
        usernameLabel.TextStrokeTransparency = 0
        usernameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        usernameLabel.Font = Enum.Font.SourceSans
        usernameLabel.Parent = frame

        -- Get CharacterName attribute from the player
        local function updateCloneCharacterName()
            local customName = targetPlayer:GetAttribute('CharacterName')
            if customName then
                characterLabel.Text = '💀 ' .. customName .. ' 💀'
                characterLabel.TextColor3 = characterColors[customName]
                    or Color3.fromRGB(255, 255, 255)
            else
                characterLabel.Text = '💀 ' .. targetPlayer.Name .. ' 💀'
                characterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end

        updateCloneCharacterName()

        -- Listen for attribute changes on the player and track the connection
        if not cloneConnections[cloneModel] then
            cloneConnections[cloneModel] = {}
        end

        cloneConnections[cloneModel].attributeConn = targetPlayer.AttributeChanged:Connect(
            function(attributeName)
                if attributeName == 'CharacterName' then
                    updateCloneCharacterName()
                end
            end
        )

        -- Cleanup connection when clone is removed
        cloneConnections[cloneModel].ancestryConn = cloneModel.AncestryChanged:Connect(
            function(_, parent)
                if not parent then
                    -- Clone was removed, cleanup connections
                    local conns = cloneConnections[cloneModel]
                    if conns then
                        if conns.attributeConn then
                            conns.attributeConn:Disconnect()
                        end
                        if conns.ancestryConn then
                            conns.ancestryConn:Disconnect()
                        end
                        cloneConnections[cloneModel] = nil
                    end
                end
            end
        )
    end

    -- Monitor playerCloneFolder for new clones
    local function setupCloneFolderMonitoring()
        local cloneFolder = workspace:FindFirstChild('playerCloneFolder')
        if cloneFolder then
            -- Process existing clones
            for _, clone in ipairs(cloneFolder:GetChildren()) do
                if clone:IsA('Model') then
                    task.defer(function()
                        createCloneNameTag(clone)
                    end)
                end
            end

            -- Monitor for new clones
            local cloneAddedConn = cloneFolder.ChildAdded:Connect(
                function(clone)
                    if not _G.__ESP_ACTIVE or not _G.__DEAD_ESP_ENABLED then
                        return
                    end
                    if clone:IsA('Model') then
                        task.wait(0.1) -- Optimized for obfuscation performance
                        createCloneNameTag(clone)
                    end
                end
            )
            table.insert(_G.__ESP_CONNECTIONS, cloneAddedConn)
        end
    end

    local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        espCache[player.UserId] = nil
        playerNameCache[player.Name] = nil -- Clean up name cache
        friendCache[player] = nil -- Clean up friend cache
        itemUpdateThrottle[player.UserId] = nil -- Clean up throttle cache
        local connections = playerConnections[player]
        if connections then
            for key, conn in pairs(connections) do
                if typeof(conn) == 'RBXScriptConnection' then
                    conn:Disconnect()
                end
                connections[key] = nil
            end
            playerConnections[player] = nil
        end
    end)
    table.insert(_G.__ESP_CONNECTIONS, playerRemovingConn)

    local playerAddedConn = Players.PlayerAdded:Connect(onPlayerAdded)
    table.insert(_G.__ESP_CONNECTIONS, playerAddedConn)

    task.spawn(function()
        local existingPlayers = Players:GetPlayers()
        for i, player in ipairs(existingPlayers) do
            if player ~= Players.LocalPlayer then
                task.defer(function()
                    onPlayerAdded(player)
                end)
            end
            -- Wait 0.3s between each player for faster rendering
            task.wait(0.3)
        end
    end)

    -- Setup clone folder monitoring
    setupCloneFolderMonitoring()

    scanForItems()

    local lastItemScanTime = 0
    task.spawn(function()
        while _G.__ESP_ACTIVE do
            task.wait(MAINTENANCE_INTERVAL) -- Use the constant defined at the top
            -- Only check for missing ESP on live players with batching
            local playerList = Players:GetPlayers()
            local processedCount = 0

            for _, player in pairs(playerList) do
                if player ~= Players.LocalPlayer then
                    local character = player.Character
                    if character and character.Parent then
                        local head = character:FindFirstChild('Head')
                        -- Create ESP if missing - use immediate creation for faster response
                        if head and not GetESP('NameTag', head) then
                            -- Only create a NameTag if the player is within the defined distance.  This
                            -- prevents dozens of far‑away tags from being added and reduces lag when
                            -- many players are present.  Use the character's HumanoidRootPart as the
                            -- reference point and compare to our own root.
                            local rootPart = character:FindFirstChild('HumanoidRootPart')
                            local myChar = Players.LocalPlayer.Character
                            local myRoot = myChar and myChar:FindFirstChild('HumanoidRootPart')
                            local withinRange = true
                            if myRoot and rootPart then
                                local dist = (rootPart.Position - myRoot.Position).Magnitude
                                if dist > MAX_NAME_TAG_DISTANCE then
                                    withinRange = false
                                end
                            end
                            if withinRange then
                                -- Create immediately instead of deferring for faster render distance response
                                pcall(function()
                                    createNameTag(player, character)
                                end)
                            end
                        end
                    end
                    -- Yield every 2 players to prevent frame drops more often.  More
                    -- frequent yields reduce per-frame workload, smoothing out
                    -- gameplay at the expense of slightly longer update cycles.
                    processedCount = processedCount + 1
                    if processedCount % 2 == 0 then
                        task.wait(0.02)
                    end
                end
            end

            -- Dead body ESP is now handled entirely by ChildAdded monitoring
            -- No need to scan clones here - removes major FPS drop

            -- Check for missing dead ESP (optimized with duplicate checks and batching)
            if _G.__DEAD_ESP_ENABLED then
                local playerCloneFolder =
                    workspace:FindFirstChild('playerCloneFolder')
                if playerCloneFolder then
                    local cloneCount = 0
                    for _, clone in pairs(playerCloneFolder:GetChildren()) do
                        if clone:IsA('Model') then
                            local head = clone:FindFirstChild('Head')
                            -- Check for NameTag to prevent duplicates
                            if head and not GetESP('NameTag', head) then
                                -- Gate dead NameTag creation by distance as well.  Use the clone's head
                                -- position and the local player's root to skip very distant corpses.
                                local myChar = Players.LocalPlayer.Character
                                local myRoot = myChar and myChar:FindFirstChild('HumanoidRootPart')
                                local withinRange = true
                                if myRoot and head then
                                    local dist = (head.Position - myRoot.Position).Magnitude
                                    if dist > MAX_NAME_TAG_DISTANCE then
                                        withinRange = false
                                    end
                                end
                                if withinRange then
                                    createCloneNameTag(clone)
                                end
                            end

                            -- Yield every 3 clones to prevent frame drops
                            cloneCount = cloneCount + 1
                            if cloneCount % 3 == 0 then
                                task.wait()
                            end
                        end
                    end
                end
            end

            -- Throttle item scanning using the same configurable interval as item ESP.
            local now = tick()
            if now - lastItemScanTime >= ITEM_UPDATE_INTERVAL then
                -- Run in separate thread to avoid blocking this loop
                task.defer(scanForItems)
                lastItemScanTime = now
            end
        end
    end)
end)

-- Dead ESP Toggle (Standalone System)
-- Custom ESPTVL system definitions.  These implement the new ESP behaviour and are
-- invoked by the toggle callback inserted above.  They are defined inside a
-- localized scope to avoid polluting the global environment.
do
    -- State table for the custom ESP
    local __ESPTVL = {
        enabled = false,
        esp = {},
        stakeESP = {},
        connections = {},
        playerConns = {},
        characterNamesCached = {},
        specieTypesCached = {},
        updateInterval = espTVLUpdateSeconds,
        -- Cache of friend relationships keyed by Player instance.  This allows
        -- IsFriendsWith calls to be avoided in the main loop, reducing the
        -- frequency of expensive API calls which may yield or error.  The
        -- cache is populated when the ESP is initialised and refreshed
        -- periodically while active.
        friendStatusCache = {},
        toolCache = {},
        trackedPlayers = {},
        stakeObjects = setmetatable({}, { __mode = 'k' }),
        friendUpdateTask = nil,
        loopTask = nil,
        player = nil,
        Players = nil,
        ReplicatedStorage = nil,
        SpeciesData = nil,
    }

    -- Tool name mappings
    local toolNames = {
        RedOakStake = 'RedOak',
        WhiteOakStake = 'WhiteOak',
        QetsiyahCure = 'QetCure',
        TheCure = 'Cure',
        IndestructibleWhiteOakStake = 'Indestructible',
    }

    -- Special character colours
    local specialCharColors = {
        ['Cleo Sowande'] = Color3.fromRGB(230, 167, 32),
        ['Esther Mikaelson'] = Color3.fromRGB(23, 22, 23),
        ['Qetsiyah'] = Color3.fromRGB(66, 149, 219),
        ['Bonnie Bennett'] = Color3.fromRGB(69, 53, 14),
        ['Dark Josie'] = Color3.fromRGB(224, 39, 171),
        ['Hope Mikaelson'] = Color3.fromRGB(194, 0, 0),
        ['Silas'] = Color3.fromRGB(147, 62, 230),
        ['Davina Claire'] = Color3.fromRGB(67, 222, 33),
        ['Landon Kirby'] = Color3.fromRGB(222, 123, 51),
    }

    -- Helper to create a BillboardGui for a player's character
    local function createBillboard(adornee)
        local gui = Instance.new('BillboardGui')
        gui.Size = UDim2.new(0, 113, 0, 60)
        gui.Adornee = adornee
        gui.AlwaysOnTop = true
        gui.StudsOffset = Vector3.new(0, 2.5, 0)
        gui.Parent = adornee
        local function makeLabel(name, yScale, font, size, color)
            local lbl = Instance.new('TextLabel')
            lbl.Name = name
            lbl.Size = UDim2.new(1, 0, 0.25, 0)
            lbl.Position = UDim2.new(0, 0, yScale, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextStrokeTransparency = 0.5
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.TextColor3 = color
            lbl.TextSize = size
            lbl.Font = font
            lbl.Parent = gui
            return lbl
        end
        return {
            gui = gui,
            charLabel = makeLabel('CharacterLabel', 0, Enum.Font.GothamMedium, 11, Color3.fromRGB(200, 200, 200)),
            userLabel = makeLabel('UserLabel', 0.25, Enum.Font.GothamMedium, 11, Color3.fromRGB(255, 255, 255)),
            toolLabel = makeLabel('ToolLabel', 0.5, Enum.Font.GothamMedium, 9, Color3.fromRGB(200, 200, 200)),
            distanceLabel = makeLabel('DistanceLabel', 0.75, Enum.Font.GothamMedium, 10, Color3.fromRGB(200, 200, 200)),
        }
    end

    -- Build and cache a comma-separated list of tools carried by a player.
    local function rebuildToolCache(targetPlayer)
        local tools, seen = {}, {}
        local function collect(container)
            if not container then
                return
            end
            for _, inst in ipairs(container:GetChildren()) do
                if inst:IsA('Tool') then
                    local mapped = toolNames[inst.Name]
                    if mapped and not seen[mapped] then
                        seen[mapped] = true
                        table.insert(tools, mapped)
                    end
                end
            end
        end
        collect(targetPlayer:FindFirstChildOfClass('Backpack'))
        collect(targetPlayer.Character)
        __ESPTVL.toolCache[targetPlayer] =
            #tools > 0 and table.concat(tools, ', ') or nil
    end

    -- Retrieve cached tool text for a player.
    local function getTools(targetPlayer)
        return __ESPTVL.toolCache[targetPlayer]
    end

    -- Keep tool cache synced via lightweight event listeners.
    local function setupToolCache(targetPlayer)
        if not __ESPTVL.playerConns[targetPlayer] then
            __ESPTVL.playerConns[targetPlayer] = {}
        end
        local conns = __ESPTVL.playerConns[targetPlayer]

        local function disconnectKey(key)
            local conn = conns[key]
            if conn then
                conn:Disconnect()
                conns[key] = nil
            end
        end

        local function connectBackpack(backpack)
            disconnectKey('backpackChildAdded')
            disconnectKey('backpackChildRemoved')
            if backpack then
                conns.backpackChildAdded =
                    backpack.ChildAdded:Connect(function(child)
                        if child:IsA('Tool') then
                            rebuildToolCache(targetPlayer)
                        end
                    end)
                conns.backpackChildRemoved =
                    backpack.ChildRemoved:Connect(function(child)
                        if child:IsA('Tool') then
                            rebuildToolCache(targetPlayer)
                        end
                    end)
            end
        end

        local function connectCharacter(char)
            disconnectKey('characterChildAdded')
            disconnectKey('characterChildRemoved')
            if char then
                conns.characterChildAdded =
                    char.ChildAdded:Connect(function(child)
                        if child:IsA('Tool') then
                            rebuildToolCache(targetPlayer)
                        end
                    end)
                conns.characterChildRemoved =
                    char.ChildRemoved:Connect(function(child)
                        if child:IsA('Tool') then
                            rebuildToolCache(targetPlayer)
                        end
                    end)
            end
        end

        if not conns.playerChildAddedTool then
            conns.playerChildAddedTool = targetPlayer.ChildAdded:Connect(
                function(child)
                    if child:IsA('Backpack') then
                        connectBackpack(child)
                        rebuildToolCache(targetPlayer)
                    end
                end
            )
        end

        if not conns.characterAddedTool then
            conns.characterAddedTool = targetPlayer.CharacterAdded:Connect(
                function(char)
                    connectCharacter(char)
                    rebuildToolCache(targetPlayer)
                end
            )
        end

        connectBackpack(targetPlayer:FindFirstChildOfClass('Backpack'))
        connectCharacter(targetPlayer.Character)
        rebuildToolCache(targetPlayer)
    end

    -- Destroy the ESP billboard for a player
    local function clearESP(targetPlayer)
        local entry = __ESPTVL.esp[targetPlayer]
        if entry and entry.gui then
            pcall(function()
                entry.gui:Destroy()
            end)
        end
        __ESPTVL.esp[targetPlayer] = nil
    end

    local function clearStakeESP(stakeObj)
        local gui = __ESPTVL.stakeESP[stakeObj]
        if gui then
            pcall(function()
                gui:Destroy()
            end)
            __ESPTVL.stakeESP[stakeObj] = nil
        end
        __ESPTVL.stakeObjects[stakeObj] = nil
    end

    local function registerStakeObject(obj)
        if obj and obj.Name == 'IndestructibleWhiteOakStake' then
            __ESPTVL.stakeObjects[obj] = true
        end
    end

    local function syncStakeESP(stakeObj)
        if not stakeObj or not stakeObj.Parent then
            clearStakeESP(stakeObj)
            return
        end

        local main = stakeObj:FindFirstChild('Main')
        if not main then
            return
        end

        local existingGui = __ESPTVL.stakeESP[stakeObj]
        if existingGui and existingGui.Parent then
            return
        end

        if existingGui then
            pcall(function()
                existingGui:Destroy()
            end)
            __ESPTVL.stakeESP[stakeObj] = nil
        end

        local gui = Instance.new('BillboardGui')
        gui.Name = 'StakeESP'
        gui.Size = UDim2.new(0, 120, 0, 25)
        gui.Adornee = main
        gui.AlwaysOnTop = true
        gui.MaxDistance = 600 -- Match player ESP distance
        gui.StudsOffset = Vector3.new(0, 3, 0)
        gui.Parent = main

        local label = Instance.new('TextLabel')
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.5
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextSize = 11
        label.Text = 'White Oak Stake'
        label.Font = Enum.Font.GothamMedium
        label.Parent = gui

        __ESPTVL.stakeESP[stakeObj] = gui
    end

    -- Setup character ESP for a player
    local function setupCharacterESP(targetPlayer)
        -- Disconnect previous connections
        if __ESPTVL.playerConns[targetPlayer] then
            for _, conn in pairs(__ESPTVL.playerConns[targetPlayer]) do
                if conn then
                    conn:Disconnect()
                end
            end
        end
        __ESPTVL.playerConns[targetPlayer] = {}
        -- Spawn Billboard when character added
        local charAddedConn = targetPlayer.CharacterAdded:Connect(function(char)
            local hrp = char:WaitForChild('HumanoidRootPart', 5)
            if hrp and __ESPTVL.enabled then
                clearESP(targetPlayer)
                __ESPTVL.esp[targetPlayer] = createBillboard(hrp)
            end
        end)
        table.insert(__ESPTVL.playerConns[targetPlayer], charAddedConn)
    end

    -- Cache character and species attributes and respond to changes
    local function setUpCached(targetPlayer)
        task.spawn(function()
            if not __ESPTVL.playerConns[targetPlayer] then
                __ESPTVL.playerConns[targetPlayer] = {}
            end
            local characterNameChanged
            local specieChanged
            local function handleCharacter(char)
                local hrp = char:WaitForChild('HumanoidRootPart', 5)
                if hrp and __ESPTVL.enabled then
                    clearESP(targetPlayer)
                    if specieChanged then
                        -- Disconnect and remove the previous specieChanged connection
                        specieChanged:Disconnect()
                        local conns = __ESPTVL.playerConns[targetPlayer]
                        if conns then
                            for idx, c in ipairs(conns) do
                                if c == specieChanged then
                                    table.remove(conns, idx)
                                    break
                                end
                            end
                        end
                    end
                    __ESPTVL.specieTypesCached[targetPlayer.UserId] = char:GetAttribute('SpecieType') or ''
                    specieChanged = char:GetAttributeChangedSignal('SpecieType'):Connect(function()
                        __ESPTVL.specieTypesCached[targetPlayer.UserId] = char:GetAttribute('SpecieType') or ''
                    end)
                    -- Track the attribute change connection so it can be
                    -- disconnected during cleanup.  Without storing this
                    -- connection, specieChanged would leak when the ESP is
                    -- cleaned up because it is only referenced by this local
                    -- variable.
                    table.insert(__ESPTVL.playerConns[targetPlayer], specieChanged)
                    __ESPTVL.characterNamesCached[targetPlayer.UserId] =
                        targetPlayer:GetAttribute('CharacterName') or ''
                    __ESPTVL.esp[targetPlayer] = createBillboard(hrp)
                end
            end
            if targetPlayer.Character then
                handleCharacter(targetPlayer.Character)
            end
            local charAddedConn = targetPlayer.CharacterAdded:Connect(handleCharacter)
            table.insert(__ESPTVL.playerConns[targetPlayer], charAddedConn)
            if characterNameChanged then
                characterNameChanged:Disconnect()
            end
            __ESPTVL.characterNamesCached[targetPlayer.UserId] =
                targetPlayer:GetAttribute('CharacterName') or ''
            characterNameChanged = targetPlayer:GetAttributeChangedSignal('CharacterName'):Connect(function()
                __ESPTVL.characterNamesCached[targetPlayer.UserId] =
                    targetPlayer:GetAttribute('CharacterName') or ''
            end)
            table.insert(__ESPTVL.playerConns[targetPlayer], characterNameChanged)
            local removedConn = targetPlayer.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    __ESPTVL.characterNamesCached[targetPlayer.UserId] = nil
                    __ESPTVL.specieTypesCached[targetPlayer.UserId] = nil
                    if __ESPTVL.playerConns[targetPlayer] then
                        for _, conn in pairs(__ESPTVL.playerConns[targetPlayer]) do
                            if conn then
                                conn:Disconnect()
                            end
                        end
                        __ESPTVL.playerConns[targetPlayer] = nil
                    end
                    if specieChanged then
                        specieChanged:Disconnect()
                    end
                end
            end)
            table.insert(__ESPTVL.playerConns[targetPlayer], removedConn)
        end)
    end

    -- Implementation of initialising the ESP
    initESPTVL = function()
        if __ESPTVL.enabled then
            return
        end
        __ESPTVL.enabled = true
        local Players = game:GetService('Players')
        local ReplicatedStorage = game:GetService('ReplicatedStorage')
        local player = Players.LocalPlayer
        local SpeciesData = require(ReplicatedStorage.ModuleScripts.Data.SpeciesData)
        __ESPTVL.Players = Players
        __ESPTVL.ReplicatedStorage = ReplicatedStorage
        __ESPTVL.player = player
        __ESPTVL.SpeciesData = SpeciesData
        __ESPTVL.updateInterval = espTVLUpdateSeconds

        -- Initialise and populate friend status cache.  To avoid repeatedly
        -- invoking Player:IsFriendsWith() in the main ESP loop (which can
        -- yield and sometimes cause instability due to engine bugs), we
        -- compute whether the local player is friends with other players
        -- once when they join the game.  Results are stored in
        -- __ESPTVL.friendStatusCache and used in the update loop.
        __ESPTVL.friendStatusCache = {}
        -- Helper to update the friend status for a specific target player.  If
        -- the IsFriendsWith call fails, we conservatively mark them as not
        -- a friend.  The target player is used as the key directly; this
        -- avoids key collisions when players leave and new players join with
        -- the same UserId.
        local function updateFriendStatusFor(target)
            local ok, isFr = pcall(function()
                return player:IsFriendsWith(target.UserId)
            end)
            __ESPTVL.friendStatusCache[target] = ok and isFr or false
        end

        -- Populate cache for players already in the game
        for _, existingPlayer in ipairs(Players:GetPlayers()) do
            if existingPlayer ~= player then
                updateFriendStatusFor(existingPlayer)
            end
        end

        -- Player join/leave listeners
        local addConn = Players.PlayerAdded:Connect(function(newPlayer)
            if newPlayer ~= player then
                __ESPTVL.trackedPlayers[newPlayer] = true
                -- Update friend status for the new player before creating ESP
                updateFriendStatusFor(newPlayer)
                setupCharacterESP(newPlayer)
                setUpCached(newPlayer)
                setupToolCache(newPlayer)
            end
        end)
        local removeConn = Players.PlayerRemoving:Connect(function(leavingPlayer)
            clearESP(leavingPlayer)
            __ESPTVL.trackedPlayers[leavingPlayer] = nil
            -- Disconnect per-player connections
            if __ESPTVL.playerConns[leavingPlayer] then
                for _, conn in pairs(__ESPTVL.playerConns[leavingPlayer]) do
                    if conn then
                        conn:Disconnect()
                    end
                end
                __ESPTVL.playerConns[leavingPlayer] = nil
            end
            -- Remove cached data for the leaving player
            __ESPTVL.characterNamesCached[leavingPlayer.UserId] = nil
            __ESPTVL.specieTypesCached[leavingPlayer.UserId] = nil
            __ESPTVL.friendStatusCache[leavingPlayer] = nil
            __ESPTVL.toolCache[leavingPlayer] = nil
        end)
        __ESPTVL.connections.PlayerAdded = addConn
        __ESPTVL.connections.PlayerRemoving = removeConn
        __ESPTVL.connections.WorkspaceChildAdded = workspace.ChildAdded:Connect(
            function(obj)
                if obj.Name == 'IndestructibleWhiteOakStake' then
                    registerStakeObject(obj)
                    syncStakeESP(obj)
                end
            end
        )
        __ESPTVL.connections.WorkspaceChildRemoved = workspace.ChildRemoved:Connect(
            function(obj)
                if obj.Name == 'IndestructibleWhiteOakStake' then
                    clearStakeESP(obj)
                end
            end
        )

        for _, obj in ipairs(workspace:GetChildren()) do
            registerStakeObject(obj)
        end
        -- Setup existing players
        for _, existingPlayer in ipairs(Players:GetPlayers()) do
            if existingPlayer ~= player then
                __ESPTVL.trackedPlayers[existingPlayer] = true
                setupCharacterESP(existingPlayer)
                setUpCached(existingPlayer)
                setupToolCache(existingPlayer)
            end
        end

        -- Periodically refresh friend status cache.  Some experiences allow
        -- players to become friends or unfriend while the game is running;
        -- additionally the IsFriendsWith API can occasionally return
        -- inconsistent results if called too frequently.  Refreshing the
        -- cache on a slower cadence ensures the ESP reflects changes
        -- without spamming the API.  This task exits automatically when
        -- __ESPTVL.enabled is set to false.
        __ESPTVL.friendUpdateTask = task.spawn(function()
            while __ESPTVL.enabled do
                task.wait(60)
                if not __ESPTVL.enabled then
                    break
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player then
                        updateFriendStatusFor(p)
                    end
                end
            end
        end)
        -- Spawn main loop
        __ESPTVL.loopTask = task.spawn(function()
            while __ESPTVL.enabled do
                local updateDelay = tonumber(espTVLUpdateSeconds) or __ESPTVL.updateInterval
                if updateDelay < 0.1 then
                    updateDelay = 0.1
                end
                __ESPTVL.updateInterval = updateDelay
                task.wait(updateDelay)
                if not __ESPTVL.enabled then
                    break
                end
                -- Update each other player
                for targetPlayer in pairs(__ESPTVL.trackedPlayers) do
                    local char = targetPlayer.Character
                    local hrp = char and char:FindFirstChild('HumanoidRootPart')
                    local hum = char and char:FindFirstChildOfClass('Humanoid')
                    if
                        not targetPlayer.Parent
                        or not char
                        or not hrp
                        or not hum
                        or hum.Health <= 0
                    then
                        clearESP(targetPlayer)
                    else
                        if not __ESPTVL.esp[targetPlayer] then
                            __ESPTVL.esp[targetPlayer] = createBillboard(hrp)
                        end
                        local e = __ESPTVL.esp[targetPlayer]
                        if e then
                            -- Hide the distance label.  Friend status is pulled from
                            -- the cached table rather than calling IsFriendsWith each
                            -- iteration.  Frequent calls to IsFriendsWith can yield
                            -- and in some cases cause client instability.  The cache
                            -- is updated when players join and periodically via
                            -- friendUpdateTask in initESPTVL.
                            e.distanceLabel.Visible = false
                            local isFriend =
                                __ESPTVL.friendStatusCache[targetPlayer] or false
                            -- Distance computation removed as per request
                            local charName =
                                __ESPTVL.characterNamesCached[targetPlayer.UserId]
                                or targetPlayer:GetAttribute('CharacterName')
                            local specieType =
                                __ESPTVL.specieTypesCached[targetPlayer.UserId]
                                or (char and char:GetAttribute('SpecieType'))
                            e.charLabel.Visible = charName and charName ~= ''
                            if charName then
                                -- Always display the character name without species and without a star
                                local color
                                if
                                    specieType
                                    and specieType ~= ''
                                    and __ESPTVL.SpeciesData[specieType]
                                then
                                    color =
                                        __ESPTVL.SpeciesData[specieType].specieColor
                                else
                                    color = Color3.fromRGB(255, 255, 255)
                                end
                                e.charLabel.RichText = false
                                e.charLabel.Text = charName
                                e.charLabel.TextColor3 = color
                                local specialColor = specialCharColors[charName]
                                if specialColor then
                                    e.charLabel.TextColor3 = specialColor
                                end
                            end
                            -- Update the user label: show star and yellow name if friend
                            do
                                local nameText =
                                    (targetPlayer.DisplayName ~= targetPlayer.Name)
                                    and (
                                        targetPlayer.DisplayName
                                        .. ' ('
                                        .. targetPlayer.Name
                                        .. ')'
                                    )
                                    or targetPlayer.Name
                                if isFriend then
                                    e.userLabel.RichText = true
                                    e.userLabel.Text = "<font color='#FFD700'>★</font> <font color='#FFFF00'>"
                                        .. nameText
                                        .. '</font>'
                                else
                                    e.userLabel.RichText = false
                                    e.userLabel.Text = nameText
                                    -- Default grey colour for non‑friends
                                    e.userLabel.TextColor3 =
                                        Color3.fromRGB(200, 200, 200)
                                end
                            end
                            local tools = getTools(targetPlayer)
                            e.toolLabel.Visible = tools ~= nil
                            if tools then
                                e.toolLabel.Text = tools
                            end
                        end
                    end
                end
                -- Stake ESP
                for obj in pairs(__ESPTVL.stakeObjects) do
                    syncStakeESP(obj)
                    if not obj or not obj.Parent then
                        clearStakeESP(obj)
                    end
                end
            end
        end)
    end

    -- Implementation of cleanup
    cleanupESPTVL = function()
        if not __ESPTVL.enabled then
            return
        end
        __ESPTVL.enabled = false
        for _, conn in pairs(__ESPTVL.connections) do
            if conn then
                conn:Disconnect()
            end
        end
        __ESPTVL.connections = {}
        for _, conns in pairs(__ESPTVL.playerConns) do
            if conns then
                for _, conn in pairs(conns) do
                    if conn then
                        conn:Disconnect()
                    end
                end
            end
        end
        __ESPTVL.playerConns = {}
        for _, entry in pairs(__ESPTVL.esp) do
            if entry and entry.gui then
                pcall(function()
                    entry.gui:Destroy()
                end)
            end
        end
        __ESPTVL.esp = {}
        for obj, gui in pairs(__ESPTVL.stakeESP) do
            if gui then
                pcall(function()
                    gui:Destroy()
                end)
            end
        end
        __ESPTVL.stakeESP = {}
        __ESPTVL.characterNamesCached = {}
        __ESPTVL.specieTypesCached = {}
        __ESPTVL.toolCache = {}
        __ESPTVL.trackedPlayers = {}
        __ESPTVL.stakeObjects = setmetatable({}, { __mode = 'k' })
        -- Clear friend cache and drop the refresh task.  Setting
        -- __ESPTVL.enabled to false causes friendUpdateTask to break
        -- out of its loop naturally; we nil out the references so they
        -- can be garbage collected.
        __ESPTVL.friendStatusCache = {}
        __ESPTVL.friendUpdateTask = nil
        -- Loop will exit automatically when enabled becomes false
    end
end
-- Hitbox expander feature removed as requested

-- Create real Teleport tab
local TeleportTab = CreateDummyTab()
-- Remotes tab is created here so that it appears third in the sidebar.
-- Use a dummy tab for Remotes to remove remote functionality
local RemotesTab = CreateDummyTab()
-- Misc tab will appear last among the functional tabs.
local MiscTab = Window:AddTab({ Title = 'Misc', Icon = 'settings' })

-- 🏛️ TOMB TAB 🏛️
--[[
    The Tomb tab has been disabled by wrapping the entire tomb-related
    code in a multi-line comment. This prevents the tab and its collision
    logic from loading while preserving the original code for reference.
-- Create a new tab dedicated to controlling collisions for parts of Silas' Tomb.
-- When enabled, collisions are disabled for various components (Cog, Net, TunnelDoor,
-- ChannelDoor, CrystalDoor and several thorn parts) and repeatedly enforced in a loop.
-- When disabled, collisions are restored.
local TombTab = Window:AddTab({ Title = 'Tomb', Icon = 'box' })

-- Internal state variables for the tomb collision toggle
local tombCollisionActive = false
local tombCollisionThread = nil

-- Helper to safely set CanCollide property on a part. Uses pcall to prevent
-- runtime errors from halting the rest of the script. If the part is nil or
-- does not support the property, the error will be suppressed.
local function safeSetCollide(part, state)
    if part ~= nil then
        pcall(function()
            -- Use protected call to avoid errors if the part is invalid or missing
            part.CanCollide = state
        end)
    end
end

-- Helper function to set collisions on or off for all targeted objects
local function setTombCollision(state)
    -- state = true means collisions enabled; false disables collisions
    local interactables = workspace:FindFirstChild('Interactables')
    if not interactables then return end
    local silasTomb = interactables:FindFirstChild('SilasTomb')
    if not silasTomb then return end
    -- Cog and its Net
    local cog = silasTomb:FindFirstChild('Cog')
    if cog then
        -- Safely set collisions on both the cog and its net child
        local net = cog:FindFirstChild('Net')
        safeSetCollide(net, state)
        safeSetCollide(cog, state)
    end
    -- TunnelDoor, ChannelDoor, CrystalDoor
    local tunnelDoor = silasTomb:FindFirstChild('TunnelDoor')
    safeSetCollide(tunnelDoor, state)
    local channelDoor = silasTomb:FindFirstChild('ChannelDoor')
    safeSetCollide(channelDoor, state)
    local crystalDoor = silasTomb:FindFirstChild('CrystalDoor')
    safeSetCollide(crystalDoor, state)
    -- Thorns folder and parts
    local thorns = silasTomb:FindFirstChild('Thorns')
    if thorns then
        local thornPart = thorns:FindFirstChild('ThornPart')
        safeSetCollide(thornPart, state)
        -- Index-specific children
        local children = thorns:GetChildren()
        local indices = {8, 4, 6, 5, 7, 3}
        for _, idx in ipairs(indices) do
            local child = children[idx]
            if child and child:IsA('BasePart') then
                safeSetCollide(child, state)
            end
        end
        local thorn2 = thorns:FindFirstChild('Meshes/thorn2')
        if thorn2 and thorn2:IsA('BasePart') then
            safeSetCollide(thorn2, state)
        end
    end
end

-- Create the toggle. The identifier must be unique across all toggles.
local TombCollissionToggle = TombTab:AddToggle('TombCollission', {
    Title = 'Tomb Collission',
    Default = false,
})

-- Toggle callback: enable/disable collisions and start/stop enforcement loop
TombCollissionToggle:OnChanged(function(value)
    tombCollisionActive = value
    if value then
        -- Turn off collisions immediately
        setTombCollision(false)
        -- Start a loop to repeatedly enforce collision off state
        tombCollisionThread = task.spawn(function()
            while tombCollisionActive do
                setTombCollision(false)
                task.wait(1)
            end
        end)
        if not isInitializing then
            Fluent:Notify({
                Title = 'Tomb Collission',
                Content = 'Collision disabled',
                Duration = 2,
            })
        end
    else
        -- Stop loop by flipping active flag; the loop checks the flag each iteration
        -- Restore collisions
        setTombCollision(true)
        if not isInitializing then
            Fluent:Notify({
                Title = 'Tomb Collission',
                Content = 'Collision enabled',
                Duration = 2,
            })
        end
    end
end)
--]] -- end Tomb tab disabled

-- ⚡ AUTOFARM TAB ⚡
-- Use a dummy tab for Autofarm to remove autofarm functionality
local AutofarmTab = CreateDummyTab()

AutofarmTab:AddParagraph({
    Title = 'Blood Bag Collection',
    Content = 'Automatically teleport to fridges and collect blood bags',
})

-- Blood bag collection variables
local bloodBagCollectionActive = false
local bloodBagCollectionThread = nil

-- Blood bag collection toggle
local BloodBagToggle = AutofarmTab:AddToggle('AutoCollectBloodBags', {
    Title = 'Auto Collect Blood Bags',
    Default = false,
})

BloodBagToggle:OnChanged(function(value)
    bloodBagCollectionActive = value
    _G.collectBloodBags = value

    if value then
        Fluent:Notify({
            Title = 'Auto Collect Blood Bags',
            Content = 'Blood bag collection started!',
            Duration = 3,
        })

        -- Start collection in a separate thread
        bloodBagCollectionThread = task.spawn(function()
            local TweenService = game:GetService('TweenService')
            local Players = game:GetService('Players')

            local player = Players.LocalPlayer
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoidRootPart = character:WaitForChild('HumanoidRootPart')

            local fridgesFolder = workspace.Interactables.Fridges
            local fridges = fridgesFolder:GetChildren()

            -- Tween settings
            local tweenInfo = TweenInfo.new(
                1, -- Duration in seconds
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out,
                0, -- Repeat count
                false, -- Reverse
                0 -- Delay
            )

            local function tweenToPosition(targetPosition)
                if not _G.collectBloodBags then
                    return
                end
                local tween = TweenService:Create(
                    humanoidRootPart,
                    tweenInfo,
                    { CFrame = CFrame.new(targetPosition) }
                )

                tween:Play()
                tween.Completed:Wait()
            end

            local function spamAllProximityPrompts(prompts, duration)
                local endTime = tick() + duration
                while tick() < endTime and _G.collectBloodBags do
                    -- Fire all prompts at once
                    for _, promptData in ipairs(prompts) do
                        fireproximityprompt(promptData.prompt)
                    end
                    task.wait(0.01) -- Wait between volleys
                end
            end

            print('Starting blood bag collection...')

            -- Continuous loop controlled by _G variable
            while _G.collectBloodBags do
                -- Loop through all fridges
                for index, fridge in ipairs(fridges) do
                    if not _G.collectBloodBags then
                        break
                    end

                    local success, err = pcall(function()
                        -- Get the fridge model position
                        if fridge:IsA('Model') and fridge.PrimaryPart then
                            local fridgePos = fridge.PrimaryPart.Position
                            local targetPos = fridgePos + Vector3.new(0, 10, 0) -- 10 studs above the model

                            print(
                                string.format(
                                    'Teleporting to fridge %d/%d...',
                                    index,
                                    #fridges
                                )
                            )

                            -- Tween to the fridge
                            tweenToPosition(targetPos)
                        elseif fridge:IsA('Model') then
                            -- If no PrimaryPart, get the center of the model's bounding box
                            local cf, size = fridge:GetBoundingBox()
                            local targetPos = cf.Position
                                + Vector3.new(0, size.Y / 2 + 5, 0)

                            print(
                                string.format(
                                    'Teleporting to fridge %d/%d...',
                                    index,
                                    #fridges
                                )
                            )

                            -- Tween to the fridge
                            tweenToPosition(targetPos)

                            -- Wait a moment for the game to register position
                            task.wait(0.2)

                            -- Now check if this fridge has any blood bags
                            local itemSpawns =
                                fridge:FindFirstChild('ItemSpawns')
                            local bloodBagPrompts = {}

                            if itemSpawns then
                                -- Check all spawn points (1, 2, 3, etc.) for blood bags
                                for _, spawnPoint in
                                    pairs(itemSpawns:GetChildren())
                                do
                                    local bloodBag =
                                        spawnPoint:FindFirstChild('BloodBag')
                                    if bloodBag then
                                        local toolPrompt =
                                            bloodBag:FindFirstChild(
                                                'ToolPrompt'
                                            )
                                        if
                                            toolPrompt
                                            and toolPrompt:IsA(
                                                'ProximityPrompt'
                                            )
                                        then
                                            table.insert(bloodBagPrompts, {
                                                prompt = toolPrompt,
                                                name = spawnPoint.Name,
                                            })
                                        end
                                    end
                                end
                            end

                            -- If blood bags found, spam the prompts
                            if #bloodBagPrompts > 0 then
                                print(
                                    string.format(
                                        'Collecting %d blood bags from fridge %d...',
                                        #bloodBagPrompts,
                                        index
                                    )
                                )
                                for _, promptData in ipairs(bloodBagPrompts) do
                                    print(
                                        string.format(
                                            '  - Found spawn point %s',
                                            promptData.name
                                        )
                                    )
                                end
                                spamAllProximityPrompts(bloodBagPrompts, 2) -- Spam all for 2 seconds
                            else
                                print(
                                    string.format(
                                        'No blood bags at fridge %d',
                                        index
                                    )
                                )
                            end

                            task.wait(0.2) -- Wait before moving to next fridge
                        else
                            warn(
                                string.format(
                                    'Fridge %d is not a valid model',
                                    index
                                )
                            )
                        end
                    end)

                    if not success then
                        warn(
                            string.format(
                                'Error processing fridge %d: %s',
                                index,
                                err
                            )
                        )
                    end
                end

                if _G.collectBloodBags then
                    print('Completed one cycle, restarting...')
                    task.wait(1) -- Small delay before restarting the cycle
                end
            end

            print('Blood bag collection stopped!')
        end)
    else
        Fluent:Notify({
            Title = 'Auto Collect Blood Bags',
            Content = 'Blood bag collection stopped!',
            Duration = 3,
        })

        -- Stop the collection thread
        if bloodBagCollectionThread then
            task.cancel(bloodBagCollectionThread)
            bloodBagCollectionThread = nil
        end
    end
end)

-- ⚡ AUTO-DEPLOY SYSTEM ⚡
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local lp = Players.LocalPlayer or (function()
    -- Double-check LocalPlayer exists
    local player
    while not player do
        player = Players.LocalPlayer
        if not player then task.wait(0.05) end
    end
    return player
end)()
local spawnFunc, confirmFunc, yesFunc
local heartbeatConn
local running = false
local charAddedConn
local selectionChangeConn2
local selectionChangeConn3
local isInitialized = false
local initializationJobActive = false
local cachedSpawnFunc, cachedConfirmFunc, cachedYesFunc = nil, nil, nil
-- Increase spam counts for faster deployment (more confirmations). Higher values mean
-- more confirm clicks will be fired in a short amount of time, which can help
-- complete the spawn/confirm sequence faster. Adjust as needed for your hardware.
local CONFIRM_SPAM_COUNT = 500000  -- ABSOLUTE MAXIMUM: Overwhelming spam speed
local HEARTBEAT_SPAM_COUNT = 100  -- Reduced for INSTANT stop (checks running flag every 100 ops)

-- helper to safely get function name info
local getInfo = debug and debug.getinfo or getinfo

-- Helper to read the selected character name from the UI label safely.
local function getSelectionName(label)
    if not label then
        return nil
    end
    local ok, value = pcall(function()
        return label.ContentText
    end)
    if ok and value and value ~= '' then
        return value
    end
    local ok2, value2 = pcall(function()
        return label.Text
    end)
    if ok2 and value2 and value2 ~= '' then
        return value2
    end
    return nil
end

-- Helper to read the selected character label text from the UI.
local function getSelectedCharacterText()
    local ok, value = pcall(function()
        local pg = game:GetService('Players').LocalPlayer.PlayerGui
        local ss = pg:FindFirstChild('StartScreen')
        local mh = ss and ss:FindFirstChild('MainHolder')
        local scf = mh and mh:FindFirstChild('SelectCharacterFrame')
        local la = scf and scf:FindFirstChild('LeftArea')
        local ma = la and la:FindFirstChild('MiddleArea')
        local ta = ma and ma:FindFirstChild('TopArea')
        local label = ta and ta:FindFirstChild('SelectedCharacter')
        if not label then
            return nil
        end
        return label.ContentText or label.Text
    end)
    if ok and value and value ~= '' then
        return value
    end
    return nil
end

-- Wait for game to be fully loaded
if not game:IsLoaded() then
    print('[AUTO-DEPLOY] Waiting for game to load...')
    game.Loaded:Wait()
    -- ABSOLUTE MAXIMUM: No wait time at all
    print('[AUTO-DEPLOY] Game loaded!')
end

-- Initialize function scanner (ULTRA-OPTIMIZED for obfuscated code)
local function initializeAutoDeployFunctions(force)
    if initializationJobActive and not force then
        return
    end
    if initializationJobActive then
        return
    end
    initializationJobActive = true
    spawnFunc, confirmFunc, yesFunc = nil, nil, nil

    task.spawn(function()
        print('[AUTO-DEPLOY] Starting optimized GC scan...')
        local startTime = tick()
        local gc = getgc and getgc(true) or {}
        local totalItems = #gc
        print('[AUTO-DEPLOY] Scanning ' .. totalItems .. ' items in GC...')

        -- Store ALL instances
        local spawnFuncs = {}
        local confirmFuncs = {}
        local yesFuncs = {}

        -- OPTIMIZATION: Process in larger batches with less frequent yields
        local BATCH_SIZE = 100000 -- ABSOLUTE MAXIMUM: Process 100k items before yielding
        local foundAll = false

        for batchStart = 1, totalItems, BATCH_SIZE do
            if foundAll then
                break
            end

            local batchEnd = math.min(batchStart + BATCH_SIZE - 1, totalItems)

            -- Process entire batch without yielding
            for i = batchStart, batchEnd do
                local v = gc[i]
                if type(v) == 'function' then
                    local ok, info = pcall(getInfo, v)
                    if ok and info and info.name then
                        if info.name == 'spawnButtonActivated' then
                            table.insert(spawnFuncs, v)
                            print(
                                '[GC] Found spawnButtonActivated #'
                                    .. #spawnFuncs
                                    .. ' at index '
                                    .. i
                            )
                        elseif info.name == 'confirmPressed' then
                            table.insert(confirmFuncs, v)
                            print(
                                '[GC] Found confirmPressed #'
                                    .. #confirmFuncs
                                    .. ' at index '
                                    .. i
                            )
                        elseif info.name == 'yesButtonActivated' then
                            table.insert(yesFuncs, v)
                            print(
                                '[GC] Found yesButtonActivated #'
                                    .. #yesFuncs
                                    .. ' at index '
                                    .. i
                            )
                        end

                        -- OPTIMIZATION: Break early if all 3 functions found
                        if
                            #spawnFuncs > 0
                            and #confirmFuncs > 0
                            and #yesFuncs > 0
                        then
                            print(
                                '[AUTO-DEPLOY] All required functions found at index '
                                    .. i
                                    .. '/'
                                    .. totalItems
                                    .. ' - stopping scan early'
                            )
                            foundAll = true
                            break
                        end
                    end
                end
            end

            -- Only yield after processing entire batch (much less frequent)
            if not foundAll and batchEnd < totalItems then
                task.wait() -- Minimal yield to prevent timeout
            end
        end

        print(
            '[AUTO-DEPLOY] Scan complete - Found '
                .. #spawnFuncs
                .. ' spawn, '
                .. #confirmFuncs
                .. ' confirm, '
                .. #yesFuncs
                .. ' yes functions'
        )

        -- Try ALL instances - create a wrapper that calls all of them
        if #spawnFuncs > 0 then
            local allSpawns = spawnFuncs
            spawnFunc = function()
                for i, func in ipairs(allSpawns) do
                    pcall(func)
                end
            end
            print(
                '[AUTO-DEPLOY] Created spawn wrapper calling ALL '
                    .. #spawnFuncs
                    .. ' instances'
            )
        end

        if #confirmFuncs > 0 then
            local allConfirms = confirmFuncs
            confirmFunc = function()
                for i, func in ipairs(allConfirms) do
                    pcall(func)
                end
            end
            print(
                '[AUTO-DEPLOY] Created confirm wrapper calling ALL '
                    .. #confirmFuncs
                    .. ' instances'
            )
        end

        if #yesFuncs > 0 then
            local allYes = yesFuncs
            yesFunc = function()
                for i, func in ipairs(allYes) do
                    pcall(func)
                end
            end
            print(
                '[AUTO-DEPLOY] Created yes wrapper calling ALL '
                    .. #yesFuncs
                    .. ' instances'
            )
        end

        local scanTime = tick() - startTime
        print(
            '[AUTO-DEPLOY] GC scan completed in '
                .. string.format('%.2f', scanTime)
                .. ' seconds'
        )

        if not spawnFunc then
            warn('spawnButtonActivated not found in getgc')
        else
            print('[GC] spawnFunc ready')
        end
        if not confirmFunc then
            warn('confirmPressed not found in getgc')
        else
            print('[GC] confirmFunc ready')
        end
        if not yesFunc then
            warn(
                'yesButtonActivated not found in getgc - will spam all three anyway'
            )
        else
            print('[GC] yesFunc ready')
        end
        -- Set initialization state only when both spawn and confirm functions are found.
        -- If either is missing, leave isInitialized false so that the script can retry
        -- scanning on the next attempt. This prevents premature starts when
        -- functions haven’t been loaded yet and avoids missing confirmations.
        if spawnFunc and confirmFunc then
            isInitialized = true
            cachedSpawnFunc = spawnFunc
            cachedConfirmFunc = confirmFunc
            cachedYesFunc = yesFunc
            print('[AUTO-DEPLOY] Initialization complete!')
        else
            isInitialized = false
            print(
                '[AUTO-DEPLOY] Initialization incomplete; will retry on next toggle.'
            )
        end
        initializationJobActive = false
    end)
end

-- NO initial scan - only scan when J is pressed
-- This prevents issues if script is executed too early
print('[AUTO-DEPLOY] Ready. Press J to scan and deploy.')

-- stop function (disconnect heartbeat and char listener)
local function stopSpammer(reason)
    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    if charAddedConn then
        charAddedConn:Disconnect()
        charAddedConn = nil
    end
    if colorCheckConnection then
        colorCheckConnection:Disconnect()
        colorCheckConnection = nil
    end
    if selectionChangeConn then
        selectionChangeConn:Disconnect()
        selectionChangeConn = nil
    end
    if selectionChangeConn2 then
        selectionChangeConn2:Disconnect()
        selectionChangeConn2 = nil
    end
    if selectionChangeConn3 then
        selectionChangeConn3:Disconnect()
        selectionChangeConn3 = nil
    end
    if selectionChangeConn3 then
        selectionChangeConn3:Disconnect()
        selectionChangeConn3 = nil
    end
    running = false
    isWaiting = false

    if reason then
        print('Auto-deploy stopped:', reason)
    else
        print('Auto-deploy stopped')
    end

    -- Update status label IMMEDIATELY when stopping
    if StatusLabel then
        UpdateStatus('Status: Inactive')
    end

    -- Only show notification if not a silent stop
    if reason and reason ~= 'silent' then
        Fluent:Notify({
            Title = '⚡ Auto Deploy Stopped',
            Content = reason or 'Deactivated',
            Duration = 2,
        })
    end

    -- Re-initialize functions after stopping regardless of the reason.
end

-- start function (connect Heartbeat and CharacterAdded)
local function startSpammer()
    if running then
        return
    end

    -- INSTANT ACTIVATION: Set running flag IMMEDIATELY
    running = true

    if selectionChangeConn then
        selectionChangeConn:Disconnect()
        selectionChangeConn = nil
    end
    if selectionChangeConn2 then
        selectionChangeConn2:Disconnect()
        selectionChangeConn2 = nil
    end
    do
        local pg = lp:FindFirstChild('PlayerGui')
        local ss = pg and pg:FindFirstChild('StartScreen')
        local mh = ss and ss:FindFirstChild('MainHolder')
        local nameLabel = mh and mh:FindFirstChild('CharacterInfo')
            and mh.CharacterInfo:FindFirstChild('PlayerName')
        local selectedName = getSelectionName(nameLabel)
        local selectedCharLabel
        local initialSelectedText = ''
        pcall(function()
            local scf = mh and mh:FindFirstChild('SelectCharacterFrame')
            local la = scf and scf:FindFirstChild('LeftArea')
            local ma = la and la:FindFirstChild('MiddleArea')
            local ta = ma and ma:FindFirstChild('TopArea')
            selectedCharLabel = ta and ta:FindFirstChild('SelectedCharacter')
            initialSelectedText = selectedCharLabel and (selectedCharLabel.ContentText or selectedCharLabel.Text) or ''
        end)
        local initialContentText = ''
        pcall(function()
            initialContentText = nameLabel and nameLabel.ContentText or ''
        end)
        if nameLabel then
            selectionChangeConn =
                nameLabel:GetPropertyChangedSignal('Text'):Connect(
                    function()
                        if not running then
                            return
                        end
                        local newName = getSelectionName(nameLabel)
                        local currentContentText = ''
                        pcall(function()
                            currentContentText = nameLabel.ContentText or ''
                        end)
                        if initialContentText ~= '' and currentContentText ~= '' and currentContentText ~= initialContentText then
                            stopSpammer('selection changed')
                            return
                        end
                        if selectedName and newName and newName ~= selectedName then
                            stopSpammer('selection changed')
                        end
                    end
                )
            -- Also watch ContentText if the label uses rich text or custom rendering.
            pcall(function()
                selectionChangeConn2 =
                    nameLabel:GetPropertyChangedSignal('ContentText'):Connect(
                        function()
                            if not running then
                                return
                            end
                            local currentContentText = nameLabel.ContentText or ''
                            if initialContentText ~= '' and currentContentText ~= '' and currentContentText ~= initialContentText then
                                stopSpammer('selection changed')
                                return
                            end
                            local newName = getSelectionName(nameLabel)
                            if selectedName and newName and newName ~= selectedName then
                                stopSpammer('selection changed')
                            end
                        end
                    )
            end)
        end
        if selectedCharLabel then
            selectionChangeConn3 =
                selectedCharLabel:GetPropertyChangedSignal(
                    'ContentText'
                ):Connect(function()
                    if not running then
                        return
                    end
                    local currentText =
                        selectedCharLabel.ContentText or selectedCharLabel.Text or ''
                    if initialSelectedText ~= ''
                        and currentText ~= ''
                        and currentText ~= initialSelectedText
                    then
                        stopSpammer('selection changed')
                    end
                end)
        end
    end

    -- INSTANT ACTIVATION: Use cached functions directly (already verified during initialization)
    if cachedSpawnFunc and cachedConfirmFunc then
        spawnFunc, confirmFunc, yesFunc =
            cachedSpawnFunc, cachedConfirmFunc, cachedYesFunc
    else
        -- Fallback to current functions if cache missing
        if not (spawnFunc and confirmFunc) then
            warn('[AUTO-DEPLOY] No functions available for instant spam!')
            running = false
            return
        end
    end

    -- INSTANT ACTIVATION: Fire spawn function IMMEDIATELY (no checks, no waits)
    if spawnFunc then
        pcall(spawnFunc)
    end

    -- INSTANT ACTIVATION: Start confirm spam burst IMMEDIATELY
    if confirmFunc then
        task.spawn(function()
            local batchSize = 100  -- Check running flag every 100 operations for instant stop
            for i = 1, CONFIRM_SPAM_COUNT do
                if not running then
                    print('[AUTO-DEPLOY] Background spam stopped at iteration ' .. i)
                    break
                end
                pcall(confirmFunc)
                if i % batchSize == 0 then
                    if not running then
                        print('[AUTO-DEPLOY] Background spam stopped at batch ' .. i)
                        break
                    end  -- Extra check before yielding
                    task.wait()
                end
            end
            print('[AUTO-DEPLOY] Background spam completed or stopped')
            -- Try Yes button after confirms
            if yesFunc and running then
                pcall(yesFunc)
            end
        end)
    end

    -- INSTANT ACTIVATION: Start heartbeat spam IMMEDIATELY
    if heartbeatConn then
        heartbeatConn:Disconnect()
    end

    local startTime = tick()

    -- Helper: detect screen transition
    local function isScreenTransitionActive()
        local active = false
        pcall(function()
            local pg = lp:FindFirstChild('PlayerGui')
            local su = pg and pg:FindFirstChild('ScreenUtils')
            local st = su and su:FindFirstChild('ScreenTransition')
            if st and st.Active ~= nil then
                active = st.Active == true
            end
        end)
        return active
    end

    -- Helper: click Yes button
    local function clickYesOnce()
        pcall(function()
            local mainHolder = lp.PlayerGui.StartScreen.MainHolder
            local confirmFrame = mainHolder and mainHolder:FindFirstChild('ConfirmFrame')
            if confirmFrame and confirmFrame.Visible then
                local yesButton = confirmFrame:FindFirstChild('Yes')
                if yesButton and yesButton.Visible and getconnections then
                    for _, connection in pairs(getconnections(yesButton.MouseButton1Click)) do
                        pcall(function()
                            connection:Fire()
                        end)
                    end
                    for _, connection in pairs(getconnections(yesButton.Activated)) do
                        pcall(function()
                            connection:Fire()
                        end)
                    end
                end
            end
        end)
    end

    heartbeatConn = RunService.Heartbeat:Connect(function()
        if not running then
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
            return
        end

        -- Stop if screen transition is active
        if isScreenTransitionActive() then
            running = false
            isWaiting = false
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
            if charAddedConn then
                charAddedConn:Disconnect()
                charAddedConn = nil
            end
            if StatusLabel then
                UpdateStatus('Status: Spawning...')
            end
            return
        end

        -- Spam confirm every frame
        if confirmFunc then
            for _ = 1, HEARTBEAT_SPAM_COUNT do
                if not running then
                    break
                end
                pcall(confirmFunc)
            end
        end

        -- Try Yes button every frame
        if yesFunc then
            pcall(yesFunc)
        end
        clickYesOnce()

        -- Safety timeout
        if (tick() - startTime) > 8 then
            running = false
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
        end
    end)

    -- ALL NON-CRITICAL OPERATIONS DEFERRED (run in background, don't block spam)
    task.defer(function()
        -- Get character name for notifications
        local characterName = 'Unknown'
        pcall(function()
            characterName =
                lp.PlayerGui.StartScreen.MainHolder.CharacterInfo.PlayerName.ContentText
        end)

        -- Show notification
        pcall(function()
            Fluent:Notify({
                Title = '⚡ Deploying as...',
                Content = characterName,
                Duration = 3,
                Image = 4483362458,
            })
        end)

        -- Update status
        if StatusLabel then
            UpdateStatus('Status: Active (one-shot)')
        end

        print('[AUTO-DEPLOY] Instant spam activated for: ' .. characterName)
    end)

    -- stop automatically when character spawns (silently) - INSTANT STOP
    if lp then
        -- INSTANT STOP function - called by multiple detections
        local function stopEverything()
            if not running then return end -- Already stopped

            print('[AUTO-DEPLOY] Character spawned - INSTANT STOP')

            -- Stop IMMEDIATELY - set flag FIRST
            running = false
            isWaiting = false

            -- Disconnect ALL connections immediately
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
            if charAddedConn then
                charAddedConn:Disconnect()
                charAddedConn = nil
            end
            if colorCheckConnection then
                colorCheckConnection:Disconnect()
                colorCheckConnection = nil
            end

            -- Background: Update status (non-blocking)
            task.defer(function()
                pcall(function()
                    local pg = lp:FindFirstChild('PlayerGui')
                    if pg and pg:FindFirstChild('StartScreen') then
                        local spawnedCharName = pg.StartScreen.MainHolder.CharacterInfo.PlayerName.ContentText
                        if StatusLabel then
                            UpdateStatus('Status: Spawned as ' .. spawnedCharName)
                        end
                        print('[AUTO-DEPLOY] Status updated to: Spawned as ' .. spawnedCharName)
                    end
                end)
            end)
        end

        -- Method 1: Detect ScreenTransition.Active = true (INSTANT - happens the moment spawn starts)
        local screenTransitionConn = nil
        pcall(function()
            local screenTransition = lp.PlayerGui:WaitForChild("ScreenUtils"):WaitForChild("ScreenTransition")
            screenTransitionConn = screenTransition:GetPropertyChangedSignal("Active"):Connect(function()
                if screenTransition.Active == true then
                    print('[AUTO-DEPLOY] ScreenTransition.Active = true - STOPPING INSTANTLY')
                    if screenTransitionConn then screenTransitionConn:Disconnect() screenTransitionConn = nil end
                    stopEverything()
                end
            end)
        end)

        -- Method 2: Detect StartScreen closing (INSTANT - happens the moment you spawn)
        local startScreenConn = nil
        pcall(function()
            local startScreen = lp.PlayerGui:WaitForChild("StartScreen")
            startScreenConn = startScreen:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not startScreen.Enabled then
                    print('[AUTO-DEPLOY] StartScreen closed - STOPPING INSTANTLY')
                    if startScreenConn then startScreenConn:Disconnect() startScreenConn = nil end
                    stopEverything()
                end
            end)
        end)

        -- Method 3: Hook CharacterSelectedFunction remote (INSTANT detection before spawn)
        pcall(function()
            local remoteFunc = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("GameServices"):WaitForChild("ToServer"):WaitForChild("CharacterSelectedFunction")
            if hookmetamethod then
                local oldNamecall
                oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if self == remoteFunc and (method == "InvokeServer" or method == "invokeServer") then
                        print('[AUTO-DEPLOY] CharacterSelectedFunction called - STOPPING INSTANTLY')
                        stopEverything()
                    end
                    return oldNamecall(self, ...)
                end)
            end
        end)

        -- Method 4: CharacterAdded event (fires when character object is created)
        charAddedConn = lp.CharacterAdded:Connect(stopEverything)

        -- Method 5: Poll for character existence (catches if event is missed)
        local charCheckConn = RunService.RenderStepped:Connect(function()
            if lp.Character then
                if charCheckConn then
                    charCheckConn:Disconnect()
                    charCheckConn = nil
                end
                stopEverything()
            end
        end)
    end
end

--
-- Synchronize the status label with the player's spawn state.
-- When the character spawns (regardless of how the auto deploy was
-- stopped), update the status label to "Spawned". This ensures
-- the UI accurately reflects the fact that you have spawned into the
-- game and avoids stale "waiting" messages lingering after a
-- successful deploy. We connect this handler once up front so it
-- always fires when the local character is added.
do
    local player = game:GetService('Players').LocalPlayer
    -- A separate connection outside of auto‑deploy ensures the label
    -- updates even if the auto‑deploy logic fails to change the label.
    player.CharacterAdded:Connect(function(character)
        if StatusLabel then
            -- Try to get character name from UI
            local charName = 'Unknown'
            pcall(function()
                local pg = player:FindFirstChild('PlayerGui')
                if pg then
                    local startScreen = pg:FindFirstChild('StartScreen')
                    if startScreen then
                        charName =
                            startScreen.MainHolder.CharacterInfo.PlayerName.ContentText
                    end
                end
            end)
            UpdateStatus('Status: Spawned as ' .. charName)
        end
    end)

    -- Monitor for character selection screen visibility
    task.spawn(function()
        while true do
            task.wait(1) -- MAXIMUM SPEED: Check every 1 second

            -- Only update if not in any active auto-deploy process and not waiting
            if StatusLabel and not running and not isWaiting then
                -- Get current status to avoid overriding important states
                local currentStatus = StatusLabel.Content or ''

                -- Don't override if status contains "Waiting", "Spawning", "Active", or "Confirming"
                local shouldNotOverride = currentStatus:find('Waiting')
                    or currentStatus:find('Spawning')
                    or currentStatus:find('Active')
                    or currentStatus:find('Confirming')

                if not shouldNotOverride then
                    local pg = player:FindFirstChild('PlayerGui')
                    if pg then
                        local startScreen = pg:FindFirstChild('StartScreen')
                        if startScreen then
                            local mainHolder =
                                startScreen:FindFirstChild('MainHolder')
                            if mainHolder then
                                local selectFrame = mainHolder:FindFirstChild(
                                    'SelectCharacterFrame'
                                )
                                if selectFrame and selectFrame.Visible then
                                    -- Character selection screen is visible and status is idle
                                    UpdateStatus('Status: In lobby')
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local AutoDeployButton = MainTab:AddButton({
    Title = 'Auto Deploy (J)',
    Callback = function()
        Fluent:Notify({
            Title = 'Auto Deploy',
            Content = 'Press J to toggle Auto Deploy',
            Duration = 2,
        })
    end,
})

-- toggle on J
local colorCheckConnection = nil
local isWaiting = false

-- Scope-safe lobby checker (doesn't rely on other locals)
local function InLobbySafe()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild('PlayerGui')
    if pg then
        local names = {
            'StartScreen',
            'Lobby',
            'LobbyUI',
            'LobbyScreen',
            'Menu',
            'MainMenu',
        }
        for _, n in ipairs(names) do
            if pg:FindFirstChild(n) then
                return true
            end
        end
    end
    -- If no character or dead, treat as lobby/menu state
    local c = LocalPlayer and LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass('Humanoid')
    if not (c and h and h.Health > 0) then
        return true
    end
    return false
end

-- Add debounce for J key to prevent spam
local lastJPress = 0
-- 3 second cooldown to prevent double spams and bugs
local J_DEBOUNCE = 1.5 -- 3000ms cooldown

UserInputService.InputBegan:Connect(function(inp, gameProcessed)
    -- Ignore input if Roblox processed it or hotkeys are disabled
    if gameProcessed then
        return
    end
    if not hotkeysEnabled then
        return
    end
    -- Check for the J key after initialization
    if inp.KeyCode == Enum.KeyCode.J then
        -- Block J key until script is fully initialized
        if not _G.__SCRIPT_FULLY_INITIALIZED then
            Fluent:Notify({
                Title = 'Please Wait',
                Content = 'Script is still initializing... Please wait.',
                Duration = 2,
            })
            return
        end

        -- Debounce check
        local now = tick()
        if now - lastJPress < J_DEBOUNCE then
            return
        end
        lastJPress = now
        -- Spawn-safe guard: if already spawned, don't attempt lobby UI logic.
        -- Arm auto-deploy for the next time StartScreen/Lobby appears instead.
        do
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass('Humanoid')
            if char and hum and hum.Health > 0 and not InLobbySafe() then
                -- Get character name
                local charName = 'Unknown'
                pcall(function()
                    local pg = LocalPlayer:FindFirstChild('PlayerGui')
                    if pg then
                        local startScreen = pg:FindFirstChild('StartScreen')
                        if startScreen then
                            charName =
                                startScreen.MainHolder.CharacterInfo.PlayerName.ContentText
                        end
                    end
                end)

                Fluent:Notify({
                    Title = 'Auto Deploy',
                    Content = 'You are already spawned. Auto‑deploy will arm for next lobby/respawn.',
                    Duration = 3,
                })
                if StatusLabel then
                    UpdateStatus('Status: Spawned as ' .. charName)
                end
                local pg = LocalPlayer:FindFirstChild('PlayerGui')
                if pg then
                    if _G.__AD_ArmConn then
                        pcall(function()
                            _G.__AD_ArmConn:Disconnect()
                        end)
                    end
                    _G.__AD_ArmConn = pg.ChildAdded:Connect(function(child)
                        if
                            child
                            and (
                                child.Name == 'StartScreen'
                                or child.Name == 'Lobby'
                                or child.Name == 'LobbyUI'
                                or child.Name == 'LobbyScreen'
                            )
                        then
                            if _G.__AD_ArmConn then
                                pcall(function()
                                    _G.__AD_ArmConn:Disconnect()
                                end)
                                _G.__AD_ArmConn = nil
                            end
                            task.delay(0.1, function()
                                local c = LocalPlayer.Character
                                local h = c
                                    and c:FindFirstChildOfClass('Humanoid')
                                -- Only start spammer if we are no longer spawned (i.e., back at lobby)
                                if not (c and h and h.Health > 0) then
                                    isWaiting = false
                                    if type(startSpammer) == 'function' then
                                        startSpammer()
                                    elseif
                                        type(StartAutoDeploy) == 'function'
                                    then
                                        StartAutoDeploy(true)
                                    end
                                end
                            end)
                        end
                    end)
                end
                return
            end
        end

        -- Verify game is fully loaded before scanning
        if not game:IsLoaded() then
            Fluent:Notify({
                Title = 'Auto Deploy',
                Content = 'Game is still loading. Please wait...',
                Duration = 3,
            })
            return
        end

        -- CRITICAL: Wait for character selection UI to be fully loaded
        print('[AUTO-DEPLOY] Waiting for UI to be ready...')
        local uiReady = false
        -- Reduce the overall timeout and check more frequently so the auto‑deploy
        -- begins scanning sooner. The UI on modern systems usually loads within
        -- a couple of seconds, so a 6‑second cap with a 0.1s poll strikes a
        -- balance between responsiveness and stability.
        local maxUIWait = 6
        local uiWaited = 0

        while not uiReady and uiWaited < maxUIWait do
            local ok = pcall(function()
                local pg = lp:FindFirstChild('PlayerGui')
                local ss = pg and pg:FindFirstChild('StartScreen')
                local mh = ss and ss:FindFirstChild('MainHolder')
                local scf = mh and mh:FindFirstChild('SelectCharacterFrame')
                local spawn = scf
                    and scf:FindFirstChild('LeftArea')
                    and scf.LeftArea:FindFirstChild('BottomArea')
                    and scf.LeftArea.BottomArea:FindFirstChild('Spawn')

                if spawn then
                    uiReady = true
                end
            end)

            if not uiReady then
                -- Poll more frequently for the UI so we can move on as soon as it appears.
                task.wait(0.1)
                uiWaited = uiWaited + 0.1
                print('[AUTO-DEPLOY] Waiting for UI... (' .. uiWaited .. 's)')
            end
        end

        if not uiReady then
            Fluent:Notify({
                Title = 'Auto Deploy',
                Content = 'Character selection UI not ready. Please wait and try again.',
                Duration = 4,
            })
            print('[AUTO-DEPLOY] UI not ready after ' .. uiWaited .. ' seconds')
            return
        end

        print('[AUTO-DEPLOY] UI is ready! Waiting 0.3s to ensure all checks are loaded...')
        -- Wait 0.3 seconds to ensure all checks are loaded and everything is ready
        task.wait(0.3)
        print('[AUTO-DEPLOY] Starting GC scan...')

        -- ALWAYS reinitialize on every J press (as requested)
        print(
            '[AUTO-DEPLOY] Reinitializing - scanning entire GC for functions...'
        )

        -- Reset and force new scan EVERY TIME
        isInitialized = false
        initializationJobActive = false
        spawnFunc = nil
        confirmFunc = nil
        yesFunc = nil

        -- Start the scan
        initializeAutoDeployFunctions(true)

        -- Wait for scan to complete with faster polling
        local maxWait = 2  -- ABSOLUTE MAXIMUM: 2s timeout
        local waited = 0
        while
            (not isInitialized or not spawnFunc or not confirmFunc)
            and waited < maxWait
        do
            -- ABSOLUTE MAXIMUM: Poll every 0.005s (200 checks/second)
            task.wait(0.005)
            waited = waited + 0.005

            -- Show progress roughly every 2 seconds.  Multiply by 20 (since
            -- waited increments by 0.05s) and check modulo 40 to get a
            -- consistent interval even with floating point increments.
            local w10 = math.floor(waited * 20)
            if w10 % 40 == 0 then
                print('[AUTO-DEPLOY] Still scanning... (' .. string.format('%.2f', waited) .. 's)')
            end
        end

        -- Check if scan was successful
        if not isInitialized or not spawnFunc or not confirmFunc then
            Fluent:Notify({
                Title = 'Auto Deploy',
                Content = 'Functions not found. Game may not be ready. Wait and try again.',
                Duration = 4,
            })
            print(
                '[AUTO-DEPLOY] Scan failed - functions not found after '
                    .. waited
                    .. ' seconds'
            )
            print(
                '[AUTO-DEPLOY] This may happen if script was executed too early'
            )
            print('[AUTO-DEPLOY] Wait a few seconds and press J again')
            return
        end

        print('[AUTO-DEPLOY] Functions found! Starting deployment...')

        -- Check if waiting and cancel it
        if isWaiting then
            -- If already waiting, pressing J again cancels the wait
            print('[DEBUG] Cancelled waiting for button')
            Fluent:Notify({
                Title = '❌ Auto Deploy Cancelled',
                Content = 'Stopped waiting for button',
                Duration = 2,
            })
            if colorCheckConnection then
                colorCheckConnection:Disconnect()
                colorCheckConnection = nil
            end
            if selectionChangeConn then
                selectionChangeConn:Disconnect()
                selectionChangeConn = nil
            end
            isWaiting = false
            UpdateStatus('Status: Inactive')
        else
            -- Enhanced checks before starting
            local success, errorMsg = pcall(function()
                -- First, verify the UI exists
                local startScreen = lp.PlayerGui:FindFirstChild('StartScreen')
                if not startScreen then
                    error(
                        'StartScreen not found - are you on the spawn screen?'
                    )
                end

                local mainHolder = startScreen:FindFirstChild('MainHolder')
                if not mainHolder then
                    error('MainHolder not found')
                end

                local selectFrame =
                    mainHolder:FindFirstChild('SelectCharacterFrame')
                if not selectFrame then
                    error(
                        'SelectCharacterFrame not found - you may not be on the character selection screen'
                    )
                end

                -- Check if the frame is actually visible
                if not selectFrame.Visible then
                    error('Character selection screen is not visible')
                end

                local spawn =
                    selectFrame.LeftArea.BottomArea:FindFirstChild('Spawn')
                if not spawn then
                    error('Spawn button not found in UI')
                end

                local color = spawn.ImageColor3
                local r, g, b =
                    math.floor(color.R * 255),
                    math.floor(color.G * 255),
                    math.floor(color.B * 255)

                print('[DEBUG] Current button color RGB:', r, g, b)

                -- Check if button is greyed out or dark (waiting for character to unlock)
                if
                    (r == 72 and g == 72 and b == 72)
                    or (r < 100 and g < 100 and b < 100)
                then
                    print(
                        '[DEBUG] Button is greyed out (RGB: '
                            .. r
                            .. ','
                            .. g
                            .. ','
                            .. b
                            .. ') - waiting for it to become available...'
                    )

                    local characterName = 'Unknown'
                    pcall(function()
                        characterName =
                            mainHolder.CharacterInfo.PlayerName.ContentText
                    end)

                    isWaiting = true
                    Fluent:Notify({
                        Title = '⏳ Auto Deploy',
                        Content = 'Waiting for '
                            .. characterName
                            .. ' to unlock...',
                        Duration = 3,
                    })
                    UpdateStatus(
                        'Status: Waiting for '
                            .. characterName
                            .. ' to unlock...'
                    )

                    local initialCharacterName = characterName
                    local takenAnnouncement = mainHolder.CharacterInfoMiddle.TakenAnnouncement
                    local renderStepName = nil
                    local selectionStepName = nil
                    local textChangedConn = nil
                    local textContentConn = nil
                    local textAnyConn = nil
                    local selectionVisibleConn = nil
                    local startScreenConn = nil
                    local selectionLabel =
                        mainHolder.CharacterInfo:FindFirstChild('PlayerName')
                    local selectionLabelRef = selectionLabel
                    local initialSelectionName = getSelectionName(selectionLabel)
                    local initialSelectedText = getSelectedCharacterText() or ''
                    local initialContentText = ''
                    pcall(function()
                        initialContentText = selectionLabel.ContentText or ''
                    end)
                    if initialContentText == '' then
                        initialContentText = initialCharacterName
                    end

                    local triggered = false
                    local function cancelWaiting(reasonName)
                        triggered = true
                        if renderStepName then
                            RunService:UnbindFromRenderStep(renderStepName)
                            renderStepName = nil
                        end
                        if selectionStepName then
                            RunService:UnbindFromRenderStep(selectionStepName)
                            selectionStepName = nil
                        end
                        if textChangedConn then textChangedConn:Disconnect() textChangedConn = nil end
                        if textContentConn then textContentConn:Disconnect() textContentConn = nil end
                        if textAnyConn then textAnyConn:Disconnect() textAnyConn = nil end
                        if colorCheckConnection then colorCheckConnection:Disconnect() colorCheckConnection = nil end
                        if selectionChangeConn then
                            selectionChangeConn:Disconnect()
                            selectionChangeConn = nil
                        end
                        if selectionChangeConn2 then
                            selectionChangeConn2:Disconnect()
                            selectionChangeConn2 = nil
                        end
                        if selectionChangeConn3 then
                            selectionChangeConn3:Disconnect()
                            selectionChangeConn3 = nil
                        end
                        if selectionVisibleConn then
                            selectionVisibleConn:Disconnect()
                            selectionVisibleConn = nil
                        end
                        if startScreenConn then
                            startScreenConn:Disconnect()
                            startScreenConn = nil
                        end
                        isWaiting = false
                        if reasonName and reasonName ~= '' then
                            print('[AUTO-DEPLOY] Selection changed from ' .. initialSelectionName .. ' to ' .. reasonName .. ' - waiting cancelled')
                            Fluent:Notify({
                                Title = '❌ Auto Deploy Cancelled',
                                Content = 'Switched to ' .. reasonName,
                                Duration = 2,
                            })
                        end
                        UpdateStatus('Status: Inactive')
                    end

                    -- INSTANT reaction function - start auto-deploy immediately on unlock
                    local function checkAndStart()
                        if triggered then
                            return
                        end
                        local text = takenAnnouncement.Text
                        local content = takenAnnouncement.ContentText
                        if not (
                            text == ''
                            or text == ' '
                            or (text and #text > 0 and text:match('^%s+$'))
                            or content == ''
                            or content == ' '
                            or (content and #content > 0 and content:match('^%s+$'))
                        ) then
                            return
                        end
                        if not (selectFrame and selectFrame.Visible) then
                            cancelWaiting('selection hidden')
                            return
                        end
                        if not (startScreen and startScreen.Enabled) then
                            cancelWaiting('start screen closed')
                            return
                        end
                        if not selectionLabelRef or not selectionLabelRef.Parent then
                            cancelWaiting('selection changed')
                            return
                        end
                        local currentLabel =
                            mainHolder.CharacterInfo:FindFirstChild('PlayerName')
                        if currentLabel ~= selectionLabelRef then
                            cancelWaiting(getSelectionName(currentLabel) or 'selection changed')
                            return
                        end
                        local currentSelectedText =
                            getSelectedCharacterText() or ''
                        if initialSelectedText ~= ''
                            and currentSelectedText ~= ''
                            and currentSelectedText ~= initialSelectedText
                        then
                            cancelWaiting(currentSelectedText)
                            return
                        end
                        local currentName = getSelectionName(currentLabel)
                        local currentContentText = ''
                        pcall(function()
                            currentContentText = currentLabel.ContentText or ''
                        end)
                        if initialContentText ~= '' and currentContentText ~= '' and currentContentText ~= initialContentText then
                            cancelWaiting(currentContentText)
                            return
                        end
                        if currentName and initialSelectionName and currentName ~= initialSelectionName then
                            cancelWaiting(currentName)
                            return
                        end
                        triggered = true
                        -- Disconnect ALL listeners immediately
                        if renderStepName then
                            RunService:UnbindFromRenderStep(renderStepName)
                            renderStepName = nil
                        end
                        if selectionStepName then
                            RunService:UnbindFromRenderStep(selectionStepName)
                            selectionStepName = nil
                        end
                        if textChangedConn then textChangedConn:Disconnect() textChangedConn = nil end
                        if textContentConn then textContentConn:Disconnect() textContentConn = nil end
                        if textAnyConn then textAnyConn:Disconnect() textAnyConn = nil end
                        if colorCheckConnection then colorCheckConnection:Disconnect() colorCheckConnection = nil end
                        isWaiting = false
                        if selectionChangeConn then
                            selectionChangeConn:Disconnect()
                            selectionChangeConn = nil
                        end
                        if selectionChangeConn2 then
                            selectionChangeConn2:Disconnect()
                            selectionChangeConn2 = nil
                        end

                        -- Start auto-deploy immediately (no pre-spam that can block the event)
                        if type(startSpammer) == 'function' then
                            startSpammer()
                        elseif type(StartAutoDeploy) == 'function' then
                            StartAutoDeploy(true)
                        end
                    end

                    -- DUAL DETECTION: Event-based (instant when property changes) + Polling (catches missed events)
                    -- Method 1: GetPropertyChangedSignal for INSTANT event-based detection
                    textChangedConn = takenAnnouncement:GetPropertyChangedSignal('Text'):Connect(checkAndStart)
                    textContentConn = takenAnnouncement:GetPropertyChangedSignal('ContentText'):Connect(checkAndStart)
                    textAnyConn = takenAnnouncement.Changed:Connect(function(prop)
                        if prop == 'Text' or prop == 'ContentText' then
                            checkAndStart()
                        end
                    end)

                    -- Method 2: Render step polling at highest priority
                    renderStepName = 'TVL_TextWatch_' .. tostring(takenAnnouncement)
                    RunService:BindToRenderStep(
                        renderStepName,
                        Enum.RenderPriority.First.Value,
                        checkAndStart
                    )

                    -- Cancel waiting if selection UI is hidden or tabbed away.
                    selectionVisibleConn = selectFrame:GetPropertyChangedSignal('Visible'):Connect(function()
                        if isWaiting and not selectFrame.Visible then
                            cancelWaiting('selection hidden')
                        end
                    end)
                    startScreenConn = startScreen:GetPropertyChangedSignal('Enabled'):Connect(function()
                        if isWaiting and not startScreen.Enabled then
                            cancelWaiting('start screen closed')
                        end
                    end)

                    -- Cancel waiting if player switches selection
                    if selectionChangeConn then
                        selectionChangeConn:Disconnect()
                        selectionChangeConn = nil
                    end
                    if selectionChangeConn2 then
                        selectionChangeConn2:Disconnect()
                        selectionChangeConn2 = nil
                    end
                    if selectionLabel then
                        selectionChangeConn =
                            selectionLabel:GetPropertyChangedSignal(
                                'Text'
                            ):Connect(function()
                                if not isWaiting then
                                    return
                                end
                                local newName = getSelectionName(selectionLabel)
                                local currentContentText = ''
                                pcall(function()
                                    currentContentText =
                                        selectionLabel.ContentText or ''
                                end)
                                if initialContentText ~= ''
                                    and currentContentText ~= ''
                                    and currentContentText ~= initialContentText
                                then
                                    cancelWaiting(currentContentText)
                                    return
                                end
                                if newName and newName ~= initialSelectionName then
                                    cancelWaiting(newName)
                                end
                            end)
                        selectionChangeConn2 =
                            selectionLabel:GetPropertyChangedSignal(
                                'ContentText'
                            ):Connect(function()
                                if not isWaiting then
                                    return
                                end
                                local currentContentText =
                                    selectionLabel.ContentText or ''
                                if initialContentText ~= ''
                                    and currentContentText ~= ''
                                    and currentContentText ~= initialContentText
                                then
                                    cancelWaiting(currentContentText)
                                    return
                                end
                                local newName = getSelectionName(selectionLabel)
                                if newName and newName ~= initialSelectionName then
                                    cancelWaiting(newName)
                                end
                            end)
                        selectionStepName = 'TVL_SelectWatch_' .. tostring(selectionLabel)
                        RunService:BindToRenderStep(
                            selectionStepName,
                            Enum.RenderPriority.First.Value,
                            function()
                                if not isWaiting then
                                    return
                                end
                                local newName = getSelectionName(selectionLabel)
                                local currentContentText = ''
                                pcall(function()
                                    currentContentText =
                                        selectionLabel.ContentText or ''
                                end)
                                if initialContentText ~= ''
                                    and currentContentText ~= ''
                                    and currentContentText ~= initialContentText
                                then
                                    cancelWaiting(currentContentText)
                                    return
                                end
                                if newName and newName ~= initialSelectionName then
                                    cancelWaiting(newName)
                                end
                            end
                        )
                    end
                    do
                        local ok, label = pcall(function()
                            return mainHolder.SelectCharacterFrame.LeftArea.MiddleArea.TopArea:FindFirstChild('SelectedCharacter')
                        end)
                        if ok and label then
                            if selectionChangeConn3 then
                                selectionChangeConn3:Disconnect()
                            end
                            selectionChangeConn3 =
                                label:GetPropertyChangedSignal(
                                    'ContentText'
                                ):Connect(function()
                                    if not isWaiting then
                                        return
                                    end
                                    local currentText =
                                        label.ContentText or label.Text or ''
                                    if initialSelectedText ~= ''
                                        and currentText ~= ''
                                        and currentText ~= initialSelectedText
                                    then
                                        cancelWaiting(currentText)
                                    end
                                end)
                        end
                    end

                    -- Store main connection for cleanup
                    colorCheckConnection = textChangedConn
                    -- Immediate check in case the text is already unlocked
                    checkAndStart()
                -- Check if button is bright/available (RGB 150+ indicates unlocked)
                elseif r >= 150 and g >= 150 and b >= 150 then
                    print(
                        '[DEBUG] Button is available (RGB: '
                            .. r
                            .. ','
                            .. g
                            .. ','
                            .. b
                            .. ') - starting auto-deploy'
                    )
                    Fluent:Notify({
                        Title = '✅ Auto Deploy',
                        Content = 'Button ready - deploying now!',
                        Duration = 2,
                    })
                    startSpammer()
                else
                    -- Button in intermediate/loading state - treat as locked and wait
                    print(
                        '[DEBUG] Button in loading state (RGB: '
                            .. r
                            .. ','
                            .. g
                            .. ','
                            .. b
                            .. ') - waiting for unlock...'
                    )

                    local characterName = 'Unknown'
                    pcall(function()
                        characterName =
                            mainHolder.CharacterInfo.PlayerName.ContentText
                    end)

                    isWaiting = true
                    Fluent:Notify({
                        Title = '⏳ Auto Deploy',
                        Content = 'Waiting for '
                            .. characterName
                            .. ' to unlock...',
                        Duration = 3,
                    })
                    UpdateStatus(
                        'Status: Waiting for '
                            .. characterName
                            .. ' to unlock...'
                    )

                    local initialCharacterName = characterName
                    local takenAnnouncement = mainHolder.CharacterInfoMiddle.TakenAnnouncement
                    local renderStepName = nil
                    local selectionStepName = nil
                    local textChangedConn = nil
                    local textContentConn = nil
                    local textAnyConn = nil
                    local selectionVisibleConn = nil
                    local startScreenConn = nil
                    local selectionLabel =
                        mainHolder.CharacterInfo:FindFirstChild('PlayerName')
                    local selectionLabelRef = selectionLabel
                    local initialSelectionName = getSelectionName(selectionLabel)
                    local initialSelectedText = getSelectedCharacterText() or ''
                    local initialContentText = ''
                    pcall(function()
                        initialContentText = selectionLabel.ContentText or ''
                    end)
                    if initialContentText == '' then
                        initialContentText = initialCharacterName
                    end

                    local triggered = false
                    local function cancelWaiting(reasonName)
                        triggered = true
                        if renderStepName then
                            RunService:UnbindFromRenderStep(renderStepName)
                            renderStepName = nil
                        end
                        if selectionStepName then
                            RunService:UnbindFromRenderStep(selectionStepName)
                            selectionStepName = nil
                        end
                        if textChangedConn then textChangedConn:Disconnect() textChangedConn = nil end
                        if textContentConn then textContentConn:Disconnect() textContentConn = nil end
                        if textAnyConn then textAnyConn:Disconnect() textAnyConn = nil end
                        if colorCheckConnection then colorCheckConnection:Disconnect() colorCheckConnection = nil end
                        if selectionChangeConn then
                            selectionChangeConn:Disconnect()
                            selectionChangeConn = nil
                        end
                        if selectionChangeConn2 then
                            selectionChangeConn2:Disconnect()
                            selectionChangeConn2 = nil
                        end
                        if selectionChangeConn3 then
                            selectionChangeConn3:Disconnect()
                            selectionChangeConn3 = nil
                        end
                        if selectionVisibleConn then
                            selectionVisibleConn:Disconnect()
                            selectionVisibleConn = nil
                        end
                        if startScreenConn then
                            startScreenConn:Disconnect()
                            startScreenConn = nil
                        end
                        isWaiting = false
                        if reasonName and reasonName ~= '' then
                            print('[AUTO-DEPLOY] Selection changed from ' .. initialSelectionName .. ' to ' .. reasonName .. ' - waiting cancelled')
                            Fluent:Notify({
                                Title = '❌ Auto Deploy Cancelled',
                                Content = 'Switched to ' .. reasonName,
                                Duration = 2,
                            })
                        end
                        UpdateStatus('Status: Inactive')
                    end

                    -- INSTANT reaction function - start auto-deploy immediately on unlock
                    local function checkAndStart()
                        if triggered then
                            return
                        end
                        local text = takenAnnouncement.Text
                        local content = takenAnnouncement.ContentText
                        if not (
                            text == ''
                            or text == ' '
                            or (text and #text > 0 and text:match('^%s+$'))
                            or content == ''
                            or content == ' '
                            or (content and #content > 0 and content:match('^%s+$'))
                        ) then
                            return
                        end
                        if not (selectFrame and selectFrame.Visible) then
                            cancelWaiting('selection hidden')
                            return
                        end
                        if not (startScreen and startScreen.Enabled) then
                            cancelWaiting('start screen closed')
                            return
                        end
                        if not selectionLabelRef or not selectionLabelRef.Parent then
                            cancelWaiting('selection changed')
                            return
                        end
                        local currentLabel =
                            mainHolder.CharacterInfo:FindFirstChild('PlayerName')
                        if currentLabel ~= selectionLabelRef then
                            cancelWaiting(getSelectionName(currentLabel) or 'selection changed')
                            return
                        end
                        local currentSelectedText =
                            getSelectedCharacterText() or ''
                        if initialSelectedText ~= ''
                            and currentSelectedText ~= ''
                            and currentSelectedText ~= initialSelectedText
                        then
                            cancelWaiting(currentSelectedText)
                            return
                        end
                        local currentName = getSelectionName(currentLabel)
                        local currentContentText = ''
                        pcall(function()
                            currentContentText = currentLabel.ContentText or ''
                        end)
                        if initialContentText ~= '' and currentContentText ~= '' and currentContentText ~= initialContentText then
                            cancelWaiting(currentContentText)
                            return
                        end
                        if currentName and initialSelectionName and currentName ~= initialSelectionName then
                            cancelWaiting(currentName)
                            return
                        end
                        triggered = true
                        -- Disconnect ALL listeners immediately
                        if renderStepName then
                            RunService:UnbindFromRenderStep(renderStepName)
                            renderStepName = nil
                        end
                        if selectionStepName then
                            RunService:UnbindFromRenderStep(selectionStepName)
                            selectionStepName = nil
                        end
                        if textChangedConn then textChangedConn:Disconnect() textChangedConn = nil end
                        if textContentConn then textContentConn:Disconnect() textContentConn = nil end
                        if textAnyConn then textAnyConn:Disconnect() textAnyConn = nil end
                        if colorCheckConnection then colorCheckConnection:Disconnect() colorCheckConnection = nil end
                        isWaiting = false
                        if selectionChangeConn then
                            selectionChangeConn:Disconnect()
                            selectionChangeConn = nil
                        end
                        if selectionChangeConn2 then
                            selectionChangeConn2:Disconnect()
                            selectionChangeConn2 = nil
                        end

                        -- Start auto-deploy immediately (no pre-spam that can block the event)
                        if type(startSpammer) == 'function' then
                            startSpammer()
                        elseif type(StartAutoDeploy) == 'function' then
                            StartAutoDeploy(true)
                        end
                    end

                    -- DUAL DETECTION: Event-based (instant when property changes) + Polling (catches missed events)
                    -- Method 1: GetPropertyChangedSignal for INSTANT event-based detection
                    textChangedConn = takenAnnouncement:GetPropertyChangedSignal('Text'):Connect(checkAndStart)
                    textContentConn = takenAnnouncement:GetPropertyChangedSignal('ContentText'):Connect(checkAndStart)
                    textAnyConn = takenAnnouncement.Changed:Connect(function(prop)
                        if prop == 'Text' or prop == 'ContentText' then
                            checkAndStart()
                        end
                    end)

                    -- Method 2: Render step polling at highest priority
                    renderStepName = 'TVL_TextWatch_' .. tostring(takenAnnouncement)
                    RunService:BindToRenderStep(
                        renderStepName,
                        Enum.RenderPriority.First.Value,
                        checkAndStart
                    )

                    -- Cancel waiting if selection UI is hidden or tabbed away.
                    selectionVisibleConn = selectFrame:GetPropertyChangedSignal('Visible'):Connect(function()
                        if isWaiting and not selectFrame.Visible then
                            cancelWaiting('selection hidden')
                        end
                    end)
                    startScreenConn = startScreen:GetPropertyChangedSignal('Enabled'):Connect(function()
                        if isWaiting and not startScreen.Enabled then
                            cancelWaiting('start screen closed')
                        end
                    end)

                    -- Cancel waiting if player switches selection
                    if selectionChangeConn then
                        selectionChangeConn:Disconnect()
                        selectionChangeConn = nil
                    end
                    if selectionChangeConn2 then
                        selectionChangeConn2:Disconnect()
                        selectionChangeConn2 = nil
                    end
                    if selectionLabel then
                        selectionChangeConn =
                            selectionLabel:GetPropertyChangedSignal(
                                'Text'
                            ):Connect(function()
                                if not isWaiting then
                                    return
                                end
                                local newName = getSelectionName(selectionLabel)
                                local currentContentText = ''
                                pcall(function()
                                    currentContentText =
                                        selectionLabel.ContentText or ''
                                end)
                                if initialContentText ~= ''
                                    and currentContentText ~= ''
                                    and currentContentText ~= initialContentText
                                then
                                    cancelWaiting(currentContentText)
                                    return
                                end
                                if newName and newName ~= initialSelectionName then
                                    cancelWaiting(newName)
                                end
                            end)
                        selectionChangeConn2 =
                            selectionLabel:GetPropertyChangedSignal(
                                'ContentText'
                            ):Connect(function()
                                if not isWaiting then
                                    return
                                end
                                local currentContentText =
                                    selectionLabel.ContentText or ''
                                if initialContentText ~= ''
                                    and currentContentText ~= ''
                                    and currentContentText ~= initialContentText
                                then
                                    cancelWaiting(currentContentText)
                                    return
                                end
                                local newName = getSelectionName(selectionLabel)
                                if newName and newName ~= initialSelectionName then
                                    cancelWaiting(newName)
                                end
                            end)
                        selectionStepName = 'TVL_SelectWatch_' .. tostring(selectionLabel)
                        RunService:BindToRenderStep(
                            selectionStepName,
                            Enum.RenderPriority.First.Value,
                            function()
                                if not isWaiting then
                                    return
                                end
                                local newName = getSelectionName(selectionLabel)
                                local currentContentText = ''
                                pcall(function()
                                    currentContentText =
                                        selectionLabel.ContentText or ''
                                end)
                                if initialContentText ~= ''
                                    and currentContentText ~= ''
                                    and currentContentText ~= initialContentText
                                then
                                    cancelWaiting(currentContentText)
                                    return
                                end
                                if newName and newName ~= initialSelectionName then
                                    cancelWaiting(newName)
                                end
                            end
                        )
                    end
                    do
                        local ok, label = pcall(function()
                            return mainHolder.SelectCharacterFrame.LeftArea.MiddleArea.TopArea:FindFirstChild('SelectedCharacter')
                        end)
                        if ok and label then
                            if selectionChangeConn3 then
                                selectionChangeConn3:Disconnect()
                            end
                            selectionChangeConn3 =
                                label:GetPropertyChangedSignal(
                                    'ContentText'
                                ):Connect(function()
                                    if not isWaiting then
                                        return
                                    end
                                    local currentText =
                                        label.ContentText or label.Text or ''
                                    if initialSelectedText ~= ''
                                        and currentText ~= ''
                                        and currentText ~= initialSelectedText
                                    then
                                        cancelWaiting(currentText)
                                    end
                                end)
                        end
                    end

                    -- Store main connection for cleanup
                    colorCheckConnection = textChangedConn
                    -- Immediate check in case the text is already unlocked
                    checkAndStart()
                end
            end)

            if not success then
                print('[ERROR] Auto-deploy check failed:', errorMsg)
                Fluent:Notify({
                    Title = '❌ Error',
                    Content = tostring(errorMsg),
                    Duration = 4,
                })
                -- If the error indicates the character selection screen is missing or hidden,
                -- show a more descriptive status so the user knows why auto-deploy cannot start.
                local err = tostring(errorMsg)
                if
                    string.find(
                        err,
                        'Character selection screen is not visible',
                        1,
                        true
                    )
                    or string.find(
                        err,
                        'SelectCharacterFrame not found',
                        1,
                        true
                    )
                    or string.find(err, 'StartScreen not found', 1, true)
                    or string.find(err, 'MainHolder not found', 1, true)
                then
                    UpdateStatus('Status: Character menu not found')
                else
                    UpdateStatus('Status: Error')
                end
            end
        end
    end
end)

-- extra safety: if player already has a character, consider we have "spawned" and ensure not running
if lp and lp.Character then
    -- Stop silently without notification
    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    if charAddedConn then
        charAddedConn:Disconnect()
        charAddedConn = nil
    end
    running = false

    -- Get character name for status
    local charName = 'Unknown'
    pcall(function()
        local pg = lp:FindFirstChild('PlayerGui')
        if pg then
            local startScreen = pg:FindFirstChild('StartScreen')
            if startScreen then
                charName =
                    startScreen.MainHolder.CharacterInfo.PlayerName.ContentText
            end
        end
    end)
    UpdateStatus('Status: Spawned as ' .. charName)
end

print('Auto-deploy toggle ready — Press J to start/stop.')

-- Hotkey Settings
-- Self ability hotkey disabled
_G.SelfAbilityHotkey = nil

-- Wait 3 seconds before enabling hotkeys
-- Define hotkeysEnabled as a global so it is visible to the event callbacks
hotkeysEnabled = false

-- Wait 0.5 seconds before enabling hotkeys (reduced for faster startup)
task.delay(0.5, function()
    hotkeysEnabled = true
    print('[HOTKEYS] Hotkeys enabled!')
end) -- Removed Fast Respawn Hotkey (feature removed)

-- Helper function to convert key input to KeyCode
local function getKeyCode(input)
    local key = input:upper()

    -- Map number strings to their KeyCode names
    local numberMap = {
        ['0'] = 'Zero',
        ['1'] = 'One',
        ['2'] = 'Two',
        ['3'] = 'Three',
        ['4'] = 'Four',
        ['5'] = 'Five',
        ['6'] = 'Six',
        ['7'] = 'Seven',
        ['8'] = 'Eight',
        ['9'] = 'Nine',
    }

    -- Check if it's a number
    if numberMap[key] then
        return Enum.KeyCode[numberMap[key]]
    end

    -- Otherwise try as a letter
    return Enum.KeyCode[key]
end

-- Self Ability Hotkey
-- Self Ability feature removed by user request
local SelfAbilityInput = { Value = '', OnChanged = function(self, callback) end }

-- Self Ability hotkey change handler removed

-- Fast Respawn Hotkey
-- (Fast Respawn Hotkey input removed)

-- Hotkey Handler
UserInputService.InputBegan:Connect(function(input, gp)
    -- Ignore input if Roblox processed it or hotkeys are disabled
    if gp then
        return
    end
    if not hotkeysEnabled then
        return
    end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    -- Self Ability hotkey removed: this branch previously listened for the
    -- SelfAbilityHotkey and fired the AbilityActivated remote.  The user
    -- requested the Self Ability feature be disabled entirely, so this code
    -- has been removed.  Since _G.SelfAbilityHotkey is nil, the condition
    -- would never be true, but removing the block clarifies that the
    -- functionality is no longer active.

    -- Fast Respawn feature removed
end)

-- RemotesTab has already been created earlier to ensure the desired tab order.

-- ⚡ UNDESICCATE SECTION ⚡
RemotesTab:AddParagraph({
    Title = 'Undesiccate',
    Content = 'Restore desiccated entities',
})

local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local selectedEntity = nil
local entityLookup = {}

local function getDesiccatedEntities()
    entityLookup = {}
    local names = {}

    if Workspace:FindFirstChild('Entities') then
        for _, entity in pairs(Workspace.Entities:GetChildren()) do
            if entity:GetAttribute('Desiccated') == true then
                table.insert(names, entity.Name)
                entityLookup[entity.Name] = entity
            end
        end
    end

    table.sort(names)
    return names
end

local UndesiccateDropdown = RemotesTab:AddDropdown('UndesiccateDropdown', {
    Title = 'Select Desiccated Entity',
    Values = getDesiccatedEntities(),
    Multi = false,
    Default = 1,
})

UndesiccateDropdown:OnChanged(function(Value)
    local selected = type(Value) == 'table' and Value[1] or Value
    selectedEntity = tostring(selected)
    if not isInitializing then
        Fluent:Notify({
            Title = 'Entity Selected',
            Content = 'Target: ' .. selectedEntity,
            Duration = 2,
        })
    end
end)

local RefreshUndesiccateButton = RemotesTab:AddButton({
    Title = 'Refresh Entity List',
    Callback = function()
        local newList = getDesiccatedEntities()
        UndesiccateDropdown:SetValues(newList)

        Fluent:Notify({
            Title = 'Refreshed',
            Content = 'Entity list updated! Found: ' .. #newList,
            Duration = 2,
        })
    end,
})

local UndesiccateButton = RemotesTab:AddButton({
    Title = 'Undesiccate',
    Callback = function()
        if
            not selectedEntity
            or selectedEntity == ''
            or selectedEntity == 'None'
        then
            Fluent:Notify({
                Title = 'Error',
                Content = 'No entity selected!',
                Duration = 3,
            })
            return
        end

        local targetEntity = entityLookup[selectedEntity]

        if not targetEntity or not targetEntity.Parent then
            Fluent:Notify({
                Title = 'Error',
                Content = 'Entity not found or was removed!',
                Duration = 3,
            })
            return
        end

        if targetEntity:GetAttribute('Desiccated') ~= true then
            Fluent:Notify({
                Title = 'Error',
                Content = 'Entity is no longer desiccated!',
                Duration = 3,
            })
            return
        end

        local success, err = pcall(function()
            local args = { targetEntity }
            ReplicatedStorage.Remotes.ToolService.ToServer.ToolActivated:FireServer(
                unpack(args)
            )
        end)

        if success then
            Fluent:Notify({
                Title = 'Success',
                Content = 'Undesiccated ' .. selectedEntity,
                Duration = 3,
            })
        else
            Fluent:Notify({
                Title = 'Failed',
                Content = 'Error: ' .. tostring(err),
                Duration = 4,
            })
        end
    end,
})

-- ⚡ REMOTE RESURRECTION SECTION ⚡
RemotesTab:AddParagraph({
    Title = 'Remote Resurrection',
    Content = 'Resurrect players in limbo',
})

local selectedPlayer = nil
local playerLookup = {}

local function getLimboPlayers()
    playerLookup = {}
    local names = {}

    if Workspace:FindFirstChild('playerInLimboFolder') then
        for _, playerModel in pairs(Workspace.playerInLimboFolder:GetChildren()) do
            if playerModel:IsA('Model') then
                local playerName = playerModel.Name
                table.insert(names, playerName)
                playerLookup[playerName] = playerModel
            end
        end
    end

    table.sort(names)
    return names
end

local ResurrectionDropdown = RemotesTab:AddDropdown('ResurrectionDropdown', {
    Title = 'Select Player in Limbo',
    Values = getLimboPlayers(),
    Multi = false,
    Default = 1,
})

ResurrectionDropdown:OnChanged(function(Value)
    local selected = type(Value) == 'table' and Value[1] or Value
    selectedPlayer = tostring(selected)
    if not isInitializing then
        Fluent:Notify({
            Title = 'Player Selected',
            Content = 'Target: ' .. selectedPlayer,
            Duration = 2,
        })
    end
end)

local RefreshResurrectionButton = RemotesTab:AddButton({
    Title = 'Refresh Player List',
    Callback = function()
        local newList = getLimboPlayers()
        ResurrectionDropdown:SetValues(newList)

        Fluent:Notify({
            Title = 'Refreshed',
            Content = 'Player list updated! Found: ' .. #newList,
            Duration = 2,
        })
    end,
})

local ResurrectButton = RemotesTab:AddButton({
    Title = 'Resurrect Player',
    Callback = function()
        if
            not selectedPlayer
            or selectedPlayer == ''
            or selectedPlayer == 'None'
        then
            Fluent:Notify({
                Title = 'Error',
                Content = 'No player selected!',
                Duration = 3,
            })
            return
        end

        local targetPlayer = playerLookup[selectedPlayer]

        if not targetPlayer or not targetPlayer.Parent then
            Fluent:Notify({
                Title = 'Error',
                Content = 'Player not found or was removed!',
                Duration = 3,
            })
            return
        end

        local success, err = pcall(function()
            local args = { selectedPlayer }
            ReplicatedStorage.Remotes.AbilityService.ToServer['AbilityActivated___']:FireServer(
                unpack(args)
            )
        end)

        if success then
            Fluent:Notify({
                Title = 'Success',
                Content = 'Resurrected ' .. selectedPlayer,
                Duration = 3,
            })
        else
            Fluent:Notify({
                Title = 'Failed',
                Content = 'Error: ' .. tostring(err),
                Duration = 4,
            })
        end
    end,
})

-- Infinite Stamina

-- Cured Notifier (Optimized - Event Driven)
-- Variables to track ESP creation timing (prevents race conditions)
local lastESPCreationTime = {}
local espCreationInProgress = {}

MainTab:AddParagraph({
    Title = 'Cured Notifier',
    Content = 'Get notified when players are cured',
})
local curedNotifierEnabled = false
local curedNotified = {}
local curedConns = { players = {} }
local playerAddedConn, playerRemovingConn = nil, nil

local function disconnectPlayerCuredConns(p)
    local bucket = curedConns.players[p]
    if not bucket then
        return
    end
    curedCheckThrottle[p] = nil -- Clean up throttle cache
    if bucket.playerCuredConn then
        pcall(function()
            bucket.playerCuredConn:Disconnect()
        end)
        bucket.playerCuredConn = nil
    end
    if bucket.charCuredConn then
        pcall(function()
            bucket.charCuredConn:Disconnect()
        end)
        bucket.charCuredConn = nil
    end
    if bucket.charAddedConn then
        pcall(function()
            bucket.charAddedConn:Disconnect()
        end)
        bucket.charAddedConn = nil
    end
    curedConns.players[p] = nil
    curedNotified[p] = nil
end

local curedCheckThrottle = {} -- Throttle cured checks per player

local function handleCuredState(player)
    local function notifyIfCured()
        -- Simple throttle to prevent spam (0.5s cooldown per player)
        local now = tick()
        local lastCheck = curedCheckThrottle[player] or 0
        if now - lastCheck < 0.5 then
            return
        end
        curedCheckThrottle[player] = now

        -- Check cured status
        local isCured = false
        pcall(function()
            if player:GetAttribute('Cured') then
                isCured = true
            elseif
                player.Character and player.Character:GetAttribute('Cured')
            then
                isCured = true
            end
        end)

        if isCured and not curedNotified[player] then
            curedNotified[player] = true
            local charName
            pcall(function()
                charName = player:GetAttribute('CharacterName')
                    or (
                        player.Character
                        and player.Character:GetAttribute('CharacterName')
                    )
            end)
            charName = charName or player.Name
            Fluent:Notify({
                Title = '🩺 Cured',
                Content = charName .. ' has been cured.',
                Duration = 3,
            })
        elseif not isCured and curedNotified[player] then
            curedNotified[player] = nil
        end
    end

    local bucket = curedConns.players[player]
    if not bucket then
        bucket = {}
        curedConns.players[player] = bucket

        -- Monitor player Cured attribute
        bucket.playerCuredConn = player
            :GetAttributeChangedSignal('Cured')
            :Connect(function()
                task.defer(notifyIfCured)
            end)

        -- Monitor character changes
        bucket.charAddedConn = player.CharacterAdded:Connect(function(char)
            if bucket.charCuredConn then
                pcall(function()
                    bucket.charCuredConn:Disconnect()
                end)
                bucket.charCuredConn = nil
            end
            if char then
                -- Monitor character Cured attribute
                bucket.charCuredConn = char:GetAttributeChangedSignal('Cured')
                    :Connect(function()
                        task.defer(notifyIfCured)
                    end)
            end
            task.defer(notifyIfCured)
        end)
    end

    -- Setup character monitoring if character exists
    if player.Character and not (bucket and bucket.charCuredConn) then
        bucket.charCuredConn = player.Character
            :GetAttributeChangedSignal('Cured')
            :Connect(function()
                task.defer(notifyIfCured)
            end)
    end

    -- Initial check
    task.defer(notifyIfCured)
end

local CuredNotifierToggle = MainTab:AddToggle('CuredNotifier', {
    Title = 'Cured Notifier',
    Default = true,
})

CuredNotifierToggle:OnChanged(function(Value)
    curedNotifierEnabled = Value
    if Value then
        if not isInitializing then
            Fluent:Notify({
                Title = 'Cured Notifier',
                Content = 'Enabled',
                Duration = 2,
            })
        end
        -- initialize for existing players with batching to prevent FPS drops
        task.spawn(function()
            local playerList = Players:GetPlayers()
            for i, p in ipairs(playerList) do
                if p ~= Players.LocalPlayer then
                    task.defer(function()
                        handleCuredState(p)
                    end)
                end
                -- Yield every 3 players to prevent FPS drops
                if i % 3 == 0 then
                    task.wait()
                end
            end
        end)
        -- connect new players (idempotent)
        if not playerAddedConn then
            playerAddedConn = Players.PlayerAdded:Connect(function(p)
                if curedNotifierEnabled then
                    handleCuredState(p)
                end
            end)
        end
        if not playerRemovingConn then
            playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
                disconnectPlayerCuredConns(p)
            end)
        end
    else
        if not isInitializing then
            Fluent:Notify({
                Title = 'Cured Notifier',
                Content = 'Disabled',
                Duration = 2,
            })
        end
        -- disconnect global listeners
        if playerAddedConn then
            pcall(function()
                playerAddedConn:Disconnect()
            end)
            playerAddedConn = nil
        end
        if playerRemovingConn then
            pcall(function()
                playerRemovingConn:Disconnect()
            end)
            playerRemovingConn = nil
        end
        -- disconnect all per-player listeners
        for p, _ in pairs(curedConns.players) do
            disconnectPlayerCuredConns(p)
        end
        curedNotified = {}
    end
end)

-- Infinite Stamina feature removed by user request
-- This section previously created UI and logic to enable a toggle that would
-- continuously fire the RunStateToggled remote, granting infinite stamina.
-- The user has asked for this feature to be completely removed, so we disable
-- it and stub out the UI elements.  _G.InfiniteStaminaEnabled is left false
-- to ensure no residual logic is executed.
_G.InfiniteStaminaEnabled = false

-- Stub for the now-removed Infinite Stamina toggle.  This dummy object
-- includes a Value property and a no-op OnChanged method so that any
-- references to InfiniteStaminaToggle remain harmless.
local InfiniteStaminaToggle = {
    Value = false,
    OnChanged = function(self, callback)
        -- Intentionally blank: infinite stamina toggle has been disabled.
    end,
}

-- Teleportation (moved to Teleport tab)
TeleportTab:AddParagraph({
    Title = 'Teleportation',
    Content = 'Quick travel to key locations',
})

TeleportTab:AddParagraph({
    Title = '⚠️ Important Warning',
    Content = 'Only use in a private server',
})

local TeleportToCureButton = TeleportTab:AddButton({
    Title = 'Teleport to Cure',
    Callback = function()
        Fluent:Notify({
            Title = 'Teleport',
            Content = 'Starting stealth sequence...',
            Duration = 2,
        })

        local player = Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild('HumanoidRootPart')
        local humanoid = char:WaitForChild('Humanoid')

        -- Main waypoints with slight random variations
        local basePositions = {
            Vector3.new(1113, -138, -2239),
            Vector3.new(1103, -138, -2242),
            Vector3.new(1042, -138, -2454),
        }

        -- Add random offset to each position (simulate human imprecision)
        local function addRandomOffset(pos)
            local offsetX = math.random(-3, 3)
            local offsetZ = math.random(-3, 3)
            return Vector3.new(pos.X + offsetX, pos.Y, pos.Z + offsetZ)
        end

        -- Randomize movement speed (simulate human variation)
        local function getRandomSpeed()
            return math.random(40, 60) / 10 -- 4.0 to 6.0 seconds per segment
        end

        -- Randomize easing style (mix of human-like movements)
        local easingStyles = {
            Enum.EasingStyle.Quad,
            Enum.EasingStyle.Sine,
            Enum.EasingStyle.Cubic,
        }

        local function tweenToPosition(targetPos)
            -- Random easing for natural movement
            local randomEasing = easingStyles[math.random(1, #easingStyles)]
            local tweenInfo = TweenInfo.new(
                getRandomSpeed(),
                randomEasing,
                Enum.EasingDirection.InOut,
                0,
                false,
                0
            )

            local tween = TweenService:Create(
                hrp,
                tweenInfo,
                { CFrame = CFrame.new(targetPos) }
            )
            tween:Play()
            tween.Completed:Wait()
        end

        -- Simulate human looking around (random camera adjustments)
        local function simulateHumanBehavior()
            -- Random pause (humans don't move constantly)
            task.wait(math.random(5, 10) / 10) -- 0.5 to 1.0 seconds

            -- Occasionally "stop" as if checking surroundings
            if math.random(1, 3) == 1 then
                task.wait(math.random(10, 20) / 10) -- 1.0 to 2.0 seconds pause
            end
        end

        -- Execute teleport with human-like behavior
        for i, pos in ipairs(basePositions) do
            local targetPos = addRandomOffset(pos)
            tweenToPosition(targetPos)

            -- Simulate human behavior between waypoints
            simulateHumanBehavior()

            -- Occasionally walk backwards slightly (human correction)
            if math.random(1, 4) == 1 and i < #basePositions then
                local currentPos = hrp.Position
                local backtrackPos = Vector3.new(
                    currentPos.X + math.random(-2, 2),
                    currentPos.Y,
                    currentPos.Z + math.random(-2, 2)
                )
                tweenToPosition(backtrackPos)
                task.wait(math.random(3, 6) / 10)
            end
        end

        Fluent:Notify({
            Title = 'Teleport',
            Content = 'Arrived safely!',
            Duration = 2,
        })
    end,
})

-- Teleport to Safe Area (COMMENTED OUT BY USER REQUEST)
--[[
-- Adds a new teleport button to the Teleport tab that moves the player to a predefined safe area.
local TeleportToSafeAreaButton = TeleportTab:AddButton({
    Title = 'Teleport to Safe Area',
    Callback = function()
        Fluent:Notify({
            Title = 'Teleport',
            Content = 'Starting sequence...',
            Duration = 2,
        })
        local player = Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild('HumanoidRootPart')
        -- Only one position for safe area teleport; wrap in table for consistency
        local positions = {
            Vector3.new(1174, 77, -730),
        }
        -- Configure tween for smooth movement
        local tweenInfo = TweenInfo.new(
            0.5,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut,
            0,
            false,
            0
        )
        -- Helper to tween to a single position
        local function tweenToPosition(targetPos)
            local tween = TweenService:Create(
                hrp,
                tweenInfo,
                { CFrame = CFrame.new(targetPos) }
            )
            tween:Play()
            tween.Completed:Wait()
        end
        -- Execute the tween sequence
        for i, pos in ipairs(positions) do
            tweenToPosition(pos)
            -- slight delay between movements, kept for future extensibility
            wait(0.1)
        end
        Fluent:Notify({
            Title = 'Teleport',
            Content = 'Complete!',
            Duration = 2,
        })
    end,
})
--]]

-- Anti Annoy
MiscTab:AddParagraph({
    Title = 'Anti Annoy',
    Content = 'Remove annoying effects',
})

local AntiAnnoyButton = MiscTab:AddButton({
    Title = 'Anti Annoy',
    Callback = function()
        if not isInitializing then
            Fluent:Notify({
                Title = 'Anti Annoy',
                Content = 'Anti Annoy script executed',
                Duration = 2,
            })
        end
        loadstring(game:HttpGet('https://pastebin.com/raw/rWr3t3Sj'))()
    end,
})

-- Auto Buy Cola Section
-- Auto Buy Cola feature removed by user request
-- Global state for cola purchase (obfuscation-resistant)
_G.__AUTO_COLA_ENABLED = false
_G.__AUTO_COLA_LOOP = nil
local AutoColaToggle = { OnChanged = function(self, callback) end }

AutoColaToggle:OnChanged(function(Value)
    _G.__AUTO_COLA_ENABLED = Value
    print('[AUTO COLA] Toggle changed to:', Value)

    if Value then
        -- Start the cola purchase loop
        _G.__AUTO_COLA_LOOP = task.spawn(function()
            print('[AUTO COLA] Loop started')
            while _G.__AUTO_COLA_ENABLED do
                local success, err = pcall(function()
                    local npcPath =
                        workspace:FindFirstChild('NonPlayerCharacters')
                    if npcPath then
                        local waitress = npcPath:FindFirstChild(
                            'MysticGrillWaitressNicholeCane'
                        )
                        if waitress then
                            local hrp =
                                waitress:FindFirstChild('HumanoidRootPart')
                            if hrp then
                                local args = {
                                    hrp,
                                    'BuyColaServer',
                                }
                                game:GetService('ReplicatedStorage')
                                    :WaitForChild('Remotes')
                                    :WaitForChild('NPCService')
                                    :WaitForChild('ToServer')
                                    :WaitForChild('ReturnResponse')
                                    :InvokeServer(unpack(args))
                                print('[AUTO COLA] Purchase successful')
                            else
                                warn('[AUTO COLA] HumanoidRootPart not found')
                            end
                        else
                            warn('[AUTO COLA] Waitress NPC not found')
                        end
                    else
                        warn('[AUTO COLA] NonPlayerCharacters folder not found')
                    end
                end)

                if not success then
                    warn('[AUTO COLA] Error:', err)
                end

                -- Wait before next purchase (adjust delay as needed)
                task.wait(0.05) -- 50ms delay for fast spamming
            end
            print('[AUTO COLA] Loop stopped')
        end)

        if not isInitializing then
            Fluent:Notify({
                Title = 'Auto Buy Cola',
                Content = 'Enabled - Purchasing cola automatically',
                Duration = 2,
            })
        end
    else
        -- Stop the loop
        _G.__AUTO_COLA_ENABLED = false

        if _G.__AUTO_COLA_LOOP then
            task.cancel(_G.__AUTO_COLA_LOOP)
            _G.__AUTO_COLA_LOOP = nil
        end

        if not isInitializing then
            Fluent:Notify({
                Title = 'Auto Buy Cola',
                Content = 'Disabled',
                Duration = 2,
            })
        end
    end
end)

-- Camera Section
MiscTab:AddParagraph({
    Title = 'Camera',
    Content = 'Camera control options',
})

-- Noclip Camera Toggle
local noclipCameraActive = false
local originalCameraMode = nil

local NoclipCameraToggle = MiscTab:AddToggle('NoclipCamera', {
    Title = 'Noclip Camera',
    Default = false,
})

NoclipCameraToggle:OnChanged(function(Value)
    noclipCameraActive = Value
    local Players = game:GetService('Players')
    local LocalPlayer = Players.LocalPlayer

    if Value then
        -- Enable noclip camera (SMOOTH VERSION)
        local Camera = workspace.CurrentCamera

        -- Store original settings
        if not originalCameraMode then
            originalCameraMode = {
                cameraMode = LocalPlayer.CameraMode,
                occlusionMode = LocalPlayer.DevCameraOcclusionMode,
            }
        end

        -- Use ONLY DevCameraOcclusionMode for smooth noclip
        -- This prevents the choppy zoom caused by CameraType switching
        pcall(function()
            LocalPlayer.DevCameraOcclusionMode =
                Enum.DevCameraOcclusionMode.Invisicam
        end)

        -- Optional: Adjust zoom limits for better control
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = 400 -- Reasonable max zoom
            LocalPlayer.CameraMinZoomDistance = 0.5 -- Allow close zoom
        end)

        if not isInitializing then
            Fluent:Notify({
                Title = 'Noclip Camera',
                Content = 'Camera collision disabled',
                Duration = 2,
            })
        end
    else
        -- Disable noclip camera (restore original settings)
        if originalCameraMode then
            pcall(function()
                LocalPlayer.DevCameraOcclusionMode = originalCameraMode.occlusionMode
                    or Enum.DevCameraOcclusionMode.Zoom
            end)

            pcall(function()
                LocalPlayer.CameraMode = originalCameraMode.cameraMode
            end)

            originalCameraMode = nil
        else
            -- Fallback if no original settings stored
            pcall(function()
                LocalPlayer.DevCameraOcclusionMode =
                    Enum.DevCameraOcclusionMode.Zoom
            end)
        end

        if not isInitializing then
            Fluent:Notify({
                Title = 'Noclip Camera',
                Content = 'Camera collision enabled',
                Duration = 2,
            })
        end
    end
end)

-- 🔧 WEBHOOK TAB 🔧
-- This tab allows the Discord webhook URL and the role ID used for staff notifications
-- to be changed on‑the‑fly. A test button is also provided to send a sample
-- notification using the current settings.
local CustomTab = CreateDummyTab()

-- Developer colors (shared by Fire Circle and Incendia)
local DEVELOPER_COLORS = {
    Luna = ColorSequence.new(
        Color3.fromRGB(148, 0, 211),
        Color3.fromRGB(160, 0, 211)
    ),
    Marina = ColorSequence.new(
        Color3.fromRGB(41, 109, 44),
        Color3.fromRGB(78, 202, 84)
    ),
    Raven = ColorSequence.new(
        Color3.fromRGB(41, 55, 109),
        Color3.fromRGB(75, 101, 201)
    ),
    TheGrinch = ColorSequence.new(
        Color3.fromRGB(41, 109, 44),
        Color3.fromRGB(22, 57, 23)
    ),
    TheDeer = ColorSequence.new(
        Color3.fromRGB(139, 69, 19),
        Color3.fromRGB(92, 51, 23)
    ),
    Elora = ColorSequence.new(
        Color3.fromRGB(178, 75, 201),
        Color3.fromRGB(226, 95, 255)
    ),
    Valeria = ColorSequence.new(
        Color3.fromRGB(245, 0, 59),
        Color3.fromRGB(245, 0, 10)
    ),
    DataSigh = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 200)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 110, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 200)),
    }),
    Emchikuwu = ColorSequence.new(
        Color3.fromRGB(255, 173, 241),
        Color3.fromRGB(253, 203, 245)
    ),
    Teletubbieshoi = ColorSequence.new(
        Color3.fromRGB(41, 109, 44),
        Color3.fromRGB(78, 202, 84)
    ),
    Kardashszn = ColorSequence.new(
        Color3.fromRGB(178, 75, 201),
        Color3.fromRGB(226, 95, 255)
    ),
    Halohashira = ColorSequence.new(
        Color3.fromRGB(28, 37, 73),
        Color3.fromRGB(70, 88, 159)
    ),
    Qetsiyah = ColorSequence.new(
        Color3.fromRGB(93, 123, 243),
        Color3.fromRGB(69, 157, 201)
    ),
    CleoSowande = ColorSequence.new(
        Color3.fromRGB(255, 178, 71),
        Color3.fromRGB(242, 190, 118)
    ),
    ChowLlama = ColorSequence.new(
        Color3.fromRGB(2, 10, 90),
        Color3.fromRGB(2, 10, 90)
    ),
    AnimateWithRick = ColorSequence.new(
        Color3.fromRGB(151, 52, 34),
        Color3.fromRGB(151, 52, 34)
    ),
    agussts_13 = ColorSequence.new(
        Color3.fromRGB(226, 226, 226),
        Color3.fromRGB(226, 226, 226)
    ),
}

CustomTab:AddParagraph({
    Title = 'Particle Controls',
    Content = 'Customize particle effects',
})

-- Color Presets
local COLOR_PRESETS = {
    ['Purple'] = { r = 128, g = 0, b = 255 },
    ['Blue'] = { r = 0, g = 100, b = 255 },
    ['Red'] = { r = 255, g = 0, b = 0 },
    ['Green'] = { r = 0, g = 255, b = 0 },
    ['Yellow'] = { r = 255, g = 255, b = 0 },
    ['Orange'] = { r = 255, g = 165, b = 0 },
    ['Pink'] = { r = 255, g = 105, b = 180 },
    ['Cyan'] = { r = 0, g = 255, b = 255 },
    ['White'] = { r = 255, g = 255, b = 255 },
    ['Black'] = { r = 0, g = 0, b = 0 },
}

-- Dynamic color variables (default to Purple)
local selectedFireCircleColor = 'Purple'

-- Current color values
local FIRE_CIRCLE_COLOR = ColorSequence.new(Color3.fromRGB(128, 0, 255))
local FIRE_CIRCLE_RGB = Color3.fromRGB(128, 0, 255)

local customFireCircleActive = false
local fireCircleConnections = {}
local fireCircleDescendantConnections = {}
local fireCircleOriginalEmitters = {}
local fireCircleOriginalLights = {}

local function updateFireCircleColor(colorName)
    -- Stop rainbow if switching to a static color
    if colorName ~= 'Rainbow' and rainbowActive then
        rainbowActive = false
        if rainbowLoop then
            task.cancel(rainbowLoop)
            rainbowLoop = nil
        end
    end

    if colorName == 'Rainbow' then
        rainbowActive = true
        selectedFireCircleColor = 'Rainbow'

        -- Start rainbow loop (always start when rainbow is selected)
        if not rainbowLoop then
            rainbowLoop = task.spawn(function()
                local hue = 0
                while rainbowActive do
                    hue = (hue + 0.01) % 1
                    local color = Color3.fromHSV(hue, 1, 1)

                    FIRE_CIRCLE_COLOR = ColorSequence.new(color)
                    FIRE_CIRCLE_RGB = color

                    -- Update all active particles if fire circle is enabled
                    if customFireCircleActive then
                        for emitter, _ in pairs(fireCircleOriginalEmitters) do
                            if emitter and emitter.Parent then
                                emitter.Color = FIRE_CIRCLE_COLOR
                            end
                        end
                        for light, _ in pairs(fireCircleOriginalLights) do
                            if light and light.Parent then
                                light.Color = FIRE_CIRCLE_RGB
                            end
                        end
                    end

                    task.wait(0.1) -- Optimized for obfuscation performance (~10 FPS)
                end
            end)
        end
        print('[FIRE CIRCLE] Rainbow mode enabled')
    elseif colorName:find('Dev: ') then
        -- Handle developer colors
        local devName = colorName:gsub('Dev: ', '')
        local devColor = DEVELOPER_COLORS[devName]
        if devColor then
            FIRE_CIRCLE_COLOR = devColor
            -- Extract first color from ColorSequence for RGB
            local keypoints = devColor.Keypoints
            FIRE_CIRCLE_RGB = keypoints[1].Value
            selectedFireCircleColor = colorName
            print('[FIRE CIRCLE] Developer color updated to:', devName)
        end
    elseif colorName == '--- Developer Colors ---' then
        -- Ignore separator
        return
    else
        local color = COLOR_PRESETS[colorName]
        if color then
            FIRE_CIRCLE_COLOR =
                ColorSequence.new(Color3.fromRGB(color.r, color.g, color.b))
            FIRE_CIRCLE_RGB = Color3.fromRGB(color.r, color.g, color.b)
            selectedFireCircleColor = colorName
            print('[FIRE CIRCLE] Color updated to:', colorName)
        end
    end
end

local function restoreFireCircleColors()
    for emitter, color in pairs(fireCircleOriginalEmitters) do
        if emitter and emitter.Parent then
            emitter.Color = color
        end
    end
    for light, color in pairs(fireCircleOriginalLights) do
        if light and light.Parent then
            light.Color = color
        end
    end
    table.clear(fireCircleOriginalEmitters)
    table.clear(fireCircleOriginalLights)
end

local function enableFireCircleHook()
    if customFireCircleActive then
        return
    end
    customFireCircleActive = true

    -- Throttling variables
    local lastColorChange = {}
    local COLOR_CHANGE_THROTTLE = 0.2 -- Optimized for obfuscation performance

    -- MoonSec v3 compatible approach - optimized for performance
    local function applyColorToObject(desc)
        if not customFireCircleActive or not desc.Parent then
            return
        end

        if desc:IsA('ParticleEmitter') then
            if not fireCircleOriginalEmitters[desc] then
                fireCircleOriginalEmitters[desc] = desc.Color
            end
            desc.Color = FIRE_CIRCLE_COLOR

            -- Throttled color monitoring
            local conn = desc:GetPropertyChangedSignal('Color')
                :Connect(function()
                    if not customFireCircleActive or not desc.Parent then
                        return
                    end

                    local now = tick()
                    local lastChange = lastColorChange[desc] or 0

                    if now - lastChange >= COLOR_CHANGE_THROTTLE then
                        lastColorChange[desc] = now
                        desc.Color = FIRE_CIRCLE_COLOR
                    end
                end)
            table.insert(fireCircleConnections, conn)
        elseif desc:IsA('PointLight') then
            if not fireCircleOriginalLights[desc] then
                fireCircleOriginalLights[desc] = desc.Color
            end
            desc.Color = FIRE_CIRCLE_RGB

            -- Throttled color monitoring
            local conn = desc:GetPropertyChangedSignal('Color')
                :Connect(function()
                    if not customFireCircleActive or not desc.Parent then
                        return
                    end

                    local now = tick()
                    local lastChange = lastColorChange[desc] or 0

                    if now - lastChange >= COLOR_CHANGE_THROTTLE then
                        lastColorChange[desc] = now
                        desc.Color = FIRE_CIRCLE_RGB
                    end
                end)
            table.insert(fireCircleConnections, conn)
        end
    end

    local function monitorAndColorize(instance)
        if not customFireCircleActive then
            return
        end

        -- Batch process descendants
        task.spawn(function()
            local descendants = instance:GetDescendants()
            local batchSize = 20

            for i = 1, #descendants, batchSize do
                if not customFireCircleActive then
                    break
                end

                for j = i, math.min(i + batchSize - 1, #descendants) do
                    local desc = descendants[j]
                    if
                        desc:IsA('ParticleEmitter') or desc:IsA('PointLight')
                    then
                        applyColorToObject(desc)
                    end
                end

                if i + batchSize < #descendants then
                    task.wait() -- Yield between batches
                end
            end
        end)

        -- Throttled descendant monitoring
        local pendingDescendants = {}
        local isProcessingDescendants = false

        local function processDescendants()
            if isProcessingDescendants or not customFireCircleActive then
                return
            end
            isProcessingDescendants = true

            task.spawn(function()
                while #pendingDescendants > 0 and customFireCircleActive do
                    local desc = table.remove(pendingDescendants, 1)
                    if desc and desc.Parent then
                        applyColorToObject(desc)
                    end

                    if #pendingDescendants > 5 then
                        task.wait() -- Yield if queue is large
                    end
                end
                isProcessingDescendants = false
            end)
        end

        local descConn = instance.DescendantAdded:Connect(function(desc)
            if not customFireCircleActive then
                return
            end

            if desc:IsA('ParticleEmitter') or desc:IsA('PointLight') then
                table.insert(pendingDescendants, desc)
                processDescendants()
            end
        end)
        fireCircleDescendantConnections[instance] = descConn
    end

    -- Process existing debris in background - OPTIMIZED
    task.spawn(function()
        local debris = workspace.Debris:GetChildren()
        for i, child in ipairs(debris) do
            if not customFireCircleActive then
                break
            end
            monitorAndColorize(child)

            if i % 3 == 0 then
                task.wait() -- Yield every 3 items for better performance
            end
        end
    end)

    -- Monitor new debris
    fireCircleConnections.debris = workspace.Debris.ChildAdded:Connect(
        function(child)
            if customFireCircleActive then
                monitorAndColorize(child)
            end
        end
    )

    print(
        '[FIRE CIRCLE] Hook enabled with color:',
        selectedFireCircleColor,
        '(Optimized)'
    )
end

local function disableFireCircleHook()
    if not customFireCircleActive then
        return
    end
    customFireCircleActive = false

    -- Disconnect all connections
    for _, conn in pairs(fireCircleConnections) do
        if
            conn
            and typeof(conn) == 'RBXScriptConnection'
            and conn.Connected
        then
            conn:Disconnect()
        end
    end
    table.clear(fireCircleConnections)

    for inst, conn in pairs(fireCircleDescendantConnections) do
        if
            conn
            and typeof(conn) == 'RBXScriptConnection'
            and conn.Connected
        then
            conn:Disconnect()
        end
        fireCircleDescendantConnections[inst] = nil
    end

    -- Restore original colors
    restoreFireCircleColors()

    print('[FIRE CIRCLE] Hook disabled - colors restored')
end

-- Fire Circle Color Dropdown
local FireCircleColorDropdown = CustomTab:AddDropdown('FireCircleColor', {
    Title = 'Fire Circle Color',
    Values = {
        'Purple',
        'Blue',
        'Red',
        'Green',
        'Yellow',
        'Orange',
        'Pink',
        'Cyan',
        'White',
        'Black',
        'Rainbow',
        '--- Developer Colors ---',
        'Dev: Luna',
        'Dev: Marina',
        'Dev: Raven',
        'Dev: TheGrinch',
        'Dev: TheDeer',
        'Dev: Elora',
        'Dev: Valeria',
        'Dev: DataSigh',
        'Dev: Emchikuwu',
        'Dev: Teletubbieshoi',
        'Dev: Kardashszn',
        'Dev: Halohashira',
        'Dev: Qetsiyah',
        'Dev: CleoSowande',
        'Dev: ChowLlama',
        'Dev: AnimateWithRick',
        'Dev: agussts_13',
    },
    Multi = false,
    Default = 1,
})

FireCircleColorDropdown:OnChanged(function(Value)
    local selected = type(Value) == 'table' and Value[1] or Value
    updateFireCircleColor(selected)
    if not isInitializing then
        Fluent:Notify({
            Title = 'Fire Circle Color',
            Content = 'Color set to: ' .. selected,
            Duration = 2,
        })
    end
end)

-- Fire Circle Toggle
local FireCircleToggle = CustomTab:AddToggle('FireCircle', {
    Title = 'Enable Custom Fire Circle',
    Default = false,
})

FireCircleToggle:OnChanged(function(Value)
    if Value then
        enableFireCircleHook()
        if not isInitializing then
            Fluent:Notify({
                Title = 'Fire Circle',
                Content = 'Custom colors enabled ('
                    .. selectedFireCircleColor
                    .. ')',
                Duration = 2,
            })
        end
    else
        disableFireCircleHook()
        if not isInitializing then
            Fluent:Notify({
                Title = 'Fire Circle',
                Content = 'Custom colors disabled',
                Duration = 2,
            })
        end
    end
end)

-- Custom Incendia Section
CustomTab:AddParagraph({
    Title = 'Custom Incendia',
    Content = 'Customize Incendia ability colors',
})

-- Incendia color variables
local selectedIncendiaColor = 'Blue'
local INCENDIA_COLOR = ColorSequence.new(Color3.fromRGB(0, 100, 255))
local customIncendiaActive = false
local incendiaRainbowActive = false
local incendiaRainbowLoop = nil
local myRecentHits = {}
local myFireballGuids = {}
local originalIncendiaBegin = nil
local originalIncendiaFireballHit = nil

local function updateIncendiaColor(colorName)
    -- Stop rainbow if switching to a static color
    if colorName ~= 'Rainbow' and incendiaRainbowActive then
        incendiaRainbowActive = false
        if incendiaRainbowLoop then
            task.cancel(incendiaRainbowLoop)
            incendiaRainbowLoop = nil
        end
    end

    if colorName == 'Rainbow' then
        incendiaRainbowActive = true
        selectedIncendiaColor = 'Rainbow'

        -- Start rainbow loop (always start when rainbow is selected)
        if not incendiaRainbowLoop then
            incendiaRainbowLoop = task.spawn(function()
                local hue = 0
                local Players = game:GetService('Players')
                local LocalPlayer = Players.LocalPlayer

                local CollectionService = game:GetService('CollectionService')

                while incendiaRainbowActive do
                    hue = (hue + 0.01) % 1
                    local color = Color3.fromHSV(hue, 1, 1)
                    INCENDIA_COLOR = ColorSequence.new(color)
                    _G.__INCENDIA_RAINBOW_COLOR = INCENDIA_COLOR -- Update global for new particles

                    -- Update player attribute if active
                    if customIncendiaActive and LocalPlayer then
                        LocalPlayer:SetAttribute('CustomColor', INCENDIA_COLOR)

                        local char = LocalPlayer.Character
                        local colorRGB = Color3.fromHSV(hue, 1, 1)

                        -- Update character particles only (most visible) - OPTIMIZED
                        if char then
                            -- Cache descendants to avoid repeated GetDescendants calls
                            local descendants = char:GetDescendants()
                            for _, desc in ipairs(descendants) do
                                if desc:IsA('ParticleEmitter') then
                                    desc.Color = INCENDIA_COLOR
                                end
                                if desc:IsA('PointLight') then
                                    desc.Color = colorRGB
                                end
                            end
                        end

                        -- Update Incendia targets (burn effects) - optimized
                        local targets =
                            CollectionService:GetTagged('IncendiaTarget')
                        local maxTargets = math.min(#targets, 5) -- Limit to 5 targets max

                        for i = 1, maxTargets do
                            local target = targets[i]
                            if target and target:IsA('BasePart') then
                                target:SetAttribute('FireColor', INCENDIA_COLOR)

                                -- Particles are in the character's body parts
                                local parent = target.Parent
                                if parent then
                                    -- Check each body part (GetChildren, not GetDescendants)
                                    for _, bodyPart in
                                        ipairs(parent:GetChildren())
                                    do
                                        if
                                            bodyPart:IsA('BasePart')
                                            or bodyPart:IsA('MeshPart')
                                        then
                                            -- Update particles in this body part
                                            for _, child in
                                                ipairs(bodyPart:GetChildren())
                                            do
                                                if
                                                    child:IsA('ParticleEmitter')
                                                then
                                                    child.Color = INCENDIA_COLOR
                                                elseif
                                                    child:IsA('PointLight')
                                                then
                                                    child.Color = colorRGB
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.1) -- Slower for better performance
                end
            end)
        end
        print('[INCENDIA] Rainbow mode enabled')
    else
        local color = COLOR_PRESETS[colorName]
        if color then
            INCENDIA_COLOR =
                ColorSequence.new(Color3.fromRGB(color.r, color.g, color.b))
            selectedIncendiaColor = colorName

            -- Update player attribute if active
            if customIncendiaActive then
                local Players = game:GetService('Players')
                local LocalPlayer = Players.LocalPlayer
                if LocalPlayer then
                    LocalPlayer:SetAttribute('CustomColor', INCENDIA_COLOR)
                end
            end

            print('[INCENDIA] Color updated to:', colorName)
        end
    end
end

local function enableIncendiaHook()
    if customIncendiaActive then
        return
    end
    customIncendiaActive = true

    local Players = game:GetService('Players')
    local CollectionService = game:GetService('CollectionService')
    local LocalPlayer = Players.LocalPlayer

    -- Set initial color
    LocalPlayer:SetAttribute('CustomColor', INCENDIA_COLOR)

    -- Get Incendia module
    local success, IncendiaModule = pcall(function()
        return LocalPlayer.PlayerScripts.ModuleScripts.AbilityHandler.Incendia
    end)

    if not success or not IncendiaModule then
        warn('[INCENDIA] Failed to find Incendia module')
        customIncendiaActive = false
        return
    end

    local Incendia = require(IncendiaModule)

    -- Hook begin function
    if not originalIncendiaBegin then
        originalIncendiaBegin = Incendia.begin
        Incendia.begin = function(p, g, c, t)
            if p == LocalPlayer and customIncendiaActive then
                p:SetAttribute('CustomColor', INCENDIA_COLOR)
                myFireballGuids[g] = true
                local hitPos = c.Position + (c.LookVector * 200)
                table.insert(myRecentHits, {
                    position = hitPos,
                    time = tick(),
                })
            end
            return originalIncendiaBegin(p, g, c, t)
        end
    end

    -- Hook fireballHit function
    if not originalIncendiaFireballHit then
        originalIncendiaFireballHit = Incendia.fireballHit
        Incendia.fireballHit = function(guid, position, color)
            local useCustom = customIncendiaActive and myFireballGuids[guid]
            if useCustom then
                myFireballGuids[guid] = nil
            end
            return originalIncendiaFireballHit(
                guid,
                position,
                useCustom and INCENDIA_COLOR or color
            )
        end
    end

    -- Target color handler
    local function setTargetColor(target)
        if not customIncendiaActive or not target:IsA('BasePart') then
            return
        end

        local char = LocalPlayer.Character
        if char and target:IsDescendantOf(char) then
            target:SetAttribute('FireColor', INCENDIA_COLOR)
            return
        end

        -- Clean up old hits
        for i = #myRecentHits, 1, -1 do
            if tick() - myRecentHits[i].time > 3 then
                table.remove(myRecentHits, i)
            end
        end

        -- Check proximity to recent hits
        local targetPos = target.Position
        for _, hit in ipairs(myRecentHits) do
            if (targetPos - hit.position).Magnitude < 50 then
                target:SetAttribute('FireColor', INCENDIA_COLOR)
                return
            end
        end
    end

    -- Connect to new targets
    CollectionService:GetInstanceAddedSignal('IncendiaTarget')
        :Connect(setTargetColor)

    -- Process existing targets
    local existingTargets = CollectionService:GetTagged('IncendiaTarget')
    for i = 1, #existingTargets do
        setTargetColor(existingTargets[i])
    end

    print('[INCENDIA] Custom colors enabled')
end

local function disableIncendiaHook()
    if not customIncendiaActive then
        return
    end
    customIncendiaActive = false

    -- Stop rainbow
    incendiaRainbowActive = false
    if incendiaRainbowLoop then
        task.cancel(incendiaRainbowLoop)
        incendiaRainbowLoop = nil
    end

    -- Disconnect particle watcher
    if incendiaParticleConnection then
        incendiaParticleConnection:Disconnect()
        incendiaParticleConnection = nil
    end

    -- Clear tracking tables
    table.clear(myRecentHits)
    table.clear(myFireballGuids)

    print('[INCENDIA] Custom colors disabled')
end

-- Incendia Color Dropdown
local IncendiaColorDropdown = CustomTab:AddDropdown('IncendiaColor', {
    Title = 'Incendia Color',
    Values = {
        'Purple',
        'Blue',
        'Red',
        'Green',
        'Yellow',
        'Orange',
        'Pink',
        'Cyan',
        'White',
        'Black',
        'Rainbow',
    },
    Multi = false,
    Default = 2, -- Blue
})

IncendiaColorDropdown:OnChanged(function(Value)
    local selected = type(Value) == 'table' and Value[1] or Value
    updateIncendiaColor(selected)
    if not isInitializing then
        Fluent:Notify({
            Title = 'Incendia Color',
            Content = 'Color set to: ' .. selected,
            Duration = 2,
        })
    end
end)

-- Developer Colors Dropdown
local DeveloperColorDropdown = CustomTab:AddDropdown('DeveloperColor', {
    Title = 'Developer Colors',
    Values = {
        'Luna',
        'Marina',
        'Raven',
        'TheGrinch',
        'TheDeer',
        'Elora',
        'Valeria',
        'DataSigh',
        'Emchikuwu',
        'Teletubbieshoi',
        'Kardashszn',
        'Halohashira',
        'Qetsiyah',
        'CleoSowande',
        'ChowLlama',
        'AnimateWithRick',
        'agussts_13',
    },
    Multi = false,
    Default = 1,
})

DeveloperColorDropdown:OnChanged(function(Value)
    local selected = type(Value) == 'table' and Value[1] or Value
    local devColor = DEVELOPER_COLORS[selected]
    if devColor then
        INCENDIA_COLOR = devColor
        selectedIncendiaColor = 'Dev: ' .. selected

        -- Update player attribute if active
        if customIncendiaActive then
            local Players = game:GetService('Players')
            local LocalPlayer = Players.LocalPlayer
            if LocalPlayer then
                LocalPlayer:SetAttribute('CustomColor', INCENDIA_COLOR)
            end
        end

        if not isInitializing then
            Fluent:Notify({
                Title = 'Developer Color',
                Content = 'Set to: ' .. selected,
                Duration = 2,
            })
        end
    end
end)

-- Incendia Toggle
local IncendiaToggle = CustomTab:AddToggle('CustomIncendia', {
    Title = 'Enable Custom Incendia',
    Default = false,
})

IncendiaToggle:OnChanged(function(Value)
    if Value then
        enableIncendiaHook()
        if not isInitializing then
            Fluent:Notify({
                Title = 'Custom Incendia',
                Content = 'Enabled (' .. selectedIncendiaColor .. ')',
                Duration = 2,
            })
        end
    else
        disableIncendiaHook()
        if not isInitializing then
            Fluent:Notify({
                Title = 'Custom Incendia',
                Content = 'Disabled',
                Duration = 2,
            })
        end
    end
end)

-- 👔 OUTFIT SYSTEM BACKEND 👔
if not _G.OutfitCache then
    _G.OutfitCache = {}
end

local cache = _G.OutfitCache

local PATHS_TO_CACHE = {
    { 'Heretic', 'Luna', 'Default' },
    { 'Heretic', 'ChowLlama', 'Default' },
    { 'Heretic', 'Valeria', 'Default' },
    { 'Heretic', 'Elora', 'Default' },
    { 'Heretic', 'Marina', 'Default' },
    { 'Heretic', 'agussts_13', 'Default' },
    { 'Heretic', 'Emchikuwu', 'Default' },
    { 'Heretic', 'Kardashszn', 'Default' },
}

local function getOutfitCharacters()
    local chars = {}
    local seen = {}
    for _, path in ipairs(PATHS_TO_CACHE) do
        if #path >= 2 then
            local charName = path[2]
            if not seen[charName] then
                table.insert(chars, charName)
                seen[charName] = true
            end
        end
    end
    table.sort(chars)
    return chars
end

local function scanReplicationTarget()
    local Players = game:GetService('Players')
    local LocalPlayer = Players.LocalPlayer
    
    if not LocalPlayer then
        warn('[Outfit] LocalPlayer not available')
        return 0
    end
    
    local rootFolder = LocalPlayer.PlayerGui:FindFirstChild('ReplicationTarget')

    if not rootFolder then
        warn('[Outfit] ReplicationTarget not found')
        print(
            '[Outfit] PlayerGui contents:',
            table.concat(
                (function()
                    local t = {}
                    for _, v in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                        table.insert(t, v.Name)
                    end
                    return t
                end)(),
                ', '
            )
        )
        return 0
    end

    print(
        '[Outfit] ReplicationTarget found! Contents:',
        table.concat(
            (function()
                local t = {}
                for _, v in ipairs(rootFolder:GetChildren()) do
                    table.insert(t, v.Name .. ':' .. v.ClassName)
                end
                return t
            end)(),
            ', '
        )
    )

    local totalAdded = 0
    local totalUpdated = 0

    for _, pathTable in ipairs(PATHS_TO_CACHE) do
        local current = rootFolder
        local pathString = table.concat(pathTable, '.')
        local success = true

        print(string.format('[Outfit] Attempting to cache: %s', pathString))

        for i, folderName in ipairs(pathTable) do
            local next = current:FindFirstChild(folderName)
            if not next then
                warn(
                    string.format(
                        '[Outfit] Path not found: %s (missing: %s)',
                        pathString,
                        folderName
                    )
                )
                success = false
                break
            end
            print(
                string.format(
                    '[Outfit] Found: %s (Type: %s)',
                    folderName,
                    next.ClassName
                )
            )
            current = next
        end

        if success and current:IsA('Model') then
            local modelClone = current:Clone()
            local childCount = #modelClone:GetChildren()

            if not cache[pathString] then
                cache[pathString] = modelClone
                totalAdded = totalAdded + 1
                print(
                    string.format(
                        '[Outfit] Cached NEW: %s (%d children)',
                        pathString,
                        childCount
                    )
                )
            else
                cache[pathString] = modelClone
                totalUpdated = totalUpdated + 1
                print(
                    string.format(
                        '[Outfit] Updated: %s (%d children)',
                        pathString,
                        childCount
                    )
                )
            end
        elseif success then
            warn(
                string.format(
                    '[Outfit] Not a Model: %s (Type: %s)',
                    pathString,
                    current.ClassName
                )
            )
        end
    end

    print(
        string.format(
            '[Outfit] Scan complete: %d new, %d updated',
            totalAdded,
            totalUpdated
        )
    )
    return totalAdded + totalUpdated
end

local selectedName = nil
local currentEntity = nil
local deathConnection = nil

local function getPlayerEntity()
    local entities = workspace:FindFirstChild('Entities')
    if not entities then
        return nil
    end

    local candidate = entities:FindFirstChild(LocalPlayer.Name)
    if candidate then
        return candidate
    end

    for _, m in ipairs(entities:GetChildren()) do
        if
            m:IsA('Model')
            and (
                m:GetAttribute('Owner') == LocalPlayer
                or m:GetAttribute('OwnerUserId') == LocalPlayer.UserId
            )
        then
            return m
        end
    end
    return nil
end

local function clearVisuals(model)
    if not model then
        return
    end

    print('[OutfitGUI] Clearing old outfit...')

    -- Clear Accessories folder completely
    local accFolder = model:FindFirstChild('Accessories')
    if accFolder then
        accFolder:ClearAllChildren()
        print('[OutfitGUI] Cleared Accessories folder')
    end

    -- Clear Faces folder completely
    local facesFolder = model:FindFirstChild('Faces')
    if facesFolder then
        facesFolder:ClearAllChildren()
        print('[OutfitGUI] Cleared Faces folder')
    end

    -- Clear all accessories/clothing/etc from entire model (including descendants)
    for _, inst in ipairs(model:GetDescendants()) do
        if
            inst:IsA('Accessory')
            or inst:IsA('Hat')
            or inst:IsA('Shirt')
            or inst:IsA('Pants')
            or inst:IsA('ShirtGraphic')
            or inst:IsA('BodyColors')
            or inst:IsA('CharacterMesh')
        then
            inst:Destroy()
        end
    end

    -- Clear ALL decals from Head (face expressions, etc.)
    local head = model:FindFirstChild('Head')
    if head then
        for _, decal in ipairs(head:GetChildren()) do
            if decal:IsA('Decal') then
                decal:Destroy()
            end
        end
        print('[OutfitGUI] Cleared all decals from Head')
    end

    -- Clear any old outfit parts from workspace
    for _, part in ipairs(workspace:GetChildren()) do
        if part.Name == 'OutfitClone' and part:IsA('BasePart') then
            part:Destroy()
        end
    end

    print('[OutfitGUI] Cleared successfully')
end

local function findClosestBodyPart(accessory, sourceModel, entityModel)
    -- METHOD 1: Check WeldConstraint (most accurate)
    local weldConstraint = accessory:FindFirstChildOfClass('WeldConstraint')
    if weldConstraint then
        -- Try Part1 first (usually the body part)
        if weldConstraint.Part1 and weldConstraint.Part1 ~= accessory then
            local part1Name = weldConstraint.Part1.Name
            local entityPart = entityModel:FindFirstChild(part1Name)
            if entityPart then
                print(
                    string.format(
                        '[OutfitGUI] %s using WeldConstraint.Part1 -> %s',
                        accessory.Name,
                        part1Name
                    )
                )
                return entityPart
            else
                warn(
                    string.format(
                        "[OutfitGUI] %s WeldConstraint.Part1 '%s' not found in entity",
                        accessory.Name,
                        part1Name
                    )
                )
            end
        end

        -- Try Part0 as fallback (in case Part1 is the accessory itself)
        if weldConstraint.Part0 and weldConstraint.Part0 ~= accessory then
            local part0Name = weldConstraint.Part0.Name
            local entityPart = entityModel:FindFirstChild(part0Name)
            if entityPart then
                print(
                    string.format(
                        '[OutfitGUI] %s using WeldConstraint.Part0 -> %s',
                        accessory.Name,
                        part0Name
                    )
                )
                return entityPart
            else
                warn(
                    string.format(
                        "[OutfitGUI] %s WeldConstraint.Part0 '%s' not found in entity",
                        accessory.Name,
                        part0Name
                    )
                )
            end
        end
    end

    -- METHOD 2: Check regular Weld
    local weld = accessory:FindFirstChildOfClass('Weld')
    if weld then
        -- Try Part0 first (usually the body part for regular Welds)
        if weld.Part0 and weld.Part0 ~= accessory then
            local part0Name = weld.Part0.Name
            local entityPart = entityModel:FindFirstChild(part0Name)
            if entityPart then
                print(
                    string.format(
                        '[OutfitGUI] %s using Weld.Part0 -> %s',
                        accessory.Name,
                        part0Name
                    )
                )
                return entityPart
            end
        end

        -- Try Part1 as fallback
        if weld.Part1 and weld.Part1 ~= accessory then
            local part1Name = weld.Part1.Name
            local entityPart = entityModel:FindFirstChild(part1Name)
            if entityPart then
                print(
                    string.format(
                        '[OutfitGUI] %s using Weld.Part1 -> %s',
                        accessory.Name,
                        part1Name
                    )
                )
                return entityPart
            end
        end
    end

    -- METHOD 3: Name-based hints for common accessories
    local nameHints = {
        ['necklace'] = 'UpperTorso',
        ['pendant'] = 'UpperTorso',
        ['chain'] = 'UpperTorso',
        ['collar'] = 'UpperTorso',
        ['tie'] = 'UpperTorso',
        ['scarf'] = 'UpperTorso',
        ['cape'] = 'UpperTorso',
        ['wings'] = 'UpperTorso',
        ['backpack'] = 'UpperTorso',
        ['belt'] = 'LowerTorso',
        ['waist'] = 'LowerTorso',
        ['hat'] = 'Head',
        ['hair'] = 'Head',
        ['mask'] = 'Head',
        ['glasses'] = 'Head',
        ['crown'] = 'Head',
        ['helmet'] = 'Head',
    }

    local lowerName = accessory.Name:lower()
    for keyword, bodyPart in pairs(nameHints) do
        if lowerName:find(keyword) then
            local hintedPart = entityModel:FindFirstChild(bodyPart)
            if hintedPart then
                print(
                    string.format(
                        "[OutfitGUI] %s matched hint '%s' -> %s",
                        accessory.Name,
                        keyword,
                        bodyPart
                    )
                )
                return hintedPart
            end
        end
    end

    -- METHOD 4: Fall back to distance-based detection
    local bodyParts = {
        'Head',
        'UpperTorso',
        'LowerTorso',
        'LeftUpperArm',
        'LeftLowerArm',
        'LeftHand',
        'RightUpperArm',
        'RightLowerArm',
        'RightHand',
        'LeftUpperLeg',
        'LeftLowerLeg',
        'LeftFoot',
        'RightUpperLeg',
        'RightLowerLeg',
        'RightFoot',
    }

    local closestPart = nil
    local closestDistance = math.huge

    for _, partName in ipairs(bodyParts) do
        local sourcePart = sourceModel:FindFirstChild(partName)
        if sourcePart and sourcePart:IsA('BasePart') then
            local distance = (accessory.Position - sourcePart.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestPart = partName
            end
        end
    end

    -- Debug logging
    if closestPart then
        print(
            string.format(
                '[OutfitGUI] %s closest to %s (distance: %.2f)',
                accessory.Name,
                closestPart,
                closestDistance
            )
        )
    else
        warn(
            '[OutfitGUI] Could not find closest body part for:',
            accessory.Name
        )
    end

    -- Find corresponding part in entity
    if closestPart then
        local entityPart = entityModel:FindFirstChild(closestPart)
        if not entityPart then
            warn(
                '[OutfitGUI] Entity missing body part:',
                closestPart,
                'for accessory:',
                accessory.Name
            )
        end
        return entityPart
    end
    return nil
end

local function attachCloneToEntity(entity, source)
    if not entity or not source then
        return
    end

    print('[OutfitGUI] Applying outfit from:', source.Name)
    print(
        '[OutfitGUI] Source has these folders:',
        table.concat(
            (function()
                local t = {}
                for _, v in ipairs(source:GetChildren()) do
                    if v:IsA('Folder') then
                        table.insert(t, v.Name)
                    end
                end
                return t
            end)(),
            ', '
        )
    )

    local itemsAdded = 0

    -- Get or create Accessories folder
    local accFolder = entity:FindFirstChild('Accessories')
    if not accFolder then
        accFolder = Instance.new('Folder')
        accFolder.Name = 'Accessories'
        accFolder.Parent = entity
    end

    -- Get or create Faces folder
    local facesFolder = entity:FindFirstChild('Faces')
    if not facesFolder then
        facesFolder = Instance.new('Folder')
        facesFolder.Name = 'Faces'
        facesFolder.Parent = entity
    end

    -- Clone and WELD items from source Accessories folder (custom Parts/MeshParts system)
    local sourceAccFolder = source:FindFirstChild('Accessories')
    if sourceAccFolder then
        local totalItems = #sourceAccFolder:GetDescendants()
        print(
            '[OutfitGUI] Found Accessories folder with',
            #sourceAccFolder:GetChildren(),
            'direct children and',
            totalItems,
            'total descendants'
        )
        local entityHead = entity:FindFirstChild('Head')

        -- Process ALL descendants (including items in subfolders like "Outfit")
        for _, item in ipairs(sourceAccFolder:GetDescendants()) do
            if item:IsA('BasePart') or item:IsA('MeshPart') then
                print(
                    '[OutfitGUI] Cloning from Accessories:',
                    item.Name,
                    'Type:',
                    item.ClassName,
                    'Parent:',
                    item.Parent.Name
                )
                -- Find which body part this accessory is closest to
                local targetPart = findClosestBodyPart(item, source, entity)

                if targetPart then
                    -- Clone the part
                    local clone = item:Clone()
                    clone.Name = 'OutfitClone' -- Name it so it can be cleared later
                    clone.Anchored = false
                    clone.CanCollide = false
                    clone.Massless = true

                    -- Parent to Accessories folder first
                    clone.Parent = accFolder

                    -- Try to copy original WeldConstraint offsets (most accurate)
                    local originalWeldConstraint =
                        item:FindFirstChildOfClass('WeldConstraint')
                    local originalWeld = item:FindFirstChildOfClass('Weld')

                    local c0Offset = CFrame.new()
                    local c1Offset = CFrame.new()

                    if originalWeldConstraint then
                        -- WeldConstraints don't have C0/C1, so calculate from positions
                        local sourceTargetPart =
                            source:FindFirstChild(targetPart.Name)
                        if sourceTargetPart then
                            c0Offset = sourceTargetPart.CFrame:inverse()
                                * item.CFrame
                        end
                    elseif originalWeld then
                        -- Copy C0/C1 from original Weld (most accurate!)
                        c0Offset = originalWeld.C0
                        c1Offset = originalWeld.C1
                        print(
                            string.format(
                                '[OutfitGUI] Copying original Weld offsets for %s: C0=%s, C1=%s',
                                item.Name,
                                tostring(c0Offset),
                                tostring(c1Offset)
                            )
                        )
                    else
                        -- Fallback: calculate offset manually
                        local sourceTargetPart =
                            source:FindFirstChild(targetPart.Name)
                        if sourceTargetPart then
                            c0Offset = sourceTargetPart.CFrame:inverse()
                                * item.CFrame
                        end
                    end

                    -- Create weld with copied/calculated offsets
                    local weld = Instance.new('Weld')
                    weld.Part0 = targetPart
                    weld.Part1 = clone
                    weld.C0 = c0Offset
                    weld.C1 = c1Offset
                    weld.Parent = clone

                    itemsAdded = itemsAdded + 1
                    print(
                        '[OutfitGUI] Welded accessory to',
                        targetPart.Name .. ':',
                        item.Name,
                        '-> OutfitClone in Accessories folder'
                    )
                end
            end
        end
    else
        print('[OutfitGUI] No Accessories folder in source')
    end

    -- Handle Faces folder (Parts/MeshParts only, NOT Decals)
    local sourceFacesFolder = source:FindFirstChild('Faces')
    if sourceFacesFolder then
        print(
            '[OutfitGUI] Found Faces folder with',
            #sourceFacesFolder:GetChildren(),
            'items'
        )
        local entityHead = entity:FindFirstChild('Head')

        for _, item in ipairs(sourceFacesFolder:GetChildren()) do
            print(
                '[OutfitGUI] Cloning from Faces:',
                item.Name,
                'Type:',
                item.ClassName
            )

            -- Skip decals in Faces folder - we'll handle the face decal separately from Head
            if item:IsA('BasePart') or item:IsA('MeshPart') then
                -- Face parts should always weld to Head
                local entityHead = entity:FindFirstChild('Head')
                local sourceHead = source:FindFirstChild('Head')

                if entityHead and sourceHead then
                    local clone = item:Clone()
                    clone.Name = 'OutfitClone' -- Name it so it can be cleared later
                    clone.Anchored = false
                    clone.CanCollide = false
                    clone.Massless = true

                    -- Calculate offset from source Head to this part
                    local offset = sourceHead.CFrame:inverse() * item.CFrame

                    -- Parent to Faces folder (keeps it organized)
                    clone.Parent = facesFolder

                    -- Create weld so it follows the head
                    local weld = Instance.new('Weld')
                    weld.Part0 = entityHead
                    weld.Part1 = clone
                    weld.C0 = offset
                    weld.C1 = CFrame.new()
                    weld.Parent = clone

                    itemsAdded = itemsAdded + 1
                    print(
                        '[OutfitGUI] Welded face part to Head:',
                        item.Name,
                        '-> OutfitClone in Faces folder'
                    )
                end
            else
                -- Other items go to folder
                local clone = item:Clone()
                clone.Parent = facesFolder
                itemsAdded = itemsAdded + 1
            end
        end
    else
        print('[OutfitGUI] No Faces folder in source')
    end

    -- Clone accessories from source root
    for _, obj in ipairs(source:GetChildren()) do
        if obj:IsA('Accessory') then
            local clone = obj:Clone()
            clone.Parent = accFolder
            itemsAdded = itemsAdded + 1
            print('[OutfitGUI] Added root accessory:', clone.Name)
        end
    end

    -- Clone the single face decal from source Head
    local sourceHead = source:FindFirstChild('Head')
    local entityHead = entity:FindFirstChild('Head')
    if sourceHead and entityHead then
        -- Find the first Decal in source Head (e.g., "Luna")
        local sourceDecal = nil
        for _, child in ipairs(sourceHead:GetChildren()) do
            if child:IsA('Decal') then
                sourceDecal = child
                break
            end
        end

        if sourceDecal then
            local clone = sourceDecal:Clone()
            clone.Parent = entityHead
            itemsAdded = itemsAdded + 1
            print(
                string.format(
                    '[OutfitGUI] Added face decal from Head: %s (Texture: %s)',
                    sourceDecal.Name,
                    sourceDecal.Texture
                )
            )
        else
            warn('[OutfitGUI] No face decal found in source Head')
        end
    end

    -- Clone clothing
    for _, obj in ipairs(source:GetChildren()) do
        if obj:IsA('Shirt') or obj:IsA('Pants') or obj:IsA('ShirtGraphic') then
            local clone = obj:Clone()
            clone.Parent = entity
            itemsAdded = itemsAdded + 1
            print('[OutfitGUI] Added clothing:', obj.ClassName)
        end
    end

    -- Clone BodyColors
    for _, obj in ipairs(source:GetChildren()) do
        if obj:IsA('BodyColors') then
            local clone = obj:Clone()
            clone.Parent = entity
            itemsAdded = itemsAdded + 1
            print('[OutfitGUI] Added BodyColors')
        end
    end

    -- Copy skin tone from body parts
    local bodyParts = {
        'Head',
        'UpperTorso',
        'LowerTorso',
        'LeftUpperArm',
        'LeftLowerArm',
        'LeftHand',
        'RightUpperArm',
        'RightLowerArm',
        'RightHand',
        'LeftUpperLeg',
        'LeftLowerLeg',
        'LeftFoot',
        'RightUpperLeg',
        'RightLowerLeg',
        'RightFoot',
        'Torso',
        'Left Arm',
        'Right Arm',
        'Left Leg',
        'Right Leg',
    }

    for _, partName in ipairs(bodyParts) do
        local sourcePart = source:FindFirstChild(partName)
        local entityPart = entity:FindFirstChild(partName)

        if
            sourcePart
            and entityPart
            and sourcePart:IsA('BasePart')
            and entityPart:IsA('BasePart')
        then
            -- Copy both Color and BrickColor to ensure compatibility
            entityPart.Color = sourcePart.Color
            entityPart.BrickColor = sourcePart.BrickColor
            print(
                string.format(
                    '[OutfitGUI] Copied skin tone for %s: %s',
                    partName,
                    tostring(sourcePart.BrickColor)
                )
            )
        end
    end

    -- Clone CharacterMesh
    for _, obj in ipairs(source:GetChildren()) do
        if obj:IsA('CharacterMesh') then
            local clone = obj:Clone()
            clone.Parent = entity
            itemsAdded = itemsAdded + 1
            print('[OutfitGUI] Added CharacterMesh:', obj.BodyPart.Name)
        end
    end

    print(string.format('[OutfitGUI] Applied outfit: %d items', itemsAdded))
end

local function setupDeathDetection(entity)
    -- Disconnect previous death connection if it exists
    if deathConnection then
        deathConnection:Disconnect()
        deathConnection = nil
    end

    if not entity then
        return
    end

    local humanoid = entity:FindFirstChildOfClass('Humanoid')
    if humanoid then
        -- Listen for death event
        deathConnection = humanoid.Died:Connect(function()
            print('[OutfitGUI] Player died - clearing outfit')
            clearVisuals(entity)
            currentEntity = nil
        end)
        print('[OutfitGUI] Death detection enabled')
    else
        warn('[OutfitGUI] No Humanoid found - death detection disabled')
    end

    -- Also detect if entity is removed from workspace
    entity.AncestryChanged:Connect(function(_, parent)
        if not parent then
            print('[OutfitGUI] Entity removed - clearing outfit')
            clearVisuals(entity)
            currentEntity = nil
            if deathConnection then
                deathConnection:Disconnect()
                deathConnection = nil
            end
        end
    end)
end

local function applySelection()
    if not selectedName then
        warn('[OutfitGUI] No outfit selected')
        return
    end

    print('[OutfitGUI] ========== APPLYING OUTFIT ==========')
    print('[OutfitGUI] Selected outfit:', selectedName)
    print(
        '[OutfitGUI] Cache contents:',
        table.concat(
            (function()
                local t = {}
                for k, _ in pairs(cache) do
                    table.insert(t, k)
                end
                return t
            end)(),
            ', '
        )
    )

    local src = cache[selectedName]
    if not src then
        warn('[OutfitGUI] Outfit not found in cache:', selectedName)
        warn(
            '[OutfitGUI] Available in cache:',
            table.concat(
                (function()
                    local t = {}
                    for k, _ in pairs(cache) do
                        table.insert(t, k)
                    end
                    return t
                end)(),
                ', '
            )
        )
        return
    end

    print('[OutfitGUI] Source model found:', src.Name)

    local entity = getPlayerEntity()
    if not entity then
        warn('[OutfitGUI] Player entity not found in workspace.Entities')
        local entities = workspace:FindFirstChild('Entities')
        if entities then
            print(
                '[OutfitGUI] Entities folder contents:',
                table.concat(
                    (function()
                        local t = {}
                        for _, v in ipairs(entities:GetChildren()) do
                            table.insert(t, v.Name)
                        end
                        return t
                    end)(),
                    ', '
                )
            )
        else
            warn('[OutfitGUI] Entities folder not found in workspace')
        end
        return
    end

    print('[OutfitGUI] Entity found:', entity.Name)
    clearVisuals(entity)
    attachCloneToEntity(entity, src)
    currentEntity = entity
    setupDeathDetection(entity)
    print('[OutfitGUI] ========== OUTFIT APPLIED ==========')
end

-- BACKWARD COMPATIBILITY: Keep old applyOutfit function that wraps applySelection
local function applyOutfit(outfitName)
    selectedName = outfitName
    applySelection()
    return true, 'Applied'
end

local function getOutfitsForCharacter(characterName)
    local outfits = {}
    for name, _ in pairs(cache) do
        if name:match('%w+%.' .. characterName .. '%.%w+') then
            table.insert(outfits, name)
        end
    end
    table.sort(outfits)
    return outfits
end

local OutfitTab = CreateDummyTab()

OutfitTab:AddParagraph({
    Title = '👔 Outfit System',
    Content = 'Clone and apply character outfits',
})

local outfitCharacters = getOutfitCharacters()
local selectedCharacter = outfitCharacters[1] or 'Luna' -- Default to first character in sorted list
local CharacterDropdown = OutfitTab:AddDropdown('CharacterSelect', {
    Title = 'Select Character',
    Description = 'Choose which character to load outfits from',
    Values = outfitCharacters,
    Default = 1,
    Callback = function(Value)
        selectedCharacter = Value
        print('[Outfit] Selected character:', Value)
    end,
})

OutfitTab:AddButton({
    Title = '📦 Cache Models',
    Description = 'Scan and cache outfits from ReplicationTarget',
    Callback = function()
        Fluent:Notify({
            Title = 'Caching Outfits',
            Content = 'Scanning ReplicationTarget...',
            Duration = 2,
        })

        local count = scanReplicationTarget()

        Fluent:Notify({
            Title = 'Cache Complete',
            Content = 'Cached ' .. count .. ' outfit(s)',
            Duration = 3,
        })
    end,
})

OutfitTab:AddButton({
    Title = '✨ Apply Outfit',
    Description = 'Apply the selected character outfit',
    Callback = function()
        if not selectedCharacter then
            Fluent:Notify({
                Title = 'No Character Selected',
                Content = 'Please select a character first',
                Duration = 3,
            })
            return
        end

        local outfits = getOutfitsForCharacter(selectedCharacter)

        if #outfits == 0 then
            Fluent:Notify({
                Title = 'No Outfits Cached',
                Content = 'Cache models first by clicking "Cache Models"',
                Duration = 3,
            })
            return
        end

        local success, message = applyOutfit(outfits[1])

        if success then
            Fluent:Notify({
                Title = 'Outfit Applied',
                Content = message,
                Duration = 3,
            })
        else
            Fluent:Notify({
                Title = 'Error',
                Content = message,
                Duration = 3,
            })
        end
    end,
})

OutfitTab:AddParagraph({
    Title = 'ℹ️ How to Use',
    Content = '1. Click "Cache Models" to scan outfits ( only in lobby )\n2. Select a character from the dropdown\n3. Click "Apply Outfit" to equip',
})

-- AUTO-CACHING DISABLED - Use "Cache Models" button instead
--[[
local hasAutoCached = false
task.spawn(function()
    local Players = game:GetService('Players')
    local LocalPlayer = Players.LocalPlayer

    while not hasAutoCached do
        local success = pcall(function()
            local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
            if not playerGui then
                return
            end

            local startScreen = playerGui:FindFirstChild('StartScreen')
            if not startScreen then
                return
            end

            local mainHolder = startScreen:FindFirstChild('MainHolder')
            if not mainHolder then
                return
            end

            local selectFrame =
                mainHolder:FindFirstChild('SelectCharacterFrame')
            if selectFrame and selectFrame.Visible then
                hasAutoCached = true
                print('[Outfit] Auto-caching outfits...')

                task.wait(0.5)
                local count = scanReplicationTarget()

                if count > 0 then
                    Fluent:Notify({
                        Title = '👔 Outfits Auto-Cached',
                        Content = 'Cached ' .. count .. ' outfit(s)',
                        Duration = 3,
                    })
                end
            end
        end)

        if not hasAutoCached then
            task.wait(1)
        end
    end
end)
--]]

-- ⚡ STAFF NOTIFIER TAB ⚡
local StaffNotifierTab = CreateDummyTab()

StaffNotifierTab:AddParagraph({
    Title = 'Staff Notifier',
    Content = 'Get notified when staff members join the game. Fully compatible with moonsec v3 obfuscation.',
})

-- Staff notifier state
_G.STAFF_WEBHOOK_URL = _G.STAFF_WEBHOOK_URL or ''
_G.STAFF_NOTIFIER_ENABLED = true -- Automatically enabled on script execution
_G.STAFF_DETECTION_METHODS = _G.STAFF_DETECTION_METHODS
    or {
        group_check = true, -- Only method - uses groupRoles table
    }

-- Known staff user IDs (add known staff IDs here)
local KNOWN_STAFF_IDS = {
    -- Add staff user IDs here if known
}

-- HTTP request function compatible with most executors (moonsec obfuscation proof)
local function sendWebhookNotification(webhookUrl, embedData)
    if not webhookUrl or webhookUrl == '' then
        warn('[Staff Notifier] No webhook URL configured')
        return false
    end

    -- Try multiple HTTP request methods for maximum executor compatibility
    local httpRequest = (syn and syn.request)
        or (http and http.request)
        or http_request
        or (fluxus and fluxus.request)
        or request
        or (http_request and http_request)

    if not httpRequest then
        warn(
            '[Staff Notifier] HTTP request function not available in this executor'
        )
        return false
    end

    -- Use game service directly to avoid obfuscation issues
    local HttpService = game:GetService('HttpService')

    -- Sanitize fields to ensure all values are proper types
    local sanitizedFields = {}
    if embedData.fields then
        for _, field in ipairs(embedData.fields) do
            table.insert(sanitizedFields, {
                name = tostring(field.name or ''),
                value = tostring(field.value or ''),
                inline = field.inline == true,
            })
        end
    end

    local payload = HttpService:JSONEncode({
        embeds = {
            {
                title = tostring(embedData.title or 'Staff Member Detected'),
                description = tostring(
                    embedData.description
                        or 'A staff member has joined the game!'
                ),
                color = tonumber(embedData.color) or 15158332, -- Red color
                fields = sanitizedFields,
                footer = {
                    text = tostring(
                        'TVL Staff Notifier • ' .. os.date('%I:%M %p')
                    ),
                },
                timestamp = tostring(os.date('!%Y-%m-%dT%H:%M:%S') .. 'Z'),
            },
        },
    })

    local success, response = pcall(function()
        return httpRequest({
            Url = webhookUrl,
            Method = 'POST',
            Headers = {
                ['Content-Type'] = 'application/json',
            },
            Body = payload,
        })
    end)

    if
        success
        and response
        and (response.StatusCode == 204 or response.StatusCode == 200)
    then
        print('[Staff Notifier] Webhook sent successfully')
        return true
    else
        warn(
            '[Staff Notifier] Failed to send webhook:',
            response and response.StatusCode or 'Unknown error'
        )
        return false
    end
end

-- Obfuscation-proof staff detection
local function isStaffMember(player)
    local reasons = {}

    -- Method 1: Check user ID against known staff
    if table.find(KNOWN_STAFF_IDS, player.UserId) then
        table.insert(reasons, 'Known Staff ID')
        return true, reasons
    end

    -- Method 2: Check group roles (only check specific groups from groupRoles table)
    -- Uses Roblox API - works even in fully obfuscated games
    if _G.STAFF_DETECTION_METHODS.group_check then
        local success, groups = pcall(function()
            -- Use GetService to ensure proper service access in obfuscated environments
            local GroupService = game:GetService('GroupService')
            return GroupService:GetGroupsAsync(player.UserId)
        end)

        if success and groups then
            for _, group in ipairs(groups) do
                -- Only check groups defined in the groupRoles table
                local groupId = group.Id
                if groupRoles[groupId] then
                    local staffConfig = groupRoles[groupId]
                    local roleName = group.Role or ''

                    -- Check if player's role is in the staff roles list
                    if staffConfig.roles[roleName] then
                        table.insert(
                            reasons,
                            'Group Role: '
                                .. roleName
                                .. ' in '
                                .. staffConfig.name
                        )
                        return true, reasons
                    end
                end
            end
        end
    end

    -- Method 3: Check for special attributes (set by game even when obfuscated)
    if
        player:GetAttribute('IsStaff')
        or player:GetAttribute('Staff')
        or player:GetAttribute('Admin')
        or player:GetAttribute('Moderator')
    then
        table.insert(reasons, 'Staff Attribute')
        return true, reasons
    end

    return false, reasons
end

-- Notification function
local function notifyStaff(player, reasons)
    if not _G.STAFF_NOTIFIER_ENABLED then
        return
    end

    print('[Staff Notifier] Staff member detected:', player.Name)

    -- Send Discord webhook
    if _G.STAFF_WEBHOOK_URL and _G.STAFF_WEBHOOK_URL ~= '' then
        local fields = {
            {
                name = '👤 Player',
                value = player.Name .. ' (@' .. player.DisplayName .. ')',
                inline = true,
            },
            {
                name = '🆔 User ID',
                value = tostring(player.UserId),
                inline = true,
            },
            {
                name = '📊 Account Age',
                value = player.AccountAge .. ' days',
                inline = true,
            },
            {
                name = '🎮 Server',
                value = game.JobId,
                inline = false,
            },
        }

        if #reasons > 0 then
            table.insert(fields, {
                name = '⚠️ Detection Reason',
                value = table.concat(reasons, '\n'),
                inline = false,
            })
        end

        sendWebhookNotification(_G.STAFF_WEBHOOK_URL, {
            title = '🚨 STAFF MEMBER DETECTED',
            description = 'A staff member has joined your server!',
            color = 15158332,
            fields = fields,
        })
    end

    -- In-game notification
    Fluent:Notify({
        Title = '🚨 Staff Alert',
        Content = player.Name .. ' (Staff) joined the game!',
        Duration = 8,
    })

    -- Play alert sound
    local sound = Instance.new('Sound')
    sound.SoundId = 'rbxassetid://6518811702' -- Alert sound
    sound.Volume = 0.5
    sound.Parent = game:GetService('SoundService')
    sound:Play()
    task.delay(3, function()
        sound:Destroy()
    end)
end

-- Monitor players
local function setupStaffMonitor()
    -- Check existing players
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= game.Players.LocalPlayer then
            task.spawn(function()
                local isStaff, reasons = isStaffMember(player)
                if isStaff then
                    notifyStaff(player, reasons)
                end
            end)
        end
    end

    -- Monitor new players
    game.Players.PlayerAdded:Connect(function(player)
        if not _G.STAFF_NOTIFIER_ENABLED then
            return
        end

        task.wait(1) -- Wait for player data to load

        task.spawn(function()
            local isStaff, reasons = isStaffMember(player)
            if isStaff then
                notifyStaff(player, reasons)
            end
        end)
    end)
end

-- UI Elements
StaffNotifierTab:AddParagraph({
    Title = '⚙️ Configuration',
    Content = 'Configure your staff notifier settings below',
})

-- Enable/Disable Toggle
local StaffNotifierToggle = StaffNotifierTab:AddToggle('StaffNotifier', {
    Title = 'Enable Staff Notifier',
    Description = 'Get notified when staff join',
    Default = true,
})

StaffNotifierToggle:OnChanged(function(Value)
    _G.STAFF_NOTIFIER_ENABLED = Value

    if Value then
        setupStaffMonitor()
        Fluent:Notify({
            Title = 'Staff Notifier',
            Content = 'Staff notifier enabled',
            Duration = 2,
        })
    else
        Fluent:Notify({
            Title = 'Staff Notifier',
            Content = 'Staff notifier disabled',
            Duration = 2,
        })
    end
end)

-- Webhook URL Input
local WebhookInput = StaffNotifierTab:AddInput('WebhookURL', {
    Title = 'Discord Webhook URL',
    Description = 'Paste your Discord webhook URL',
    Default = _G.STAFF_WEBHOOK_URL,
    Placeholder = 'https://discord.com/api/webhooks/...',
    Callback = function(Value)
        _G.STAFF_WEBHOOK_URL = Value
        print('[Staff Notifier] Webhook URL updated')
    end,
})

-- Test Webhook Button
StaffNotifierTab:AddButton({
    Title = '🧪 Test Webhook',
    Description = 'Send a test notification to your webhook',
    Callback = function()
        if not _G.STAFF_WEBHOOK_URL or _G.STAFF_WEBHOOK_URL == '' then
            Fluent:Notify({
                Title = 'Test Failed',
                Content = 'Please enter a webhook URL first',
                Duration = 3,
            })
            return
        end

        -- Safely get game name with fallback
        local gameName = 'Unknown Game'
        pcall(function()
            local productInfo = game:GetService('MarketplaceService')
                :GetProductInfo(game.PlaceId)
            if productInfo and productInfo.Name then
                gameName = tostring(productInfo.Name)
            end
        end)

        local success = sendWebhookNotification(_G.STAFF_WEBHOOK_URL, {
            title = '✅ Webhook Test Successful',
            description = 'Your webhook is working correctly!',
            color = 5763719, -- Green color
            fields = {
                {
                    name = '👤 Tested By',
                    value = tostring(game.Players.LocalPlayer.Name),
                    inline = true,
                },
                {
                    name = '🎮 Game',
                    value = gameName,
                    inline = true,
                },
                {
                    name = '⏰ Time',
                    value = tostring(os.date('%I:%M %p')),
                    inline = true,
                },
            },
        })

        if success then
            Fluent:Notify({
                Title = '✅ Test Successful',
                Content = 'Webhook notification sent!',
                Duration = 3,
            })
        else
            Fluent:Notify({
                Title = '❌ Test Failed',
                Content = 'Failed to send webhook. Check URL and try again.',
                Duration = 3,
            })
        end
    end,
})

-- Detection Methods Section
StaffNotifierTab:AddParagraph({
    Title = '🔍 Detection Methods',
    Content = 'Configure how staff members are detected',
})

StaffNotifierTab:AddParagraph({
    Title = 'ℹ️ Group Configuration',
    Content = "Group detection uses the groupRoles table (line 278). Edit that table to add your game's staff group and roles.",
})

-- Detection method toggles
local GroupCheckToggle = StaffNotifierTab:AddToggle('GroupCheck', {
    Title = 'Group Role Detection',
    Description = 'Check player group roles for staff indicators',
    Default = true,
})

GroupCheckToggle:OnChanged(function(Value)
    _G.STAFF_DETECTION_METHODS.group_check = Value
end)

-- Scan Current Players Button
StaffNotifierTab:AddButton({
    Title = '🔄 Scan Current Players',
    Description = 'Check all players in the server for staff',
    Callback = function()
        if not _G.STAFF_NOTIFIER_ENABLED then
            Fluent:Notify({
                Title = 'Staff Notifier Disabled',
                Content = 'Enable the staff notifier first',
                Duration = 3,
            })
            return
        end

        local staffFound = 0
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= game.Players.LocalPlayer then
                task.spawn(function()
                    local isStaff, reasons = isStaffMember(player)
                    if isStaff then
                        staffFound = staffFound + 1
                        notifyStaff(player, reasons)
                    end
                end)
            end
        end

        task.wait(1)
        Fluent:Notify({
            Title = 'Scan Complete',
            Content = staffFound > 0
                    and (staffFound .. ' staff member(s) found')
                or 'No staff members detected',
            Duration = 3,
        })
    end,
})

-- Auto-start monitoring if enabled
if _G.STAFF_NOTIFIER_ENABLED then
    task.defer(setupStaffMonitor)
end

-- ⚙️ SETTINGS TAB ⚙️
local SettingsTab = Window:AddTab({ Title = 'Settings', Icon = 'settings' })

SettingsTab:AddParagraph({
    Title = '⚙️ Settings',
    Content = 'Customize your interface appearance and keybinds',
})

-- Setup InterfaceManager for theme and keybind
if InterfaceManager and InterfaceManager.SetLibrary then
    pcall(function()
        InterfaceManager:SetLibrary(Fluent)
        InterfaceManager:SetFolder('TVL2Script')
        InterfaceManager:BuildInterfaceSection(SettingsTab)
    end)
else
    warn('[SCRIPT] InterfaceManager not available')
end

-- Server Info Section
SettingsTab:AddParagraph({
    Title = '🌐 Server Information',
    Content = 'View server details and connection info',
})

local ServerInfoButton = SettingsTab:AddButton({
    Title = 'Show Server Info',
    Description = 'Display server location and ping',
    Callback = function()
        local Stats = game:GetService('Stats')
        local LocalizationService = game:GetService('LocalizationService')

        -- Get ping (in milliseconds)
        local ping =
            math.floor(Stats.Network.ServerStatsItem['Data Ping']:GetValue())

        -- Get server region
        local serverRegion = 'Unknown'
        local success, result = pcall(function()
            return LocalizationService:GetCountryRegionForPlayerAsync(
                game.Players.LocalPlayer
            )
        end)

        if success and result then
            serverRegion = result
        end

        -- Get server JobId
        local jobId = game.JobId
        if jobId == '' then
            jobId = 'Private Server / Studio'
        end

        -- Get player count
        local playerCount = #game.Players:GetPlayers()
        local maxPlayers = game.Players.MaxPlayers

        -- Format the information
        local infoText = string.format(
            '🌍 Region: %s\n'
                .. '📡 Ping: %d ms\n'
                .. '👥 Players: %d/%d\n'
                .. '🆔 Job ID: %s',
            serverRegion,
            ping,
            playerCount,
            maxPlayers,
            jobId
        )

        -- Display in notification
        Fluent:Notify({
            Title = '🌐 Server Information',
            Content = infoText,
            Duration = 8,
        })

        -- Also print to console for easy copying
        print('=== SERVER INFO ===')
        print('Region:', serverRegion)
        print('Ping:', ping, 'ms')
        print('Players:', playerCount .. '/' .. maxPlayers)
        print('Job ID:', jobId)
        print('==================')
    end,
})

-- Infinite Yield
SettingsTab:AddParagraph({
    Title = 'Admin Commands',
    Content = 'Load admin command scripts',
})

local InfiniteYieldButton = SettingsTab:AddButton({
    Title = 'Infinite Yield',
    Callback = function()
        Fluent:Notify({
            Title = 'Infinite Yield',
            Content = 'Loading...',
            Duration = 2,
        })
        loadstring(
            game:HttpGet(
                'https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'
            )
        )()
        Fluent:Notify({
            Title = 'Infinite Yield',
            Content = 'Loaded!',
            Duration = 2,
        })
    end,
})

-- Select Main tab on startup
task.defer(function()
    task.wait(0.1)
    -- Try to select Main tab by finding it
    for i, tab in pairs(Window.Tabs) do
        if tab.Title == 'Main' then
            Window:SelectTab(i)
            break
        end
    end

    -- Mark initialization complete immediately after tab selection
    task.wait(0.1)
    isInitializing = false
    print('[SCRIPT] ✅ GUI initialization complete!')
end)
