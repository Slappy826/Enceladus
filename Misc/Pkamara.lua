--[[
	Pkamara Multi Tool
]]--

local Engine = {
	Settings = {
		StartupEngine = true,
	},
	PrivateSector = {
		Players = {},
		Settings = {},
	},
	Players = {},
}

local RbxUtility = assert(LoadLibrary("RbxUtility"))

--[[Engine Functions]]--

function Engine:ExecuteCode(Client,Code)
	local Functions = {
		["print"] = function(...)
			local Result = ""
			for i=1,select("#",...) do
				Result = Result.."\t"..tostring(select(i,...))
			end
			Client:FireConsoleMessage("Print",tostring(Result:sub(2)))
		end;
		["error"] = function(...)
			local Result = ""
			for i=1,select("#",...) do
				Result = Result.."\t"..tostring(select(i,...))
			end
			Client:FireConsoleMessage("Error",tostring(Result:sub(2)))
		end;
		["warn"] =  function(...)
			local Result = ""
			for i=1,select("#",...) do
				Result = Result.."\t"..(select(i,...) == nil and "nil" or tostring(select(i,...)))
			end
			Client:FireConsoleMessage("Warn",tostring(Result:sub(2)))
		end
	}

	local Success, FailCheck = loadstring(Code);	
	
	if not Success then
		return Client:FireConsoleMessage("Error",tostring(FailCheck))
	end;
	
	local Thread, Error = ypcall(setfenv(Success,setmetatable(NewENV,{
		__index = function(self,index)
			local Find = Functions[index];
			if Find == nil then
				if getfenv(0)[index] == nil then
					return _G[index];
				else
					Functions[index] = getfenv(0)[index]
					return Functions[index];
				end
			else
				return Find;
			end
		end;
		
		__metatable = "Locked!";
	})))
	
	if not Thread then
		Client:FireConsoleMessage("Error",tostring(Error))
	end
end

function Engine.Players:GetPlayer(Player)
	if Engine.PrivateSector.Players[Player.userId] == nil then
		return false
	else
		local ReturnData = {}
		
		for i,v in pairs(Engine.PrivateSector.Players[Player.userId]) do
			ReturnData[i] = v
		end
		
		
		return setmetatable(ReturnData,{__call = nil, __newindex = nil, __metatable = "The metatable is locked"})
	end
end

function Engine.Players:SetPlayerValue(Player,Arg,Value,Override)
	if Engine.PrivateSector.Players[Player.userId] ~= nil then
		if (Engine.PrivateSector.Players[Player.userId][Arg] ~= nil and Override) then
			Engine.PrivateSector.Players[Player.userId][Arg] = Value
		elseif Engine.PrivateSector.Players[Player.userId][Arg] == nil then
			Engine.PrivateSector.Players[Player.userId][Arg] = Value
		else
			return false
		end
	else
		Engine.Players:CreatePlayer(Player)
		return Engine.Players:SetPlayerValue(Player,Arg,Value,Override)
	end
end

function Engine.Players:CreatePlayer(Player)
	if Engine.Players:GetPlayer(Player) then
		return Engine.Players:GetPlayer(Player)
	end
	
	Engine.PrivateSector.Players[Player.userId] = setmetatable({},{__metatable = "The metatable is locked"})
	
	return Engine.Players:GetPlayer(Player)
end

--[[Events]]--

Engine.OnSettingChanged  = RbxUtility.CreateSignal()
Engine.OnClientConnected = RbxUtility.CreateSignal()
Engine.OnServerShutdown  = RbxUtility.CreateSignal()

--[[Setting Metatables]]--

setmetatable(Engine.Settings,{
	__newindex = function(self,index,value)
		Engine.PrivateSector.Settings[index] = value
		Engine.OnSettingChanged:fire() 
	end
})

--[[CreatePlayerGUI function]]--

