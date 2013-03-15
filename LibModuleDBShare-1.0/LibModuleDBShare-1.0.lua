--- **LibModuleDBShare-1.0**\\ 
-- A description will eventually be here.
--
-- @usage
-- Also coming soon.
-- @class file
-- @name LibModuleDBShare-1.0.lua
local MAJOR, MINOR = "LibModuleDBShare-1.0", 1
local LibModuleDBShare, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not LibModuleDBShare then return end -- No upgrade needed

-- Lua APIs
local assert = assert;

-- Required Libraries
local AceDB = LibStub("AceDB-3.0");
local AceDBOptions = LibStub("AceDBOptions-3.0");
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

LibModuleDBShare.groups = LibModuleDBShare.groups or {};

local DBGroup = {};

--- Creates a new DB group.
-- @param groupName The name of the new DB group.
-- @param usesDualSpec True if this group should use LibDualSpec, false otherwise. (NYI)
-- @param initialProfile The name of the profile to start with. (Defaults to character-specific)
-- @usage
-- local myAddonDBGroup = LibStub("LibModuleDBShare-1.0"):NewGroup("MyAddonGroupName", true)
-- @return the new DB group object
function LibModuleDBShare:NewGroup(groupName, usesDualSpec, initialProfile)
	assert(type(groupName) == "string", "Usage: LibModuleDBShare:NewGroup(groupName, usesDualSpec, initialProfile): 'groupName' must be a string.");
	assert(type(LibModuleDBShare.groups[groupName]) == "nil", "LibModuleDBShare:NewGroup(groupName, usesDualSpec, initialProfile): 'groupName' already exists");
	local group = {}
	group.name = groupName;
	group.rootOptionsTable = {
		type = "group",
		name = groupName,
		args = {
			text = {
				type = "description",
				name = "placeholder text.",
			},
		},
	};
	AceConfigRegistry:RegisterOptionsTable(groupName, group.rootOptionsTable);
	AceConfigDialog:AddToBlizOptions(groupName);
	group.syncDBTable = {};
	group.syncDB = AceDB:New(group.syncDBTable, nil, initialProfile);
	group.profileOptionsTable = AceDBOptions:GetOptionsTable(group.syncDB, false);
	AceConfigRegistry:RegisterOptionsTable(groupName.."Profiles", group.profileOptionsTable);
	AceConfigDialog:AddToBlizOptions(groupName.."Profiles", group.profileOptionsTable.name, groupName);
	group.members = {};
	for k, v in pairs(DBGroup) do
		group[k] = v;
	end
	group.syncDB.RegisterCallback(group, "OnProfileChanged", "OnProfileChanged");
	group.syncDB.RegisterCallback(group, "OnProfileDeleted", "OnProfileDeleted");
	group.syncDB.RegisterCallback(group, "OnProfileCopied", "OnProfileCopied");
	group.syncDB.RegisterCallback(group, "OnProfileReset", "OnProfileReset");
	group.squelchCallbacks = false;
	LibModuleDBShare.groups[groupName] = group;
	return group;
end

--- Retrieves an existing DB group.
-- @param groupName The name of the DB group to retrieve.
-- @usage
-- local myAddonDBGroup = LibStub("LibModuleDBShare-1.0"):GetGroup("MyAddonGroupName")
-- @return the DB group object, or nil if not found
function LibModuleDBShare:GetGroup(groupName)
	assert(type(groupName) == "string", "Usage: LibModuleDBShare:GetGroup(groupName): 'groupName' must be a string");
	return LibModuleDBShare.groups[groupName];
end

--- Adds a database to the group.
-- @param db The database to add.
-- @usage
-- myAddonDBGroup:AddDB(MyAddon.db)
function DBGroup:AddDB(db)
	local syncProfile = self.syncDB:GetCurrentProfile();
	
	local shouldDeleteDefault = false; -- if not first DB, then default profile already handled
	if type(self.profileTimestamp) == "nil" then
		shouldDeleteDefault = true -- first DB added.. might not have default profile
		self.profileTimestamp = 0;
	end
	self.squelchCallbacks = true;
	for i, profile in pairs(db:GetProfiles()) do
		if profile == "Default" then
			shouldDeleteDefault = false;
		end
		self.syncDB:SetProfile(profile);
	end
	
	if db.character.logoutTimestamp > self.profileTimestamp then
		self.syncDB:SetProfile(db:GetCurrentProfile());
		self.profileTimestamp = db.character.logoutTimestamp;
	else
		self.syncDB:SetProfile(syncProfile);
	end
	
	if shouldDeleteDefault then
		self.syncDB:DeleteProfile("Default");
	end
	self.squelchCallbacks = false;
	
	if self.syncDB:GetCurrentProfile() ~= syncProfile then
		self:OnProfileChanged("OnProfileChanged", self.syncDB, self.syncDB:GetCurrentProfile());
	end
end

-- callback handlers (new profiles are handled by OnProfileChanged)

function DBGroup:OnProfileChanged(callback, db, profile)
	print("Profile Changed");
	print(self.name);
	print(type(profile));
	print(tostring(profile));
end

function DBGroup:OnProfileDeleted(callback, db, profile)
	print("Profile Deleted");
	print(self.name);
	print(type(profile));
	print(tostring(profile));
end

function DBGroup:OnProfileCopied(callback, db, profile)
	print("Profile Copied");
	print(self.name);
	print(type(profile));
	print(tostring(profile));
end

function DBGroup:OnProfileReset(callback, db)
	print("Profile Reset");
	print(self.name);
end
