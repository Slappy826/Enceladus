--[[
    File Name : Main.lua
    Author    : Pkamara
]]--


--[[Main Engine]]--
local Engine = {}
local _ENV   = getfenv(0)

--[[Core Functions]]--

function Engine:CreatePlayer(Player)
    local PlayerData = {}
    local GithubBase = ""
    
    PlayerData["ClientName"] = game.JobId.."_"..Player.userId.."__"..Player.userId
    PlayerData["ClientKey"]  = "TEMP_KEY__"
    PlayerData["Settings"]   = {}
    PlayerData["Data"]       = {}
    
    print("[Player Created] "..Player.Name.."'s data has been created successfully at : "..PlayerData["ClientName"])
        
    print("COS I'M N-E-T-S-C-H-E")
end
