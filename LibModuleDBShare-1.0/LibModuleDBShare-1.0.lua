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
local error, type, pairs, time = error, type, pairs, time;

-- Required Libraries
local AceDB = LibStub("AceDB-3.0");
local AceDBOptions = LibStub("AceDBOptions-3.0");
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

-- Optional Libraries
local LibDualSpec = LibStub("LibDualSpec-1.0", true);

LibModuleDBShare.groups = LibModuleDBShare.groups or {};

local DBGroup = {};

--- Creates a new DB group.
-- @param groupName The name of the new DB group.
-- @param groupDescription A description of the group to be shown in the root options panel.
-- @param initialDB The first DB to add to the group.
-- @param usesDualSpec True if this group should use LibDualSpec, false otherwise.
-- @usage
-- local myAddonDBGroup = LibStub("LibModuleDBShare-1.0"):NewGroup("MyAddonGroupName", true)
-- @return the new DB group object
function LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec)
	-- verify parameters
	if type(groupName) ~= "string" then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'groupName' must be a string.", 2);
	elseif type(groupDescription) ~= "string" then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'groupDescription' must be a string.", 2);
	elseif type(LibModuleDBShare.groups[groupName]) ~= "nil" then
		error("LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): group '"..groupName.."' already exists.", 2);
	elseif type(initialDB) ~= "table" or not AceDB.db_registry[initialDB] then
		error("LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'initalDB' must be an AceDB-3.0 database.", 2);
	elseif type(usesDualSpec) ~= "boolean" and type(usesDualSpec) ~= "nil" then
		error("LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'usesDualSpec' must be a boolean or nil.", 2);
	elseif usesDualSpec and not LibDualSpec then
		error("LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'usesDualSpec' cannot be true without LibDualSpec-1.0 installed.", 2);
	end
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
	if usesDualSpec then
		LibDualSpec:EnhanceDatabase(group.syncDB, groupName);
		LibDualSpec:EnhanceOptions(group.profileOptionsTable, group.syncDB);
	end
	AceConfigRegistry:RegisterOptionsTable(groupName.."Profiles", group.profileOptionsTable);
	AceConfigDialog:AddToBlizOptions(groupName.."Profiles", group.profileOptionsTable.name, groupName);
	-- add all profiles from initialDB to syncDB
	for i, profile in pairs(initialDB:GetProfiles()) do
		group.syncDB:SetProfile(profile);
	end
	-- load profile info from initialDB
	group.syncDB:SetProfile(initialDB:GetCurrentProfile());
	group.members[initialDB] = initialDB:GetNamespace(MAJOR, true) or initialDB:RegisterNamespace(MAJOR);
	if type(group.members[initialDB].char.logoutTimestamp) == "number" then
		group.profileTimestamp = group.members[initialDB].char.logoutTimestamp;
	else
		group.profileTimestamp = 0;
	end
	if usesDualSpec then
		local dualSpecNamespace = group.syncDB:GetNamespace("LibDualSpec-1.0");
		dualSpecNamespace.char.profile = group.members[initialDB].char.profile;
		dualSpecNamespace.char.enabled = group.members[initialDB].char.enabled;
		dualSpecNamespace.char.specGroup = group.members[initialDB].char.specGroup;
		group.syncDB:CheckDualSpecState();
	end
	-- add methods and callbacks
	for k, v in pairs(DBGroup) do
		group[k] = v;
	end
	group.syncDB.RegisterCallback(group, "OnProfileChanged", "OnProfileChanged");
	group.syncDB.RegisterCallback(group, "OnProfileDeleted", "OnProfileDeleted");
	group.syncDB.RegisterCallback(group, "OnProfileCopied", "OnProfileCopied");
	group.syncDB.RegisterCallback(group, "OnProfileReset", "OnProfileReset");
	group.syncDB.RegisterCallback(group, "OnDatabaseShutdown", "OnSyncShutdown");
	initialDB.RegisterCallback(group, "OnDatabaseShutdown", "OnMemberShutdown");
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
	if type(groupName) ~= "string" then
		error("Usage: LibModuleDBShare:GetGroup(groupName): 'groupName' must be a string.", 2);
	end
	return LibModuleDBShare.groups[groupName];
