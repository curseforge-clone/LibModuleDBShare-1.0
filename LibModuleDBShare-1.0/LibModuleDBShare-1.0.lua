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
local assert, type, pairs = assert, type, pairs;

-- Required Libraries
local AceDB = LibStub("AceDB-3.0");
local AceDBOptions = LibStub("AceDBOptions-3.0");
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

LibModuleDBShare.groups = LibModuleDBShare.groups or {};

local DBGroup = {};

--- Creates a new DB group.
-- @param groupName The name of the new DB group.
-- @param groupDescription A description of the group to be shown in the root options panel.
-- @param initialDB The first DB to add to the group.
-- @param usesDualSpec True if this group should use LibDualSpec, false otherwise. (NYI)
-- @usage
-- local myAddonDBGroup = LibStub("LibModuleDBShare-1.0"):NewGroup("MyAddonGroupName", true)
-- @return the new DB group object
function LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec)
	-- verify parameters
	assert(type(groupName) == "string", "Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'groupName' must be a string.");
	assert(type(groupDescription) == "string", "Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'groupDescription' must be a string.");
	assert(type(LibModuleDBShare.groups[groupName]) == "nil", "LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): group '"..groupName.."' already exists.");
	assert(type(initialDB) == "table", "LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'initalDB must be a table.");
	-- create group
	local group = {}
	group.name = groupName;
	group.members = {};
	-- create root option panel for group
	group.rootOptionsTable = {
		type = "group",
		name = groupName,
		args = {
			text = {
				type = "description",
				name = groupDescription,
			},
		},
	};
	AceConfigRegistry:RegisterOptionsTable(groupName, group.rootOptionsTable);
	AceConfigDialog:AddToBlizOptions(groupName);
	-- create sync DB and profile options page
	group.syncDBTable = {};
	group.syncDB = AceDB:New(group.syncDBTable, nil, initialDB:GetCurrentProfile());
	group.profileOptionsTable = AceDBOptions:GetOptionsTable(group.syncDB, false);
	AceConfigRegistry:RegisterOptionsTable(groupName.."Profiles", group.profileOptionsTable);
	AceConfigDialog:AddToBlizOptions(groupName.."Profiles", group.profileOptionsTable.name, groupName);
	-- add all profiles from initialDB to syncDB
	for i, profile in pairs(initialDB:GetProfiles()) do
		group.syncDB:SetProfile(profile);
	end
	group.syncDB:SetProfile(initialDB:GetCurrentProfile());
	group.members[initialDB] = true;
	if type(initialDB.char.logoutTimestamp) == "number" then
		group.profileTimestamp = initialDB.char.logoutTimestamp;
	else
		group.profileTimestamp = 0;
	end
	-- add methods and callbacks
	for k, v in pairs(DBGroup) do
		group[k] = v;
	end
	group.syncDB.RegisterCallback(group, "OnProfileChanged", "OnProfileChanged");
	group.syncDB.RegisterCallback(group, "OnProfileDeleted", "OnProfileDeleted");
	group.syncDB.RegisterCallback(group, "OnProfileCopied", "OnProfileCopied");
	group.syncDB.RegisterCallback(group, "OnProfileReset", "OnProfileReset");
	initialDB.RegisterCallback(group, "OnDatabaseShutdown", "OnDatabaseShutdown");
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
	assert(type(groupName) == "string", "Usage: LibModuleDBShare:GetGroup(groupName): 'groupName' must be a string.");
	return LibModuleDBShare.groups[groupName];
end

--- Adds a database to the group.
-- @param newDB The database to add.
-- @usage
-- myAddonDBGroup:AddDB(MyAddon.db)
function DBGroup:AddDB(newDB)
	-- verify parameters
	assert(type(newDB) == "table", "Usage: DBGroup:AddDB(newDB): 'newDB' must be a table.");
	assert(type(self.members[newDB]) == "nil", "DBGroup:AddDB(newDB): 'newDB' is already a member of DBGroup.");
	-- record current profile
	local syncProfile = self.syncDB:GetCurrentProfile();
	-- add new profiles to syncDB
	self.squelchCallbacks = true;
	for i, profile in pairs(newDB:GetProfiles()) do
		self.syncDB:SetProfile(profile);
	end
	-- set current profile based on timestamps
	if type(newDB.char.logoutTimestamp) == "number" and newDB.char.logoutTimestamp > self.profileTimestamp then
		self.squelchCallbacks = false;
		self.syncDB:SetProfile(newDB:GetCurrentProfile());
		self.profileTimestamp = newDB.character.logoutTimestamp;
	else
		self.syncDB:SetProfile(syncProfile);
		newDB:SetProfile(syncProfile);
		self.squelchCallbacks = false;
	end
	-- add to members list
	self.members[newDB] = true;
	newDB.RegisterCallback(self, "OnDatabaseShutdown", "OnDatabaseShutdown");
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

function DBGroup:OnDatabaseShutdown(callback, db)
	print("Database Shutdown");
end
