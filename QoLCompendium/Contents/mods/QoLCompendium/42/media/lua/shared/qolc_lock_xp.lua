--// Lock Picking Experience
--// Lockpicking. Just. Lockpicking., Workshop 2056238799
--// FMJ - Original, MeTaLAnGeR - IWBUMS update, Oh God Spiders No - streamlining
--// aspctt - 31.08.2026
--// Pays for a picked lock on the side that owns the skill.
--//
--// Skills belong to the server. addXp is LuaManager.GlobalObject.addXp, and the jar shows it
--// handing off to GameServer.addXp when this is the server, awarding straight to the
--// character when this is neither server nor client, and doing nothing at all on a client.
--// That last branch is not an oversight, it is the point: an award a client makes for itself
--// is undone by the next sync, which is what was reported, experience appearing and then
--// going away again a moment later.
--//
--// A picked lock is worked out by a client, in a timed action the server never runs, so the
--// client has to say so and the server has to pay. Nothing but the fact of a successful pick
--// travels: the perk and the amount are fixed here and read on the server, so the request
--// carries no arguments and there is nothing in it to forge.
--//
--// This is why the same fault kept coming back in different clothes. The butchered flesh, the
--// car lock and this are one mistake made three times: a client doing something the server is
--// the only one allowed to do.

--// Tuning
QOLC_LOCK_XP_MODULE = "QoLC"
QOLC_LOCK_XP_COMMAND = "PickedLock"

-- The original's figure, and a car lock is worth the same as a house lock.
QOLC_PICK_XP = 2

--// Functions
function QolcAwardPickXp(Character)
	if not Character then return false end

	addXp(Character, Perks.Lightfoot, QOLC_PICK_XP)
	return true
end

function QolcRequestPickXp(Character)
	if not Character then return false end

	if isClient() then
		sendClientCommand(Character, QOLC_LOCK_XP_MODULE, QOLC_LOCK_XP_COMMAND, {})
		return true
	end

	return QolcAwardPickXp(Character)
end
