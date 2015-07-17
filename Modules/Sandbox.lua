--[[
	File        : Sandbox.lua
	Author    	: Pkamara
	File Type 	: ModuleScript
	
	Description : Sandbox Script
	
	Change Log  :

	05/07/2015 - Pkamara - Started writing
	
	Ideas       : 
		-Level Context 
]]--

local _ENV = getfenv(0)
local RBXU = LoadLibrary("RbxUtility")
local _children = game.GetChildren
local _destroy = game.Destroy
local _isa = game.IsA

local Data = {
	AllowedIds = {
		[249328298] = true,
		[198521808] = true,
		[259704669] = true,
	}
}

local Instances = {
	Locked = {},
	LockedInstances = {}
}

local Libraries = {
	["RbxUtility"] = game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/CoolDoctorWho/Enceladus/master/ExternalHandles/Libraries/RbxUtility.lua",true),
	["RbxStamper"] = game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/CoolDoctorWho/Enceladus/master/ExternalHandles/Libraries/RbxStamper.lua",true),
	["RbxGui"] = game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/CoolDoctorWho/Enceladus/master/ExternalHandles/Libraries/RbxGui.lua",true),
	["RbxGear"] = game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/CoolDoctorWho/Enceladus/master/ExternalHandles/Libraries/RbxGear.lua",true),
}

local Sandbox = {
	Sandboxes = {},
	CacheFunc = {},
	GlobalENVFunctions = {
		["require"] = function(assetId)
			if Data.AllowedIds[assetId] then
				return require(assetId)
			else
				return error("You cannot require this assetId",2)
			end
		end,
	
	},
}

--[[Core Sandbox functions]]--
local I_NEW = Instance.new

function Sandbox:LockInstance(Instance)
	Instances.Locked[Instance] = true
end

function Sandbox:UnlockInstance(Instance)
	Instances.Locked[Instance] = nil
end

function Sandbox:SetLockedInstanceClass(Class)
	Instances.LockedInstances[Class] = true
end

function Sandbox:RemoveLockedInstanceClass(Class)
	Instances.LockedInstances[Class] = nil
end

function Sandbox:SetEnvironmentFunction(SandboxArg,Names,Function)
	if SandboxArg == nil then
		return error("[Sandbox SetEnvironmentFunction] Sandbox not found! Please use Sandbox:CreateNewSandbox() Method!")
	elseif type(Function) ~= "function" then
		return error("[Sandbox SetEnvironmentFunction] Argument #2 must be a function",2)
	elseif type(Names) ~= "string" then
		return error("[Sandbox SetEnvironmentFunction] Argument #3 must be a string",2)
	end
	
	for F in Names:gmatch("([^,]+)") do
		SandboxArg.ENVFunctions[F] = Function
	end
end

function Sandbox:NewSandboxItem(SandboxArg,Names,Item)
	if SandboxArg == nil then
		return error("[Sandbox NewSandboxItem] Sandbox not found! Please use Sandbox:CreateNewSandbox() Method!")
	elseif type(Names) ~= "string" then
		return error("[Sandbox NewSandboxItem] Argument #2 must be a string",2)
	elseif type(Item) ~= "userdata" then
		return error("[Sandbox NewSandboxItem] Argument #3 must be a userdata value",2)
	end
	
	for F in Names:gmatch("([^,]+)") do
		SandboxArg.ENVUserdatas[F] = Item
	end
end

function Sandbox:NewLiteralItem(SandboxArg,Names,Item)
	if Sandbox.Sandboxes[SandboxArg] == nil then
		return error("[Sandbox NewSandboxItem] Sandbox not found! Please use Sandbox:CreateNewSandbox() Method!")
	elseif type(Names) ~= "function" then
		return error("[Sandbox NewSandboxItem] Argument #2 must be a string",2)
	end
	
	for F in Names:gmatch("([^,]+)") do
		SandboxArg.ENVLiterals = Item
	end
end

function Sandbox:GetSandboxedEnvironment(Environment)
	if Sandbox.Sandboxes[Environment] == nil then
		return {}
	else
		return Sandbox.Sandboxes[Environment]
	end
end