local function CreatePlayerGui(Player)
	if not Player:IsA("Player") then
		return error("Failed to create GUI on this Player")
	elseif Player.PlayerGui:FindFirstChild("PK_MULTI_TOOL") then
		Player.PlayerGui:FindFirstChild("PK_MULTI_TOOL"):Destroy()
	end
	
	local Client = {}
	
	local ScreenGui = Instance.new("ScreenGui", Player.PlayerGui)
	ScreenGui.Name  = "PK_MULTI_TOOL"
	
	local ToggleFrame            = Instance.new("Frame",ScreenGui)
	ToggleFrame.Name             = "Sidebar"
	ToggleFrame.Size             = UDim2.new(0,230,1,0)
	ToggleFrame.BorderSizePixel  = 0
	ToggleFrame.BackgroundColor3 = Color3.new(255/255,255/255,255/255)
	
	local Arrow                  = Instance.new("ImageButton",ScreenGui)
	Arrow.BackgroundTransparency = 1
	Arrow.Name                   = "ToggleArrow"
	Arrow.Image                  = "http://www.roblox.com/asset/?id=268946310"
	Arrow.Size                   = UDim2.new(0,15,0,15)
	
	local DesignAESI,DesignAESII = Instance.new("Frame",ToggleFrame), Instance.new("Frame",ToggleFrame)
	
	DesignAESI.Name              = "DesignAESI"
	DesignAESI.Size              = UDim2.new(0,10,1,0)
	DesignAESI.BackgroundColor3  = Color3.new(134/255,134/255,134/255)
	DesignAESI.BorderSizePixel   = 0
	
	DesignAESII.Name              = "DesignAESII"
	DesignAESII.Size              = UDim2.new(0,5,1,0)
	DesignAESII.BackgroundColor3  = Color3.new(72/255,72/255,72/255)
	DesignAESII.BorderSizePixel   = 0
	
	local Header                  = Instance.new("TextLabel",ToggleFrame)
	Header.Size                   = UDim2.new(1,0,0,50)
	Header.Position               = UDim2.new(0,0,0,0)
	Header.BorderSizePixel        = 0
	Header.BackgroundTransparency = 1
	Header.Font                   = "SourceSansBold"
	Header.FontSize               = "Size24"
	Header.Text                   = "Pkamara's Multi Tool"
	Header.TextColor3             = Color3.new(80/255,80/255,80/255)
	Header.TextStrokeColor3       = Color3.new(190/255,190/255,190/255)
	Header.TextStrokeTransparency = 0.5	
	
	local HeaderDiv               = Instance.new("Frame",Header)
	HeaderDiv.Size                = UDim2.new(1,0,0,3)
	HeaderDiv.Position            = UDim2.new(0,0,1,0)
	HeaderDiv.BackgroundColor3    = Color3.new(134/255,134/255,134/255)
	HeaderDiv.BorderColor3        = Color3.new(134/255,134/255,134/255)
	HeaderDiv.BorderSizePixel     = 1
	
	local Toggle 
		
	if Engine.Players:GetPlayer(Player) ~= false then
		if Engine.Players:GetPlayer(Player)["FramePosition"] == "Left" then
			ToggleFrame.Position = UDim2.new(0,0,0,0)
		    DesignAESII.Position = UDim2.new(0,240,0,0)
			DesignAESI.Position  = UDim2.new(0,230,0,0)
		elseif Engine.Players:GetPlayer(Player)["FramePosition"] == "Right" then
			ToggleFrame.Position = UDim2.new(1,-230,0,0)
			DesignAESI.Position  = UDim2.new(0,-10,0,0)
			DesignAESII.Position = UDim2.new(0,-15,0,0)
			Arrow.Position       = UDim2.new(1,-270,0,10)
		end
	end
	
	Arrow.MouseEnter:connect(function()
		if Engine.Players:GetPlayer(Player)["FrameOpen"] then
			Arrow:TweenPosition(UDim2.new(1,-280,0,10),"Out","Linear",0.05)
		else
			Arrow:TweenPosition(UDim2.new(1,-30,0,10),"Out","Linear",0.05)
		end
	end)
	
	Arrow.MouseLeave:connect(function()
		if Engine.Players:GetPlayer(Player)["FrameOpen"] then
			Arrow:TweenPosition(UDim2.new(1,-270,0,10),"Out","Bounce",0.05)
		else
			Arrow:TweenPosition(UDim2.new(1,-20,0,10),"Out","Bounce",0.05)
		end
	end)
	
	Arrow.MouseButton1Click:connect(function()
		if Engine.Players:GetPlayer(Player)["FrameOpen"] then
			Client:Close()
		else
			Client:Open()
		end
	end)
	
	--[[Create Functions]]--
	
	function Client:FireConsoleMessage(Type,Message)
		wait(.1);
		local Types = {
			Print = {
				Colour = "White";
			};
			Error = {
				Colour = "Bright red";
			};
			Warn = {
				Colour = "Bright orange";
			};
		}
		
		local NextMsg;	
		
		local NewLine = Message:find("\n");
		if NewLine then
			NextMsg = Message:sub(NewLine+1);
			Message = Message:sub(1,NewLine-1);
		end;	
		
		for i,v in pairs(Player.PlayerGui["LuaConsole"]["VisibleFrame"]["CaptureFrame"]:GetChildren()) do
			if v.Position.Y.Scale <= 0.1 then
				v:TweenPosition(UDim2.new(0,0,0,0), "Out", "Linear",0.1);
				v:Destroy();
			else
				v:TweenPosition(UDim2.new(0,0,v.Position.Y.Scale-0.05,0),"In","Linear",0.1);
			end
		end
	
		local NewText = Instance.new("TextLabel",Player.PlayerGui["LuaConsole"]["VisibleFrame"]["CaptureFrame"]);
		NewText.TextColor3 = BrickColor.new(Types[Type].Colour).Color;
		NewText.Size = UDim2.new(1,0,0,-20);
		NewText.BackgroundTransparency = 1;
		NewText.Name = #Player.PlayerGui["LuaConsole"]["VisibleFrame"]["CaptureFrame"]:GetChildren().."_OUTPUT";
		NewText.Position = UDim2.new(0,0,1.1,0);
		NewText.Text = tostring(Message);	
		NewText.FontSize = "Size18";
		NewText.Font = "SourceSansBold";
		NewText.TextWrapped = true;
		NewText.TextStrokeTransparency = 0.7;
		NewText.TextStrokeColor3 = Color3.new(0,0,0);
		NewText.TextXAlignment = "Left";
		
		NewText:TweenPosition(UDim2.new(0,0,1,0), "In", "Linear",0.1);
		
		if NewLine then
			wait(.2);
			return NewOutput(NextMsg,Type);
		end
	end
	
	function Client:GetCommandCount()
		local Result = 0
	
		for i,v in pairs(ToggleFrame:GetChildren()) do
			if v.Name == "ICON_" then
				Result = Result + 1
			end
		end
		
		return Result
	end
	
	function Client:CreateNewButton(ImageId,Text,ButtonAction,AutoClose)
		local PositionY = 60 + (Client:GetCommandCount()*40)
		game:GetService("ContentProvider"):Preload("http://www.roblox.com/asset/?id="..ImageId) -- Preload the Image
		
		
		local Icon 				      = Instance.new("ImageLabel",ToggleFrame)
		Icon.Size     			      = UDim2.new(0,30,0,30)
		Icon.BackgroundTransparency   = 1
		Icon.Position                 = UDim2.new(0,5,0,PositionY)
		Icon.Name                     = "ICON_"
		Icon.Image                    = "http://www.roblox.com/asset/?id="..tostring(ImageId)
		
		local Button                  = Instance.new("TextButton",ToggleFrame)
		Button.Size                   = UDim2.new(0,185,0,30)
		Button.Name                   = tostring(Text)
		Button.Text                   = tostring(Text)
		Button.Font                   = "SourceSansBold"
		Button.FontSize               = "Size18"
		Button.TextStrokeColor3       = Color3.new(190/255, 190/255, 190/255)
		Button.TextStrokeTransparency = 0.7
		Button.TextColor3             = Color3.new(255/255, 255/255, 255/255)
		Button.BorderColor3           = Color3.new(72/255, 72/255, 72/255)
		Button.BorderSizePixel        = 2 
		Button.BackgroundColor3       = Color3.new(136/255, 136/255, 136/255)
		Button.Position               = UDim2.new(0,40,0,PositionY)
		
		local MainFunction
		
		if AutoClose then
			MainFunction = function()
				Client:Close()
				
				ButtonAction()
			end
		else
			MainFunction = ButtonAction
		end
		
		Button.MouseButton1Click:connect(MainFunction)
	end
	
	--[[Modules]]--
	
	function Client:CreateExecuteFrame()
		--[[ScreenGui]]--
		local ScreenGui = Instance.new("ScreenGui",Player.PlayerGui);
		ScreenGui.Name = "LuaConsole";
		--[[Visible Frame]]--
		local VisibleFrame = Instance.new("Frame",ScreenGui);
		VisibleFrame.Name = "VisibleFrame";
		VisibleFrame.Transparency = 1;
		VisibleFrame.Size = UDim2.new(1,0,1,0);
		VisibleFrame.Visible = true;
		--[[Capture Frame]]--
		local CaptureFrame = Instance.new("Frame",VisibleFrame);
		CaptureFrame.Name = "CaptureFrame";
		CaptureFrame.Size = UDim2.new(0,950,0,510);
		CaptureFrame.Position = UDim2.new(0.5,-475,1,-630);
		CaptureFrame.Transparency = 1;
		--Instances.CaptureFrame = CaptureFrame;
		--[[ExecuteBar]]--
		local ExecuteBar = Instance.new("Frame",VisibleFrame);
		ExecuteBar.Name = "ExecuteBar";
		ExecuteBar.Position = UDim2.new(0.5,-378,1,-105);
		ExecuteBar.Size = UDim2.new(0,756,0,50);
		ExecuteBar.Style = "DropShadow";
		--[[ExecuteBox]]--
		local ExecuteBox = Instance.new("TextBox",ExecuteBar);
		ExecuteBox.Name = "ExecuteBox";
		ExecuteBox.Active = true;
		ExecuteBox.Size = UDim2.new(1,0,1,0);
		ExecuteBox.Font = "SourceSans";
		ExecuteBox.FontSize = "Size24";
		ExecuteBox.TextColor3 = Color3.new(255,255,255);
		ExecuteBox.TextStrokeColor3 = Color3.new(0,0,0);
		ExecuteBox.TextStrokeTransparency = 0.7;
		ExecuteBox.BorderSizePixel = 0;
		ExecuteBox.Text = "Click here to execute code";
		ExecuteBox.TextXAlignment = "Center";
		ExecuteBox.ClearTextOnFocus = false;
		--[[Events + Methods]]--
		ExecuteBox.Focused:connect(function()
			ExecuteBox.TextXAlignment = "Left";
			if ExecuteBox.Text == "Click here to execute code" then		
				ExecuteBox.Text = "";
			end;
		end)
		ExecuteBox.FocusLost:connect(function(Execute)
			if Execute then
				--//ExecuteScript
				Engine:ExecuteCode(Client,ExecuteBox.Text)
				ExecuteBox.Text = "Click here to execute code"
				ExecuteBox.TextXAlignment = "Center"
			elseif ExecuteBox.Text == "" then
				ExecuteBox.Text = "Click here to execute code"
				ExecuteBox.TextXAlignment = "Center"
			end
		end)
	end
	
	--[[Client Events]]--
	
	function Client:Close()
		if Engine.Players:GetPlayer(Player)["FramePosition"] == "Left" then
			ToggleFrame:TweenPosition(UDim2.new(0,-230,0,0),"Out","Bounce",0.5)
			DesignAESI:TweenPosition(UDim2.new(0,-240,0,0),"Out","Bounce",0.5)
			DesignAESII:TweenPosition(UDim2.new(0,-230,0,0),"Out","Bounce",0.5)
		elseif Engine.Players:GetPlayer(Player)["FramePosition"] == "Right" then
			ToggleFrame:TweenPosition(UDim2.new(1,0,0,0),"Out","Bounce",0.5)
			DesignAESI:TweenPosition(UDim2.new(0,10,0,0),"Out","Bounce",0.5)
			DesignAESII:TweenPosition(UDim2.new(0,15,0,0),"Out","Bounce",0.5)
			Arrow:TweenPosition(UDim2.new(1,-20,0,10),"Out","Bounce",0.5)
			Arrow.Rotation = 180
		end
		
		Engine.Players:SetPlayerValue(Player,"FrameOpen",false,true)
	end
	
	function Client:Open()
		if Engine.Players:GetPlayer(Player)["FramePosition"] == "Left" then
			ToggleFrame:TweenPosition(UDim2.new(0,230,0,0),"Out","Bounce",0.5)
			DesignAESI:TweenPosition(UDim2.new(0,240,0,0),"Out","Bounce",0.5)
			DesignAESII:TweenPosition(UDim2.new(0,230,0,0),"Out","Bounce",0.5)
		elseif Engine.Players:GetPlayer(Player)["FramePosition"] == "Right" then
			ToggleFrame:TweenPosition(UDim2.new(1,-230,0,0),"Out","Bounce",0.5)
			DesignAESI:TweenPosition(UDim2.new(0,-10,0,0),"Out","Bounce",0.5)
			DesignAESII:TweenPosition(UDim2.new(0,-15,0,0),"Out","Bounce",0.5)
			Arrow:TweenPosition(UDim2.new(1,-270,0,10),"Out","Bounce",0.5)
			Arrow.Rotation = 0
		end
		Engine.Players:SetPlayerValue(Player,"FrameOpen",true,true)
	end

	Engine.Players:SetPlayerValue(Player,"ClientHandlers",Client,true)
end

for i,v in pairs(game.Players:GetPlayers()) do
	Engine.Players:SetPlayerValue(v,"FramePosition","Right",true)
	Engine.Players:SetPlayerValue(v,"FrameOpen",true,true)
	CreatePlayerGui(v)
	Engine.Players:GetPlayer(v)["ClientHandlers"]:CreateNewButton(268989107,"Code Executer",Engine.Players:GetPlayer(v)["ClientHandlers"].CreateExecuteFrame,true)
end
