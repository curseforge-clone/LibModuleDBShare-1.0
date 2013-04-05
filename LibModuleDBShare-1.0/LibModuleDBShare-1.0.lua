--- **LibModuleDBShare-1.0** provides a shared profile manager for addons without a central core.
-- A basic options panel for the group is added to the Blizzard options panel, as well as a
-- standard profile manager as a subpanel. Changes through the profiles panel are propagated
-- to member databases. The root panel can be used as a parent for your module config panels,
-- to keep all your addon's config in one place. The root panel's name is the same as the group's
-- name.\\
-- \\
-- A group can be created using the ':NewGroup' library method. The returned object inherits all
-- methods of the DBGroup object described below.\\
-- \\
-- **LibDualSpec Support**\\
-- LibModuleDBShare can use LibDualSpec to manage automatic profile switching with talent spec
-- changes. This integration is handled by the library; there is no need to use LibDualSpec
-- on member databases directly. 
--
-- @usage
-- local database;
-- -- this function is called after the ADDON_LOADED event fires
-- function initializeDB()
--     database = LibStub("AceDB-3.0"):New("MyAddonDB", defaults, true);
--     local group = LibStub("LibModuleDBShare-1.0"):GetGroup("Group Name");
--     if not group then
--         group = LibStub("LibModuleDBShare-1.0"):NewGroup("Group Name", "A description for this group.", database);
--     else
--         group:AddDB(database);
--     end
-- end
-- @class file
-- @name LibModuleDBShare-1.0
local MAJOR, MINOR = "LibModuleDBShare-1.0", 4
local LibModuleDBShare, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not LibModuleDBShare then return end -- No upgrade needed

-- Lua functions
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
-- @param groupName The name of the new DB group, as shown in the options panel.
-- @param groupDescription A description of the group to be shown in the root options panel.
-- @param initialDB The first DB to add to the group.
-- @param usesDualSpec True if this group should use LibDualSpec, false otherwise.
-- @usage
-- local myDB = LibStub("AceDB-3.0"):New("MySavedVar");
-- local myAddonDBGroup = LibStub("LibModuleDBShare-1.0"):NewGroup("MyAddonGroupName", "MyDescription", myDB, true)
-- @return the new DB group object
-- @name LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB[, usesDualSpec]);
function LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec)
	-- check to see if LibDualSpec has been loaded
	if not LibDualSpec then
		LibDualSpec = LibStub("LibDualSpec-1.0", true);
	end
	-- verify parameters
	if type(groupName) ~= "string" then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'groupName' must be a string.", 2);
	elseif type(groupDescription) ~= "string" then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'groupDescription' must be a string.", 2);
	elseif type(LibModuleDBShare.groups[groupName]) ~= "nil" then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): group '"..groupName.."' already exists.", 2);
	elseif type(initialDB) ~= "table" or not AceDB.db_registry[initialDB] then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'initialDB' must be an AceDB-3.0 database.", 2);
	elseif initialDB.parent then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'initialDB' must not be a namespace.", 2)
	elseif type(usesDualSpec) ~= "boolean" and type(usesDualSpec) ~= "nil" then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'usesDualSpec' must be a boolean or nil.", 2);
	elseif usesDualSpec and not LibDualSpec then
		error("Usage: LibModuleDBShare:NewGroup(groupName, groupDescription, initialDB, usesDualSpec): 'usesDualSpec' cannot be true without LibDualSpec-1.0 installed.", 2);
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
		group.usesDualSpec = true;
		LibDualSpec:EnhanceDatabase(group.syncDB, groupName);
		LibDualSpec:EnhanceOptions(group.profileOptionsTable, group.syncDB);
	else
		group.usesDualSpec = false;
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
	local storedData = group.members[initialDB].char;
	if type(storedData.logoutTimestamp) == "number" then
		group.profileTimestamp = storedData.logoutTimestamp;
	else
		group.profileTimestamp = 0;
	end
	if usesDualSpec then
		local LDSnamespace = group.syncDB:GetNamespace("LibDualSpec-1.0");
		LDSnamespace.char.enabled = storedData.dualSpecEnabled;
		LDSnamespace.char.profile = storedData.altProfile;
		LDSnamespace.char.specGroup = storedData.activeSpecGroup;
		group.syncDB:CheckDualSpecState();
	else
		group.syncDB.char.enabled = storedData.dualSpecEnabled;
		group.syncDB.char.profile = storedData.altProfile;
		group.syncDB.char.specGroup = storedData.activeSpecGroup;
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
-- @return the DB group object, or ##nil## if not found
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
		error("Usage: DBGroup:AddDB(newDB): 'newDB' must be an AceDB-3.0 database.", 2);
	elseif newDB.parent then
		error("Usage: DBGroup:AddDB(newDB): 'newDB' must not be a namespace.", 2)
	elseif type(self.members[newDB]) ~= "nil" then
		error("Usage: DBGroup:AddDB(newDB): 'newDB' is already a member of DBGroup.", 2);
	end
	for groupName, group in pairs(LibModuleDBShare.groups) do
		if group.members[newDB] ~= nil then
			error("Usage: DBGroup:AddDB(newDB): 'newDB' is already a member of group '"..groupName.."'.", 2);
		end
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
	local storedData = namespace.char;
	if type(storedData.logoutTimestamp) == "number" and storedData.logoutTimestamp > self.profileTimestamp then
		self.squelchCallbacks = false;
		self.syncDB:SetProfile(newDB:GetCurrentProfile());
		self.profileTimestamp = storedData.logoutTimestamp;
		if self.usesDualSpec and storedData.altProfile then
			local LDSnamespace = group.syncDB:GetNamespace("LibDualSpec-1.0");
			LDSnamespace.char.enabled = storedData.dualSpecEnabled;
			LDSnamespace.char.profile = storedData.altProfile;
			LDSnamespace.char.specGroup = storedData.activeSpecGroup;
			group.syncDB:CheckDualSpecState();
		elseif storedData.altProfile then
			self.syncDB.char.enabled = storedData.dualSpecEnabled;
			self.syncDB.char.profile = storedData.altProfile;
			self.syncDB.char.specGroup = storedData.activeSpecGroup;
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