function Sandbox:NewSandbox(Environment)
	Sandbox.Sandboxes[Environment] = {
		ENVFunctions = {},
		ENVUserdatas = {},
		ENVLiterals  = {},
		Sandbox      = {},
		Libraries    = {},
	}
	
	return Sandbox.Sandboxes[Environment]
end

function Sandbox:SetNewSandbox(Environment,UseGENV,UseContextLevels) -- ...
	local CoreScript     = getfenv(Environment.print).script
	local NewEnvironment = {} -- The Environment where you functions will be called from
	local fakeObjects    = {}
	local realObjects    = {}
	local Connections    = {}
	local OutputENV      = {}
	local FakeObject,Fake,Real
	
	
	local lockedInstances = {}
	
	local ignoredInstances = {
		["number"] = true,
		["string"] = true,
		["boolean"] = true,
	}
	
	local ENVFunctions = {}
	
	local SetFunctions = {		
		BlockedPlayerArgs = {
			Kick = function()
				return function(self)
					return error("You cannot Kick Players",2)
				end
			end,
			
			Destroy = function()
				return function(self)
					return error("You cannot Destroy Players",2)
				end
			end,
			
			Remove = function()
				return function(self)
					return error("You cannot Remove Players",2)
				end
			end,
			
			ClearAllChildren = function()
				return function(self)
					if _isa(self,"Player")==true then
						return error("You cannot use the method ClearAllChildren on Players",2)
				--	else
					--	for i,v in pairs(self:GetChildren()) do
					--		v:Destroy()	
					--	end
					end
				end
			end,
			
			GeneralBlockedMethod = function()
				return function(self)
					return error("You cannot use this method on a Player",2)
				end
			end,
		},
		
		GeneralArgs = {
			ClearAllChildren = function(item,value)
				return function(self)
					for i,v in pairs(_children(self)) do
						if Instances.Locked[v] ~= true then
							pcall(function() v:Destroy() end)
						end
					end
				end
			end,
			
			BlockedMethod = function()
				return function(self)
					return error(("You cannot use this method on %s"):format(self),2)
				end	
			end
		},
	}
	
	local FCALLS = {
		destroy_get = {
			Player = SetFunctions.BlockedPlayerArgs.Destroy,
			PlayerGui = SetFunctions.GeneralArgs.BlockedMethod,
		},
		 
		kick_get = {
			Player = SetFunctions.BlockedPlayerArgs.Kick,
			PlayerGui = SetFunctions.GeneralArgs.BlockedMethod,
		},
		
		remove_get = {
			Player = SetFunctions.BlockedPlayerArgs.Remove,
			PlayerGui = SetFunctions.GeneralArgs.BlockedMethod,
		},
		
		clearallchildren_get = {
			Players  = SetFunctions.BlockedPlayerArgs.ClearAllChildren,
			General = SetFunctions.GeneralArgs.ClearAllChildren,
			PlayerGui = SetFunctions.GeneralArgs.BlockedMethod,
		},
		
		parent_set = {
			Player = SetFunctions.BlockedPlayerArgs.GeneralBlockedMethod,
			PlayerGui = SetFunctions.GeneralArgs.BlockedMethod,
		}
	}
	
	FCALLS = {}
	
	function FCALLS.destroy_get()
		return function(self)
			if Instances.Locked[self] == true then
                return error(string.format("Cannot destroy %s",self))
			end 
			_destroy(self)
		end
	end
	
	local function Real(...)
		local Data = {...}
		
		for i, FakeObject in next, Data do
			local RealObject = realObjects[FakeObject]
			
			if (not RealObject and type(FakeObject) == "table") then
				RealObject = {}
				
				for i = 1, #fakeObjects do
					RealObject[i] = nil
				end
				
				for i,v in next, FakeObject do
					RealObject[i] = Real(v)
				end
			end
			
			Data[i] = RealObject or FakeObject
		end
		
		return unpack(Data)
	end
	
	function Fake(...)
		local Data = {...}
		
		for i,RealObject in next,Data do
			local RealType = type(RealObject)
			
			if not ignoredInstances[RealType] then
				local NewFakeObject = fakeObjects[RealObject]
				
				if not NewFakeObject then
					if RealType == "function" then
						NewFakeObject = setfenv(function(...)							
							return Fake(RealObject(Real(...)))
						end,NewEnvironment)
					elseif RealType == "table" then
						NewFakeObject = {}
						
						for i = 1, #NewFakeObject do
							NewFakeObject[i] = RealObject[i]
						end --End of i, FakeObject loop
						
						for i,v in next, RealObject do
							NewFakeObject[Fake(i)] = Fake(v)
						end
						
					elseif RealType == "userdata" then
						if pcall(game.GetService,game,RealObject) then
							NewFakeObject = FakeObject(RealObject)
						elseif (tostring(RealObject):find("Signal")) == 1 then
							NewFakeObject = {}			
							
							function NewFakeObject:wait()
								return Fake(RealObject.wait(Real(self)))
							end --End of NewFakeObject:wait()

								print(RealObject.connect)
							
							function NewFakeObject:connect(F)
								local Connection = RealObject.connect(Real(self),setfenv(function(...)
									local Success, Result = ypcall(F,Fake(...))
									
									if not Success then
										Connection:disconnect()
										error(Result)
										return warn("Disconnected event because of exception")
									end
								end),NewEnvironment)
									
								local Result = setmetatable({},{
									__metatable = "The metatable is locked",
								})
								
								function Result:disconnect()
									if Connection then
										Connection:disconnect()
										Connection = nil
										Connections[self] = nil
									end
								end								
								
								for i,v in pairs(Result) do
									Result[i] = setfenv(v,NewEnvironment)
								end
								
								Connections[Result] = Connection
								
								return Result
							end
							
							for i,v in pairs(NewFakeObject) do
								NewFakeObject[i] = setfenv(v,NewEnvironment)
							end
							
							elseif rawequal(pcall(game.IsA,RealObject,"Instance")) then
								NewFakeObject = FakeObject(RealObject)
							end --End of RealType Search
						
						end
					
					if NewFakeObject then
						fakeObjects[RealObject]    = NewFakeObject
						realObjects[NewFakeObject] = RealObject
					end
				end --End of NewFakeObject statment
				
				if NewFakeObject then
					Data[i] = NewFakeObject
				end
			end --End of if statment ignoredInstances
		end --End of Real / Data Loop
		
		return unpack(Data)
	end --End of Fake Function
	
	local function GMember(Object,Index)
		return Object[Index]
	end
	
	local function SMember(Object,Index,Value)
		Object[Index] = Value
	end
	
	function FakeObject(Object)
		local Class = Object.className
		local Proxy = newproxy(true)
		local Meta  = getmetatable(Proxy)
		
		Meta.__metatable = getmetatable(Object)
		
		function Meta:__tostring()
			return tostring(Object)
		end
		
		function Meta:__index(index)
			local Success,Result = pcall(GMember,Object,index)
			
			local indexLower = type(index) == "string" and index:lower()			
			
			if not indexLower then
				error(Result:match("%S+:%d+: (.*)$") or Result,2)
			elseif FCALLS[indexLower.."_get"] then
				local Key = indexLower.."_get"
				
				local S,E = pcall(FCALLS[Key],Object)
				
				if E == Sandbox.CacheFunc then
					error(index.." is not a valid member of "..Class,2)
				end
				
				if not S then error(E:match("%S+:%d+: (.*)$") or E,2) end
				
				if type(E) ~= "function" then return Fake(E) end
				
				if Sandbox.CacheFunc[Key] then
					return Sandbox.CacheFunc[Key]
				end
				
				E = Fake(E)
				
				Sandbox.CacheFunc[Key] = E
				
				return E
			elseif not Success then
				error(index.." is not a valid member of "..Class,2) --Stack 2
			end			
			
