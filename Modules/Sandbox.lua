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

if game.PlaceId ~= 191240586 and game.PlaceId ~= 254275637 and game.PlaceId ~= 285072360 then
	warn("Loaded sandbox at the wrong place!")
	return nil
end

local GetSandbox = nil
local SandboxHidden = nil
local FakeFuncs = {}
local CoreUserdataCache = {}
local TableCache = {}
local ModuleBuffer = {}

local _ENV = getfenv(0)
local RBXU = LoadLibrary("RbxUtility")
local Children = game.GetChildren
local Destroy  = game.Destroy
local IsA      = game.IsA
local Remove   = game.Remove
local rget     = rawget
local rset     = rawset
local SandboxFunction
local ppcall   = pcall
local error    = error
local getfenv  = getfenv
local setfenv  = setfenv
local game     = game
local rawget   = rawget
local rawset   = rawset
local yypcall  = ypcall	

local Data = {
	AllowedIds = {
		[274784836] = true,
		[198521808] = true,
		[284836409] = true,
		[259704669] = true,
		[198246567] = true,
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
	GlobalENVFunctions = setmetatable({
		["require"] = function(asset)
			local Type = type(asset)
			if Type == "number" then
				if Data.AllowedIds[asset] == true then -- cuz why not?
					return require(asset)
				end
			elseif Type == "userdata" then
				local isReal, Return = ppcall(game.IsA,game,asset,"ModuleScript")
				if isReal then
					return require(asset)
				else
					return error(Return, 0)
				end
			end
			--[[if type(asset) == "number" then
				if Data.AllowedIds[asset] then
					require(asset)
					return
				elseif ModuleBuffer[asset] then
					return warn'This service is not yet active!'
				else
					return error("You cannot require this assetId",2)
				end
			elseif type(asset) == "userdata" then
				if pcall(function() return asset.className == "ModuleScript" end) then
					if ModuleBuffer[asset] then
						return warn'This service is not yet active!'
					else
						return error()
					end
				end
			end]]--
		end,
	},{
		__newindex = function(self,index)
			return error("You cannot modify a read-only table",0)			
		end,
		
		__tostring = function()
			return "Sandbox Access Table"
		end,	
		
		__metatable = "The metatable is locked",
	}),
}

SandboxHidden = setmetatable({},
	{
		__index = nil,
		
		__newindex = nil,
		
		__call = function(self,key)
			if key == "asd" then
				return Sandbox
			end
		end,		
		
		__metatable = "The metatable is locked"
	})

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

function Sandbox:SetEnvironmentFunction(SandboxArg,Names,Function,Key)
	if Key ~= "" then
		return error("Failed to assert",0)
	end
	if SandboxArg == nil then
		return error("[Sandbox SetEnvironmentFunction] Sandbox not found! Please use Sandbox:CreateNewSandbox() Method!",0)
	elseif type(Function) ~= "function" then
		return error("[Sandbox SetEnvironmentFunction] Argument #2 must be a function",0)
	elseif type(Names) ~= "string" then
		return error("[Sandbox SetEnvironmentFunction] Argument #3 must be a string",0)
	end
	
	for F in Names:gmatch("([^,]+)") do
		SandboxArg.ENVFunctions[F] = Function
	end
end

function Sandbox:NewSandboxItem(SandboxArg,Names,Item,Key)
	if Key ~= "" then
		return error("Failed to assert",0)
	end
	if SandboxArg == nil then
		return error("[Sandbox NewSandboxItem] Sandbox not found! Please use Sandbox:CreateNewSandbox() Method!",0)
	elseif type(Names) ~= "string" then
		return error("[Sandbox NewSandboxItem] Argument #2 must be a string",0)
	elseif type(Item) ~= "userdata" then
		return error("[Sandbox NewSandboxItem] Argument #3 must be a userdata value",0)
	end
	
	for F in Names:gmatch("([^,]+)") do
		SandboxArg.ENVUserdatas[F] = Item
	end
end

function Sandbox:NewLiteralItem(SandboxArg,Names,Item,Key)
	if Key ~= "" then
		return error("Failed to assert",0)
	end
	if Sandbox.Sandboxes[SandboxArg] == nil then
		return error("[Sandbox NewSandboxItem] Sandbox not found! Please use Sandbox:CreateNewSandbox() Method!",0)
	elseif type(Names) ~= "function" then
		return error("[Sandbox NewSandboxItem] Argument #2 must be a string",0)
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

function Sandbox:SetNewSandbox(Environment,UseGENV,UseContextLevels,Owner) -- ...
	local CoreScript     = getfenv(Environment.print).script
	local NewEnvironment = {} -- The Environment where you functions will be called from
	local fakeObjects    = {}
	local realObjects    = {}
	local Connections    = {}
	local OutputENV      = {}
	local MethodCache    = {}
	local EventsCache    = {}
	local is             = IsA
	local FakeObject,Fake,Real,SandboxFunction
	
	local function CheckInstance(Instance, Inst)
		if type(Instance) == "userdata" then
			return IsA(Instance, Inst)
		end
	end
	
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
				return SandboxFunction(function(self)
					if CheckInstance(self, "Player") then
						return error("You cannot Kick Players",0)
					else
						return error(('The method Kick is not a member of "%s"'):format(self.className),0)
					end
				end)
			end,
			
			Destroy = function()
				return SandboxFunction(function(self)
					if CheckInstance(self, "Player") then
						return error("You cannot Destroy Players",0)
					else
						return ppcall(Destroy,self)
					end
				end)
			end,
			
			Remove = function()
				return SandboxFunction(function(self)
					if CheckInstance(self, "Player") then
						return error("You cannot Remove Players",0)
					else
						return ppcall(Remove,self)
					end
				end)
			end,
			
			ClearAllChildren = function()
				return function(self)
					if CheckInstance(self, "Player") then
						return error("You cannot use the method ClearAllChildren on Players",0)
					else
						for i,v in pairs(self:GetChildren()) do
							ppcall(Destroy,v)	
						end
					end
				end
			end,
			
			GeneralBlockedMethod = function()
				return function(self)
					return error("You cannot use this method on a Player",0)
				end
			end,
		},
		
		GeneralArgs = {
			Connect = function()
				return function(self, Function)
					local Check, Ret = pcall(game.Changed.connect, self, print)
					
					if Check then
						Ret:disconnect()
					else
						return
					end
					
					return self.connect(Fake(Function))
				end
			end,
			
			clearallchildren = function(item,value)
				return function(self)
					for i,v in pairs(Children(self)) do
						if Instances.Locked[v] ~= true then
							if CheckInstance(v "Player") then
								return error("You cannot use the method ClearAllChildren on Players",0)
							else
								ppcall(Destroy,v)	
							end
							
						end
					end
				end
			end,
			
			kick = function()
				return function(self)
					return error("You cannot Kick Players",0)
				end
			end,
			
			BlockedMethod = function()
				return function(self)
					return error(("You cannot use this method on %s"):format(self),0)
				end	
			end,
			
			GeneralBlockedMethod = function()
				return function(self)
					return error(("This method for '%s' has been disabled"):format(self),0)
				end
			end,
			
			GeneralBlockedEvent = function()
				return setmetatable({
					connect = function()
						return error("This event has been disabled",0)
					end,
					
					wait = function()
						return error("This event has been disabled",0)
					end
					},{
									
				})
			end,

			GeneralBlockedService = function()
				return function(self)
					return error(("'s' has been blocked!"):format(self),0)
				end
			end,
		}
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
			Player  = SetFunctions.BlockedPlayerArgs.ClearAllChildren,
			General = SetFunctions.GeneralArgs.ClearAllChildren,
			PlayerGui = SetFunctions.GeneralArgs.BlockedMethod,
		},
		
		parent_set = {
			Player = SetFunctions.BlockedPlayerArgs.GeneralBlockedMethod,
			PlayerGui = SetFunctions.GeneralArgs.BlockedMethod,
		},
		
		messageout_get = {
			LogService = SetFunctions.GeneralArgs.GeneralBlockedEvent,
		},
		
		getloghistory_get = {
			LogService = SetFunctions.GeneralArgs.GeneralBlockedMethod,
		},
		
		oninvoke_set = {
			--BindableFunction = SetFunctions.GeneralArgs.InvokeResult	
		},
		
		onserverinvoke_set = {
			--RemoteFunction = SetFunctions.GeneralArgs.InvokeResult
		},
		
		teleport_get = {
			TeleportService = SetFunctions.GeneralArgs.GeneralBlockedService
		},
		
		connect_get = {
			BindableEvent = SetFunctions.GeneralArgs.Connect
		}
	}
	
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

	local function GMember(Object,Index)
		return Object[Index]
	end
	
	local function SMember(Object,Index,Value)
		Object[Index] = Value
	end
	
	local function Fake(...)
		local Data = {...}
		
		for i,RealObject in next,Data do
			
			if true == false then
				Data[i] = fakeObjects[RealObject]
			else
				local RealType = type(RealObject)
				
				if not ignoredInstances[RealType] then
					local NewFakeObject = fakeObjects[RealObject]
					
					if not NewFakeObject then
						--if RealType == "function" and not pcall(setfenv,RealObject,getfenv(RealObject)) then
						if RealType == "function" then
							if FakeFuncs[RealObject] then
								NewFakeObject = FakeFuncs[RealObject]
							else
								NewFakeObject = setfenv(function(...)						
									--return Fake(RealObject(Real(...)))	
									return Fake(RealObject(Real(...)))
								end,NewEnvironment)								
							end
							FakeFuncs[NewFakeObject] = NewFakeObject
							FakeFuncs[RealObject] = NewFakeObject
						elseif RealType == "table" then
							if TableCache[RealObject] then
								NewFakeObject = TableCache[RealObject]
							else
								NewFakeObject = {}
								
								for i = 1, #NewFakeObject do
									NewFakeObject[i] = RealObject[i]
								end --End of i, FakeObject loop
								
								for i,v in next, RealObject do
									NewFakeObject[Fake(i)] = Fake(v)
								end								
							end
							
							TableCache[RealType] = NewFakeObject
							TableCache[NewFakeObject] = NewFakeObject							
							
						elseif RealType == "userdata" then
							if ppcall(game.GetService,game,RealObject) then
								NewFakeObject = FakeObject(RealObject)
							elseif (Sandbox.Sandboxes[Environment].Sandbox["tostring"](RealObject):find("Signal")) == 1 then
								if EventsCache[RealObject] then
									return EventsCache[RealObject]
								end
								local Check,RetDat = pcall(game.Changed.connect,RealObject,print)
								if Check then
									RetDat:disconnect()
								else
									return
								end
							--elseif (string.find(RealObject):find("Signal")) == 1 then								
								local Proxy = newproxy(true)
								local Meta  = getmetatable(Proxy)
								local LockedTable = setmetatable({},{__metatble="This metatable is locked"})
								local to    = Sandbox.Sandboxes[Environment].Sandbox["tostring"](RealObject)
								
								function Meta:__tostring()
									return to
								end
								
								function Meta:__index(index)
									if LockedTable[index] ~= nil then
										return LockedTable[index]
									else
										return Fake(RealObject[index])
									end
								end								
								
								function LockedTable:wait()
									return Fake(RealObject.wait(Real(self)))
								end
								
								function LockedTable:connect(F)
									local Ret									
																
									local Connection = RealObject.connect(Real(self),function(...)
										local Success, Result = ypcall(F,Fake(...))										
										
										if type(F) ~= "function" then
											return error("Attempt to connect failed: Passed value is not a function",0)
										end													
										
										if not Success then
											ppcall(function() Connection:disconnect() end)
											error(Result,0)
											return warn("Disconnected event because of exception")
										end
									end)

									local NewProxy = newproxy(true)
									local ProxMeta = getmetatable(NewProxy)
									local To       = "Connection"
									local Hidden   = setmetatable({},{__metatable="This metatable is locked"})
									
									function Hidden:disconnect()
										Connection:disconnect()
										Connections[LockedTable] = nil
										LockedTable.connected = false
									end
									
									function ProxMeta:__tostring()
										return To
									end
									
									ProxMeta.__metatable = getmetatable(Connection)									
									
									function ProxMeta:__index(idx)
										if Hidden[idx] ~= nil then
											return Hidden[idx]
										else
											return Fake(Connection[idx])
										end
									end
									
									for i,v in pairs(Hidden) do
										Hidden[i] = setfenv(v,NewEnvironment)
									end
									
									return NewProxy
								end
							
								function Meta:__newindex(itm)
									return error(("%s cannot be assigned to"):format(itm),0)
								end
								
								Meta.__metatable = getmetatable(RealObject)								
								
								for i,v in pairs(LockedTable) do
									if type(v) == "function" then
										LockedTable[i] = setfenv(v,NewEnvironment)
									end
								end
								
								NewFakeObject = Proxy
								EventsCache[RealObject] = NewFakeObject
								EventsCache[NewFakeObject] = NewFakeObject			
								
								elseif rawequal(ppcall(game.IsA,RealObject,"Instance")) then
									NewFakeObject = FakeObject(RealObject)
								end --End of RealType Search
							end
						
						if NewFakeObject then
							fakeObjects[RealObject]    = NewFakeObject
							--fakeObjects[NewFakeObject] = NewFakeObject
							realObjects[NewFakeObject] = RealObject
						end
					end --End of NewFakeObject statment
					
					if NewFakeObject then
						Data[i] = NewFakeObject
					end
				end --End of if statment ignoredInstances
			end
		end --End of Real / Data Loop
		
		return unpack(Data)
	end --End of Fake Function
	
	function FakeObject(Object)
		if Instances.Locked[Object] == true then
			return nil
		end
		
		--if CoreUserdataCache[Object] then
		--	return CoreUserdataCache[Object]
		--end
		
		local Class = Object.className
		local Proxy = newproxy(true)
		local Meta  = getmetatable(Proxy)
		
		Meta.__metatable = getmetatable(Object)
		
		function Meta:__tostring()
			return Sandbox.Sandboxes[Environment].Sandbox["tostring"](Object)
		end
		
		function Meta:__index(index)				
			local Success,Result = ppcall(GMember,Object,index)
			
			local indexLower = type(index) == "string" and index:lower()			
			
			if not indexLower then
				error(Result:match("%S+:%d+: (.*)$") or Result,0)
			elseif FCALLS[indexLower.."_get"] then
				local Key = indexLower.."_get"
				
				local S,E
				
				if FCALLS[Key][Class] ~= nil then
					S,E = ppcall(FCALLS[Key][Class],Object,Result)
					
				
					if S and E == Sandbox.CacheFunc then
						error(index.." is not a valid member of "..Class,0)
					end
					
					if not S then error(E:match("%S+:%d+: (.*)$") or E,0) end
					
					if type(E) ~= "function" then return Fake(E) end
					
					E = Fake(E)
					
					if MethodCache[FCALLS[Key][Class]] ~= nil then
						E = MethodCache[FCALLS[Key][Class]]
					else
						MethodCache[FCALLS[Key][Class]] = E
						E = MethodCache[FCALLS[Key][Class]]
					end
				else
					if type(Result) == "function" then
						if MethodCache[Result] ~= nil then
							return MethodCache[Result]
						else
							MethodCache[Result] = setfenv(function(self,...)
									return Fake(Result(Real(self),Real(...)))
								--else
								--	local F_ENV = setfenv(Object[index](self),NewEnvironment)
								--	return setfenv(Fake(F_ENV),NewEnvironment)
								--end
							end,NewEnvironment)
							
							return MethodCache[Result]
						end
					end
				end
				
				return E
			elseif not Success then
				return error(index.." is not a valid member of "..Class,0) --Stack 2
			elseif Instances.Locked[index] == true then
				return error(index.." is not a valid member of "..Class,0)	
			end			
				if type(Result) == "function" then
					return setfenv(function(self,...)
						if self == Proxy then
							return Fake(Result(Object,Real(...)))
						else
							local F_ENV = setfenv(Object[index](self),NewEnvironment)
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
				Success,Result = ppcall(SMember,Object,Index,SFOUND(Object,Value))
			else
				Success,Result = ppcall(SMember,Object,Index,Real(Value))
			end
			
			if not Success then
				error(Result,0)
			end
		end
		
		CoreUserdataCache[Object] = Proxy			
		CoreUserdataCache[Proxy] = Proxy			
		
		return Proxy
	end
	
	function SandboxFunction(Function)
		return setfenv(function(...)
			local ypcall = yypcall
			local Result = {ypcall(Function,...)}
			if not Result[1] then
				error(Result[2],0)
			end
			
			local Test,Error = ppcall(unpack,Result,2)
			
			if not Test then
				return
			end
			
			return Fake(unpack(Result,2))
		end,NewEnvironment)
	end
	
	for i,v in pairs(Sandbox.Sandboxes[Environment].ENVFunctions) do
		Sandbox.Sandboxes[Environment].Sandbox[i] = setfenv(v,NewEnvironment)
	end
	
	for i,v in pairs(Sandbox.Sandboxes[Environment].ENVUserdatas) do
		Sandbox.Sandboxes[Environment].Sandbox[i] = Fake(v)
	end
	
	for i,v in pairs(Sandbox.Sandboxes[Environment].ENVLiterals) do
		Sandbox.Sandboxes[Environment].Sandbox[i] = Fake(v)
	end
	
	for i,v in pairs(game:GetService("Players"):GetPlayers()) do
		Sandbox.Sandboxes[Environment].Sandbox[v.PlayerGui] = Fake(v)
	end
	
	Sandbox.Sandboxes[Environment].Sandbox[game:GetService("ReplicatedStorage")] = Fake(game:GetService("ReplicatedStorage"))
	
	--[[Force Setting Functions and Tables]]--
	
	local InstanceTable = {
		new = setfenv(function(Instance,Parent)
			if Instances.LockedInstances[Instance] then
				return error(("You cannot Instance Class [%s]"):format(Instance),0)
			end
			
			local Success, Result = ppcall(I_NEW,Instance,Real(Parent))
			
			if not Success then
				error(Result,0)
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

	Sandbox.Sandboxes[Environment].Sandbox["load"] = SandboxFunction(function(func, chunk)
		if type(func) ~= "function" then
			return error(("bad argument #1 to 'load' (expected function, got %s)"):format(type(func)),0)
		end
		
		local Sfunc = Fake(func)
		
		local Success, Result = ppcall(func)
		
		if not Success then 
			return error(Result,0)
		end
		
		return func
	end)

	Sandbox.Sandboxes[Environment].Sandbox["tostring"] = SandboxFunction(tostring)		
	
	--http://www.lua.org/manual/5.1/manual.html#pdf-load LATER		
	
	Sandbox.Sandboxes[Environment].Sandbox["package"] = setmetatable({
		getpath = SandboxFunction(function()
			return "Script Builder/Buffer/"..tostring(CoreScript).."/"..CoreScript:GetFullName()
		end)
	},{
		__metatable = "This metatable is locked"
	})
	
	Sandbox.Sandboxes[Environment].Sandbox["debug"] = setmetatable({
		getenv = SandboxFunction(getfenv),
	},{
		__metatable = "This metatable is locked"
	})

	Sandbox.Sandboxes[Environment].Sandbox["NS"] = SandboxFunction(function(Source,Parent)
		if Parent == nil then
			return error("Not a valid parent!",0)
		elseif Source == nil then
			return error("Source is not valid!",0)
		end
		
		local Create = shared("","NewScript")
	
		local Script = Create(Owner,"Server",Source,"NS",Real(Parent))
		Script.Disabled = false
	end)
	
	Sandbox.Sandboxes[Environment].Sandbox["ns"] = SandboxFunction(function(Source,Parent)
		if Parent == nil then
			return error("Not a valid parent!",0)
		elseif Source == nil then
			return error("Source is not valid!",0)
		end
		
		local Create = shared("","NewScript")
	
		local Script = Create(Owner,"Server",Source,"NS",Real(Parent))
		Script.Disabled = false
	end)				
	
	Sandbox.Sandboxes[Environment].Sandbox["NLS"] = SandboxFunction(function(Source,Parent)
		if Parent == nil then
			return error("Not a valid parent!",0)
		elseif Source == nil then
			return error("Source is not valid!",0)
		end
		
		local Create = shared("","NewScript")
	
		local Script = Create(Owner,"Client",Source,"NLS",Real(Parent))
		Script.Disabled = false
	end)
	
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
			if shared("",CoreScript).Active ~= true then
				return error("Script Ended",0)
			end	
			
			if Instances.Locked[index] == true then
				return nil
			end	
			
			if Sandbox.Sandboxes[Environment].Sandbox[index] ~= nil then
				return Sandbox.Sandboxes[Environment].Sandbox[index]
			else
				if UseGENV == true then
					if Sandbox.GlobalENVFunctions[index] ~= nil then
						return SandboxFunction(Sandbox.GlobalENVFunctions[index])
					else
						if _ENV[index] == nil then
							return _G[index] or nil
						else
							Sandbox.Sandboxes[Environment].Sandbox[index] = _ENV[index]
							return Sandbox.Sandboxes[Environment].Sandbox[index]
						end
					end
				end
			end
		end,
		
		__metatable = "The metatable is locked",
	})
	
	return NewEnvironment
end --End of NewSandboxEnv Function

local function GetSandbox(key)
	if key == "asd" then
		return SandboxHidden
	else
		return error("[Sandbox] External access blocked! [Wrong Key]",0)
	end
end

return setfenv(GetSandbox,{SandboxHidden=SandboxHidden,error=error}) --Might return a metatable with a call.
