--[[
	File        : Command.lua
	Author    	: Nexure
	File Type 	: ModuleScript
	
	Description : Commands Module
	
	Change Log :

	06/07/2015 - Nexure - Started writing
]]--

local Command           = {}
local Command_Data      = {
    ["Settings"] = {
        ["Prefix"]          = "",
        ["Suffix"]          = "/",
        ["SuffixRequired"]  = true,
    },
    ["Commands"]    = {},
    ["Connections"] = {},
    ["Functions"]   = {},
}

local Command_Functions = Command_Data["Functions"]

function Command_Functions:Checkself(s,t)
    if not s or type(s) ~= "table" or s ~= t then
        return false,"\":\" Expected, got \".\""
    end
    return true,""
end

function Command_Functions:Chatted(Message,Player)
    local Settings = Command_Data["Settings"]
    local Prefix,Suffix,SuffixRequired = Settings["Prefix"],Settings["Suffix"],Settings["SuffixRequired"]
    Message = Message:match("/e%s?(.*)") or Message
    if Prefix and Prefix ~= "" then
        if Message:sub(1,#Prefix) == Prefix then
            Message = Message:sub(#Prefix+1)
        else
            return
        end
    end
    local Command_Before    = ""
    local Command_After     = ""
    local Message_Find      = Message:find(Suffix)
    if SuffixRequired then
        if not Message_Find then return end
        Command_Before  = Message:sub(1,Message_Find - 1)
        Command_After   = Message:sub(Message_Find + 1)
    else
        if not Message_Find then
            Command_Before  = Message
        else
            Command_Before  = Message:sub(1,Message_Find - 1)
            Command_After   = Message:sub(Message_Find + 1)
        end
    end
    for k,v in pairs(Command_Data["Commands"]) do
        if v["Command"] == Command_Before then
            local Thread       = coroutine.create(v["Function"])
            local Thread_Check = {coroutine.resume(Thread,Command_After,Player)}
            if not Thread_Check[1] then
                spawn(function() error("[Command Module][" .. v["Name"] .. "]: " .. tostring(Thread_Check[2]),2) end)
            end
        end
    end
end

function Command:SetSuffixRequired(bool)
    assert(Command_Functions:Checkself(self,Command))
    if bool == nil or type(bool) ~= "boolean" then
        return error("SuffixRequired value is nil, or type is not boolean",2)
    end
    Command_Data["Settings"]["SuffixRequired"] = bool
end


function Command:SetPrefix(Prefix)
    assert(Command_Functions:Checkself(self,Command))
    if not Prefix or type(Prefix) ~= "string" then
        return error("Prefix value is nil, or type is not string",2)
    end
    Command_Data["Settings"]["Prefix"] = Prefix
end

function Command:SetSuffix(Suffix)
    assert(Command_Functions:Checkself(self,Command))
    if not Suffix or type(Suffix) ~= "string" then
        return error("Suffix value is nil, or type is not string",2)
    end
    Command_Data["Settings"]["Suffix"] = Suffix
end

function Command:AddCommand(Name,Cmd,Function,...)
    assert(Command_Functions:Checkself(self,Command))
    local C_Command = {
        ["Name"]        = Name,
        ["Command"]     = Cmd,
        ["Function"]   	= Function
    }
    local P_Args = {...}
    for i = 1,select("#",...) do
        C_Command[i] = P_Args[i]
    end
    Command_Data["Commands"][Name] = C_Command
end
        
function Command:RemoveCommand(Name)
    assert(Command_Functions:Checkself(self,Command))
    if not Name or type(Name) ~= "string" then
        return error("Name value is nil, or is not string",2)
    end
    for k,v in pairs(Command_Data["Commands"]) do
        if v["Name"] == Name then
            Command_Data["Commands"][k] = nil       
        end
    end
end

function Command:GetCommandTable()
	assert(Command_Functions:Checkself(self,Command))
	local Ret = {}
	for k,v in pairs(Command_Data["Commands"]) do
		Ret[k] = v
	end
	return Ret
end

function Command:Connect(Player)
    assert(Command_Functions:Checkself(self,Command))
    if not Player or type(Player) ~= "userdata" then
        return error("Player is a nil value, or isnt userdata",2)
    end
    for k,v in pairs(Command_Data["Connections"]) do
        if k == Player then
            return false
        end
    end
    local Con,Con = nil,Player.Chatted:connect(function(Msg)
        Command_Functions:Chatted(Msg,Player)
    end)
    Command_Data["Connections"][Player] = Con
end

function Command:Disconnect(Player)
    assert(Command_Functions:Checkself(self,Command))
    if not Player or type(Player) ~= "userdata" then
        return error("Player is a nil value, or isnt userdata",2)
    end
    for k,v in pairs(Command_Data["Connections"]) do
        if k == Player then
            pcall(function() v:disconnect() end)
            Command_Data[k] = nil
        end
    end
end

return Command