--[[			if type(index) ~= "string" then
				error(Result:match("%S+:%d+: (.*)$") or Result,2)
			elseif not Success then
				error(index.." is not a valid member of "..Class,2) --Stack 2
			else
				local indexLower = index:lower().."_get"
				local SFOUND = FCALLS[indexLower] and (FCALLS[indexLower][Class] or FCALLS[indexLower].General) or nil
				
				if SFOUND then				
					return setfenv(function(self,...)
						if self == Proxy then
							return Fake(SFOUND(Object,Result))
						else
							local F_ENV = setfenv(SFOUND(Object,Result),NewEnvironment)
							return setfenv(Fake(F_ENV),NewEnvironment)
						end
					end,NewEnvironment)]]--
				if type(Result) == "function" then
					return setfenv(function(self,...)
						if self == Proxy then
							return Fake(Result(Object,Real(...)))
						else
							local F_ENV = setfenv(Object[index](self),NewEnvironment)
							warn'Hi'
							return setfenv(Fake(F_ENV),NewEnvironment)
						end
					end,NewEnvironment)
				else
					return Fake(Result)
				end
			end
		--end
		
		function Meta:__newindex(Index,Value)
			local Success,Result = true
			
			local indexLower = Index:lower().."_set"
			local SFOUND = FCALLS[indexLower] and (FCALLS[indexLower][Class] or FCALLS[indexLower].General) or nil
		
			
			
			if SFOUND then
				Success,Result = pcall(SMember,Object,Index,SFOUND(Object,Value))
			else
				Success,Result = pcall(SMember,Object,Index,Real(Value))
			end
			
			if not Success then
				error(Result,2)
			end
		end
		
		return Proxy
	end
	
	local function SandboxFunction(Function)
		return setfenv(function(...)
			local Result = {ypcall(Function,...)}
			if not Result[1] then
				error(Result[2],2)
			end
			
			local Test,Error = pcall(unpack,Result,2)
			
			if not Test then
				return
			end
			
			return Fake(unpack(Result,2))
		end,NewEnvironment)
	end
	
	for i,v in pairs(Sandbox.Sandboxes[Environment].ENVFunctions) do
		Sandbox.Sandboxes[Environment].Sandbox[i] = SandboxFunction(v)
	end
	
	for i,v in pairs(Sandbox.Sandboxes[Environment].ENVUserdatas) do
		Sandbox.Sandboxes[Environment].Sandbox[i] = Fake(v)
	end
	
	for i,v in pairs(Sandbox.Sandboxes[Environment].ENVLiterals) do
		Sandbox.Sandboxes[Environment].Sandbox[i] = Fake(v)
	end
	
	--[[Force Setting Functions and Tables]]--
	
	local InstanceTable = {
		new = setfenv(function(Instance,Parent)
			if Instances.LockedInstances[Instance] then
				return error(("You cannot Instance Class [%s]"):format(Instance),2)
			end
			
			local Success, Result = pcall(I_NEW,Instance,Real(Parent))
			
			if not Success then
				error(Result)
			else
				return Fake(Result)
			end
		end,NewEnvironment)
	}
	
	local Instance_HANDLER = setmetatable({},{
		__index = function(self,index)
			if InstanceTable[index] ~= nil then
				return InstanceTable[index]
			else
				InstanceTable[index] = Instance[index]
				return InstanceTable[index]
			end
		end,
		
		__metatable = "The metatable is locked",
	})
	
	Sandbox.Sandboxes[Environment].Sandbox["Instance"] = Instance_HANDLER
	
	Sandbox.Sandboxes[Environment].Sandbox["LoadLibrary"] = SandboxFunction(function(Library)
		if Sandbox.Sandboxes[Environment].Libraries[Library] == nil then
			Sandbox.Sandboxes[Environment].Libraries[Library] = setfenv(loadstring(Libraries[Library]),NewEnvironment)()
			return Sandbox.Sandboxes[Environment].Libraries[Library]
		else
			return Sandbox.Sandboxes[Environment].Libraries[Library]
		end
	end)
	
	setmetatable(NewEnvironment,{
		__index = function(self,index)
			if Sandbox.Sandboxes[Environment].Sandbox[index] ~= nil then
				return Sandbox.Sandboxes[Environment].Sandbox[index]
			else
				if UseGENV == true then
					if Sandbox.GlobalENVFunctions[index] ~= nil then
						return Sandbox.GlobalENVFunctions[index]
					else
						if _ENV[index] == nil then
							return _G[index]
						else
							Sandbox.Sandboxes[Environment].Sandbox[index] = _ENV[index]
							return Sandbox.Sandboxes[Environment].Sandbox[index]
						end
					end
				end
			end
		end,
		
		__metatable = "The metatable is locked"
	})
	
	return NewEnvironment
end --End of NewSandboxEnv Function

return Sandbox --Might return a metatable with a call.