--- Checks to see if this group uses LibDualSpec.
-- @return ##true## if this group uses LibDualSpec, ##false## otherwise
function DBGroup:IsUsingDualSpec()
	return self.usesDualSpec;
end

--- Enables dual spec support if not already enabled.
function DBGroup:EnableDualSpec()
	if not LibDualSpec then
		LibDualSpec = LibStub("LibDualSpec-1.0"); -- this will error if LDS isn't found
	end
	if not self.usesDualSpec then
		LibDualSpec:EnhanceDatabase(self.syncDB, self.name);
		LibDualSpec:EnhanceOptions(self.profileOptionsTable, self.syncDB);
		AceConfigRegistry:NotifyChange(self.name.."Profiles");
		self.usesDualSpec = true;
		local namespace = self.syncDB:GetNamespace("LibDualSpec-1.0");
		namespace.char.enabled = self.syncDB.char.enabled;
		namespace.char.profile = self.syncDB.char.profile;
		namespace.char.specGroup = self.syncDB.char.specGroup;
		self.syncDB:CheckDualSpecState();
	end
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

local altProfile = nil;
local dualSpecEnabled = nil;
local activeSpecGroup = nil;

function DBGroup:OnSyncShutdown(callback, syncDB)
	if self.usesDualSpec and not altProfile then
		altProfile = syncDB:GetDualSpecProfile();
		dualSpecEnabled = syncDB:IsDualSpecEnabled();
		activeSpecGroup = GetActiveSpecGroup();
	end
end

local timestamp = nil;

function DBGroup:OnMemberShutdown(callback, db)
	if not timestamp then	-- ensure uniform timestamps to minimize
		timestamp = time();	-- calls to SetProfile in NewGroup
	end
	self.members[db].char.logoutTimestamp = timestamp;
	if self.usesDualSpec then
		if not altProfile then
			altProfile = self.syncDB:GetDualSpecProfile();
			dualSpecEnabled = self.syncDB:IsDualSpecEnabled();
			activeSpecGroup = GetActiveSpecGroup();
		end
		self.members[db].char.altProfile = altProfile;
		self.members[db].char.dualSpecEnabled = dualSpecEnabled;
		self.members[db].char.activeSpecGroup = activeSpecGroup;
	end
end

-- update existing groups
for groupName, group in pairs(LibModuleDBShare.groups) do
	for funcName, func in pairs(DBGroup) do
		group[funcName] = func;
	end
end