end

--- Adds a database to the group.
-- @param newDB The database to add.
-- @usage
-- myAddonDBGroup:AddDB(MyAddon.db)
function DBGroup:AddDB(newDB)
	-- verify parameters
	if type(newDB) ~= "table" or not AceDB.db_registry[newDB] then
		error("Usage: DBGroup:AddDB(newDB): 'newDB' must be a table.", 2);
	elseif type(self.members[newDB]) ~= "nil" then
		error("DBGroup:AddDB(newDB): 'newDB' is already a member of DBGroup.", 2);
	end
	-- record current profile
	local syncProfile = self.syncDB:GetCurrentProfile();
	-- add new profiles to syncDB
	self.squelchCallbacks = true;
	for i, profile in pairs(newDB:GetProfiles()) do
		self.syncDB:SetProfile(profile);
	end
	-- set current profile based on timestamps
	local namespace = newDB:GetNamespace(MAJOR, true) or newDB:RegisterNamespace(MAJOR);
	if type(namespace.char.logoutTimestamp) == "number" and namespace.char.logoutTimestamp > self.profileTimestamp then
		self.squelchCallbacks = false;
		self.syncDB:SetProfile(newDB:GetCurrentProfile());
		self.profileTimestamp = namespace.character.logoutTimestamp;
		local dualSpecNamespace = self.syncDB:GetNamespace("LibDualSpec-1.0", true);
		if dualSpecNamespace then
			dualSpecNamespace.char.profile = namespace.char.profile;
			dualSpecNamespace.char.enabled = namespace.char.enabled;
			dualSpecNamespace.char.specGroup = namespace.char.specGroup;
			group.syncDB:CheckDualSpecState();
		end
	else
		self.syncDB:SetProfile(syncProfile);
		newDB:SetProfile(syncProfile);
		self.squelchCallbacks = false;
	end
	-- add to members list
	self.members[newDB] = namespace;
	newDB.RegisterCallback(self, "OnDatabaseShutdown", "OnMemberShutdown");
end

-- callback handlers (new profiles are handled by OnProfileChanged)

function DBGroup:OnProfileChanged(callback, syncDB, profile)
	if not self.squelchCallbacks then
		for db, _ in pairs(self.members) do
			db:SetProfile(profile);
		end
	end
end

function DBGroup:OnProfileDeleted(callback, syncDB, profile)
	for db, _ in pairs(self.members) do
		db:DeleteProfile(profile, true);
	end
end

function DBGroup:OnProfileCopied(callback, syncDB, profile)
	for db, _ in pairs(self.members) do
		db:CopyProfile(profile, true);
	end
end

function DBGroup:OnProfileReset(callback, syncDB)
	for db, _ in pairs(self.members) do
		db:ResetProfile(false, false);
	end
end

local profile = nil;
local enabled = nil;
local specGroup = nil;

function DBGroup:OnSyncShutdown(callback, syncDB)
	if not profile then
		local dualSpecNamespace = syncDB:GetNamespace("LibDualSpec-1.0");
		profile = dualSpecNamespace.char.profile;
		enabled = dualSpecNamespace.char.enabled;
		specGroup = dualSpecNamespace.char.specGroup;
	end
end

local timestamp = nil;

function DBGroup:OnMemberShutdown(callback, db)
	if not timestamp then	-- ensure uniform timestamps to minimize
		timestamp = time();	-- calls to SetProfile in NewGroup
	end
	if not profile then
		local dualSpecNamespace = syncDB:GetNamespace("LibDualSpec-1.0");
		profile = dualSpecNamespace.char.profile;
		enabled = dualSpecNamespace.char.enabled;
		specGroup = dualSpecNamespace.char.specGroup;
	end
	self.members[db].char.logoutTimestamp = timestamp;
	self.members[db].char.profile = profile;
	self.members[db].char.enabled = enabled;
	self.members[db].char.specGroup = specGroup;
end
