local MAJOR, MINOR = "LibModuleDBShare-1.0", 1
local LibModuleDBShare, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not LibModuleDBShare then return end -- No upgrade needed

LibModuleDBShare.groups = LibModuleDBShare.groups or {};

function LibModuleDBShare:NewGroup(groupName, usesDualSpec)
	
end

function LibModuleDBShare:AddModule(groupName, db)

end
