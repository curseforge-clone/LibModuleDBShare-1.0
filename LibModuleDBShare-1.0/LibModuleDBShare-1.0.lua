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

local AceDB = LibStub("AceDB-3.0");

LibModuleDBShare.groups = LibModuleDBShare.groups or {};

local DBGroup = {};

--- Creates a new DB group.
-- @param groupName The name of the new DB group.
-- @param usesDualSpec True if this group should use LibDualSpec, false otherwise. (NYI)
-- @param initialProfile The name of the profile to start with.
-- @usage
-- local myAddonDBGroup = LibStub("LibModuleDBShare-1.0"):NewGroup("MyAddonGroupName", true)
-- @return the new DB group object
function LibModuleDBShare:NewGroup(groupName, usesDualSpec, initialProfile)
	assert(type(groupName) == "string", "Usage: LibModuleDBShare:NewGroup(groupName, usesDualSpec, initialProfile): 'groupName' is not a string.");
	assert(type(LibModuleDBShare.groups[groupName]) == "nil", "LibModuleDBShare:NewGroup(groupName, usesDualSpec, initialProfile): 'groupName' already exists");
	local group = {}
	group.name = groupName;
	group.syncDBTable = {};
	group.syncDB = AceDB:New(group.syncDBTable, nil, initialProfile);
	for k, v in pairs(DBGroup) do
		group[k] = v;
	end
	return group;
end

--- Retrieves an existing DB group.
-- @param groupName The name of the DB group to retrieve.
-- @usage
-- local myAddonDBGroup = LibStub("LibModuleDBShare-1.0"):GetGroup("MyAddonGroupName")
-- @return the DB group object, or nil if not found
function LibModuleDBShare:GetGroup(groupName)
	return LibModuleDBShare.groups[groupName];
end

--- Adds a database to the group.
-- @param db The name of the new DB group.
-- @usage
-- myAddonDBGroup:AddDB(MyAddon.db)
function DBGroup:AddDB(db)

end
