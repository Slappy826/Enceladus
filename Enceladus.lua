--[[
	File        : Enceladus.lua
	Author      : Pkamara
	File Type   : Script
	
	Description : Main Script
	
	Change Log :

	04/05/2015 - Pkamara - Started writing
]]--

local Enceladus = {};

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local RbxUtility         = LoadLibrary("RbxUtility")

local Settings = {
	ClientName         = "EnceladusClient"
	PackageHandler     = "EnceladusResources"
	DataStreamName     = "EnceladusDataStream"
	RequestPrefix      = "SomeSecureKeyHere"
	
	EngineSplashScreen = true
}
