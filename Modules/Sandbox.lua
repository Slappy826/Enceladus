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

local GetSandbox = nil
local SandboxHidden = nil

if game.PlaceId == 191240586 or game.PlaceId == 254275637 or game.PlaceId == 285072360 then
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
			[249328298] = true,
			--[198521808] = true,
			--[259704669] = true,
			--[198246567] = true,
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
			["require"] = function(assetId)
				if Data.AllowedIds[assetId] then
					require(assetId)
					return
				else
					return error("You cannot require this assetId",2)
				end
			end,
		},{
			__newindex = function(self,index)
				return error("You cannot modify a read-only table")			
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
				if key == "" then
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
			return error("Failed to assert")
		end
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
	
	function Sandbox:NewSandboxItem(SandboxArg,Names,Item,Key)
		if Key ~= "" then
			return error("Failed to assert")
		end
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
	
	function Sandbox:NewLiteralItem(SandboxArg,Names,Item,Key)
		if Key ~= "" then
			return error("Failed to assert")
		end
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
	
	function Sandbox:SetNewSandbox(Environment,UseGENV,UseContextLevels,Owner) -- ...
		local CoreScript     = getfenv(Environment.print).script
		local NewEnvironment = {} -- The Environment where you functions will be called from
		local fakeObjects    = {}
		local realObjects    = {}
		local Connections    = {}
		local OutputENV      = {}
		local is             = IsA
		local FakeObject,Fake,Real,SandboxFunction
		
		
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
						if IsA(self,"Player") and type(self) == "userdata" then
							return error("You cannot Kick Players",2)
						else
							return error(('The function Kick is not a member of "%s"'):format(self.className))
						end
					end)
				end,
				
				Destroy = function()
					return SandboxFunction(function(self)
						if IsA(self,"Player") and type(self) == "userdata" then
							return error("You cannot Destroy Players",2)
						else
							return ppcall(Destroy,self)
						end
					end)
				end,
				
				Remove = function()
					return SandboxFunction(function(self)
						if IsA(self,"Player") and type(self) == "userdata" then
							return error("You cannot Remove Players",2)
						else
							return ppcall(Remove,self)
						end
					end)
				end,
				
				ClearAllChildren = function()
					return function(self)
						if IsA(self,"Player") and type(self) == "userdata" then
							return error("You cannot use the method ClearAllChildren on Players",2)
						else
							for i,v in pairs(self:GetChildren()) do
								ppcall(Destroy,v)	
							end
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
				clearallchildren = function(item,value)
					return function(self)
						for i,v in pairs(Children(self)) do
							if Instances.Locked[v] ~= true then
								if IsA(self,"Player") then
									return error("You cannot use the method ClearAllChildren on Players",2)
								else
									ppcall(function() v:Destroy() end)
								end
								
							end
						end
					end
				end,
				
				kick = function()
					return function(self)
						return error("You cannot Kick Players",2)
					end
				end,
				
				BlockedMethod = function()
					return function(self)
						return error(("You cannot use this method on %s"):format(self),2)
					end	
				end,
				
				GeneralBlockedMethod = function()
					return function(self)
						return error(("This method for '%s' has been disabled"):format(self),2)
					end
				end,
			
				--[[InvokeResult = function(obj,value)
					return function(...)
						local Result = {ypcall(obj,Fake(value))}
						
						if not Result[1] then
							return error(Result[2],2)
						end
						
						return unpack(Result,2)
					end
				end,]]--
				
				GeneralBlockedEvent = function()
					return setmetatable({
						connect = function()
							return error("This event has been disabled",2)
						end,
						
						wait = function()
							return error("This event has been disabled",2)
						end
						},{
										
					})
				end,
	
				GeneralBlockedService = function()
					return function(self)
						return error(("'s' has been blocked!"):format(self),2)
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
				local RealType = type(RealObject)
				
				if not ignoredInstances[RealType] then
					local NewFakeObject = fakeObjects[RealObject]
					
					if not NewFakeObject then
						if RealType == "function" then
							NewFakeObject = setfenv(function(...)							
								return Fake(RealObject(Real(...)))
							end,NewEnvironment)
						elseif RealType == "table" then
							if RealObject == tostring(_G) then
								NewFakeObject = Sandbox.Sandboxes[Environment].Sandbox["_G"]
							elseif Sandbox.Sandboxes[Environment].Sandbox["tostring"](RealObject) == tostring(shared) then
								NewFakeObject = Sandbox.Sandboxes[Environment].Sandbox["shared"]
							else
								NewFakeObject = {}
							end
							
							for i = 1, #NewFakeObject do
								NewFakeObject[i] = RealObject[i]
							end --End of i, FakeObject loop
							
							for i,v in next, RealObject do
								NewFakeObject[Fake(i)] = Fake(v)
							end
							
						elseif RealType == "userdata" then
							if ppcall(game.GetService,game,RealObject) then
								NewFakeObject = FakeObject(RealObject)
							elseif (Sandbox.Sandboxes[Environment].Sandbox["tostring"](RealObject):find("Signal")) == 1 then
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
											error(Result)
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
											return ProxMeta[idx]
										else
											return Fake(Connection[idx])
										end
									end
									
									for i,v in pairs(Hidden) do
										Hidden[i] = setfenv(v,NewEnvironment)
									end
									
									return ProxMeta
								end
							
								function Meta:__newindex(itm)
									return error(("%s cannot be assigned to"):format(itm))
								end
								
								Meta.__metatable = getmetatable(RealObject)								
								
								for i,v in pairs(LockedTable) do
									if type(v) == "function" then
										LockedTable[i] = setfenv(v,NewEnvironment)
									end
								end
								
								NewFakeObject = Proxy			
								
								elseif rawequal(ppcall(game.IsA,RealObject,"Instance")) then
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
		
		function FakeObject(Object)
			if Instances.Locked[Object] == true then
				return nil
			end
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
					error(Result:match("%S+:%d+: (.*)$") or Result,2)
				elseif FCALLS[indexLower.."_get"] then
					local Key = indexLower.."_get"
					
					local S,E
					
					if FCALLS[Key][Class] ~= nil then
						S,E = ppcall(FCALLS[Key][Class],Object,Result)
						
					
						if S and E == Sandbox.CacheFunc then
							error(index.." is not a valid member of "..Class,2)
						end
						
						if not S then error(E:match("%S+:%d+: (.*)$") or E,2) end
						
						if type(E) ~= "function" then return Fake(E) end
						
						E = Fake(E)
					else
						if type(Result) == "function" then
							return setfenv(function(self,...)
									return Fake(Result(Real(self),Real(...)))
								--else
								--	local F_ENV = setfenv(Object[index](self),NewEnvironment)
								--	return setfenv(Fake(F_ENV),NewEnvironment)
								--end
							end,NewEnvironment)
						end
					end
					
					return E
				elseif not Success then
					return error(index.." is not a valid member of "..Class,2) --Stack 2
				elseif Instances.Locked[index] == true then
					return error(index.." is not a valid member of "..Class,2)	
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
					error(Result,2)
				end
			end
			
			return Proxy
		end
		
		function SandboxFunction(Function)
			return setfenv(function(...)
				local ypcall = yypcall
				local Result = {ypcall(Function,...)}
				if not Result[1] then
					error(Result[2],2)
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
					return error(("You cannot Instance Class [%s]"):format(Instance),2)
				end
				
				local Success, Result = ppcall(I_NEW,Instance,Real(Parent))
				
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
		
	--[[	Sandbox.Sandboxes[Environment].Sandbox["setmetatable"] = SandboxFunction(function(arg,arg2)
			if not arg2 or type(arg2) ~= "table" then
				return assert(ppcall(function() setmetatable({},arg2) end))
			elseif not arg or type(arg2) ~= "table" then
				return assert(ppcall(function() setmetatable(arg,{}) end))
			end
			
			--arg2 = {Fake(unpack(arg2))}
			print(arg2)
			arg2 = Fake(arg2)
			print(arg2)
			
			for i,v in pairs(arg2) do
				print(i,v)
			end
			
			local a = {ppcall(setmetatable,arg,arg2)}
			
			if not a[1] then
				return error(a[2],2)
			end		
			
			return select(2,unpack(a))
		end)]]--
		
		Sandbox.Sandboxes[Environment].Sandbox["Instance"] = Instance_HANDLER
		
--[[		Sandbox.Sandboxes[Environment].Sandbox["pairs"] = function(t)
			if t == Sandbox.Sandboxes[Environment].Sandbox["_G"] then
				
			end
		end
		]]--
		Sandbox.Sandboxes[Environment].Sandbox["_G"] = setmetatable({},{
			__call = nil,
			
			__tostring = function()
				return tostring(_G)
			end,
			
			__index = function(self,index)
				--if type(_G[index]) == "function" then
					--return Fake(_G[index])
				if type(_G[index]) == "table" then
					return Fake(_G[index])
				elseif type(_G[index]) == "userdata" then
					return Fake(_G[index])
				else
					return _G[index]
				end
			end,
			
			__newindex = function(self,index,value)
				if type(value) == "userdata" then
					rawset(_G,index,Real(value))
				else
					rawset(_G,index,value)
				end
			end,
			
			__metatable = getmetatable(_G)
		})
		
		Sandbox.Sandboxes[Environment].Sandbox["rawget"] = SandboxFunction(function(arg,arg2)
			if arg == Sandbox.Sandboxes[Environment].Sandbox["_G"] then
				local Test = {ppcall(function() return rawget(_G,arg2) end)}
				
				if not Test[1] then
					return error(Test[2],2)
				end
				
				if select(2,unpack(Test)) == nil then
					return select(2,unpack(Test))
				end	
				
				if type(select(2,unpack(Test))) == "userdata" then
					return Fake(select(2,unpack(Test)))
				elseif type(type(select(2,unpack(Test)))) == "table" then
					return Fake(select(2,unpack(Test)))
				else
					return select(2,unpack(Test))
				end
			elseif arg == Sandbox.Sandboxes[Environment].Sandbox["shared"] then
				local Test = {ppcall(function() return rawget(shared,arg2) end)}
				
				if not Test[1] then
					return error(Test[2],2)
				end
				
				if select(2,unpack(Test)) == nil then
					return select(2,unpack(Test))
				end	
				
				if type(select(2,unpack(Test))) == "userdata" then
					return Fake(select(2,unpack(Test)))
				elseif type(type(select(2,unpack(Test)))) == "table" then
					return Fake(select(2,unpack(Test)))
				else
					return select(2,unpack(Test))
				end
			else
				return Fake(rget(arg,arg2))
			end
		end)
		
		 Sandbox.Sandboxes[Environment].Sandbox["rawset"] = SandboxFunction(function(arg,arg2,arg3)
			local Test
			if arg == Sandbox.Sandboxes[Environment].Sandbox["_G"] then
				arg = _G
			elseif arg == Sandbox.Sandboxes[Environment].Sandbox["shared"] then
				arg = shared
			end
			
			if type(arg2) == "table" or type(arg2) == "userdata" then
				arg2 = Real(arg2)
			end
			if type(arg3) == "table" or type(arg3) == "userdata" then
				arg3 = Real(arg3)
			end
			
			Test = {ppcall(function() rawset(arg,arg2,arg3) end)}
			
			if not Test[1] then
				return error(Test[2],2)
			end
			
			return Fake(select(2,unpack(Test)))
		 end)
		
		Sandbox.Sandboxes[Environment].Sandbox["load"] = SandboxFunction(function(func, chunk)
			if type(func) ~= "function" then
				return error(("bad argument #1 to 'load' (expected function, got %s)"):format(type(func)),0)
			end
			
			local Sfunc = Fake(func)
			
			local Success, Result = ppcall(func)
			
			if not Success then 
				return error(Result)
			end
			
			return func
		end)
	
		Sandbox.Sandboxes[Environment].Sandbox["tostring"] = SandboxFunction(tostring)		
		
		--http://www.lua.org/manual/5.1/manual.html#pdf-load LATER		
		
		Sandbox.Sandboxes[Environment].Sandbox["package"] = setmetatable({
			getpath = function()
				return "Script Builder/Buffer/"..CoreScript.."/"..CoreScript:GetFullName()
			end
		},{
			__metatable = "This metatable is locked"
		})
		
		Sandbox.Sandboxes[Environment].Sandbox["shared"] = setmetatable({},{
			__call = nil,
			
			__tostring = function()
				return Sandbox.Sandboxes[Environment].Sandbox["tostring"](shared)
			end,
			
			__index = function(self,index)
				if type(shared[index]) == "table" then
					return Fake(shared[index])
				elseif type(shared[index]) == "userdata" then
					return Fake(shared[index])
				else
					return shared[index]
				end
			end,
			
			__newindex = function(self,index,value)
				if type(value) == "userdata" then
					rawset(shared,index,Real(value))
				else
					rawset(shared,index,value)
				end
			end,
			
			__metatable = getmetatable(shared)
		})
		
		Sandbox.Sandboxes[Environment].Sandbox["NS"] = SandboxFunction(function(Source,Parent)
			if Parent == nil then
				return error("Not a valid parent!")
			elseif Source == nil then
				return error("Source is not valid!")
			end
			
			local Create = shared("","NewScript")
		
			local Script = Create(Owner,"Server",Source,"NS",Real(Parent))
			Script.Disabled = false
		end)
		
		Sandbox.Sandboxes[Environment].Sandbox["ns"] = SandboxFunction(function(Source,Parent)
			if Parent == nil then
				return error("Not a valid parent!")
			elseif Source == nil then
				return error("Source is not valid!")
			end
			
			local Create = shared("","NewScript")
		
			local Script = Create(Owner,"Server",Source,"NS",Real(Parent))
			Script.Disabled = false
		end)
		
		Sandbox.Sandboxes[Environment].Sandbox["NLS"] = SandboxFunction(function(Source,Parent)
			if Parent == nil then
				return error("Not a valid parent!")
			elseif Source == nil then
				return error("Source is not valid!")
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
					return error("Script Ended",2)
				end	
				
				if Instances.Locked[index] == true then
					return nil
				end	
				
				if Sandbox.Sandboxes[Environment].Sandbox[index] ~= nil then
					return Sandbox.Sandboxes[Environment].Sandbox[index]
				else
					if UseGENV == true then
						if Sandbox.GlobalENVFunctions[index] ~= nil then
							return Fake(Sandbox.GlobalENVFunctions[index])
						else
							if _ENV[index] == nil then
								return Sandbox.Sandboxes[Environment].Sandbox["_G"][index]
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
	
	local function GetSandbox(key)
		if key == "" then
			return SandboxHidden
		else
			return error("[Sandbox] External access blocked! [Wrong Key]")
		end
	end
	
	return setfenv(GetSandbox,{SandboxHidden=SandboxHidden,error=error}) --Might return a metatable with a call.
end
