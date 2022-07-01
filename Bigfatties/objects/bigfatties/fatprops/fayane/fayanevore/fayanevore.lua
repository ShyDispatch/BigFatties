require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
	bigFatties.messageHandlers()
	storage.bigFatties = storage.bigFatties or root.assetJson("/scripts/bigfatties.config:baseData")
	object.setInteractive(true)


	dialog = {
		swallow = {
			"^#aa99dd;Fayane^reset; wass hungry, thankss for the meal.",
			"<player> iss about to become tushy pudge, how do they feel~?",
			"Can <player> try find fish person down there? ^#aa99dd;Fayane^reset; thinks she accidentally ate while ssleep-walking.",
			"Does <player> want to go on ^#aa99dd;Fayane^reset;'s belly, boobsss, or butt~?",
			"If <player> wants to go in ^#aa99dd;Fayane^reset;'s tummy, all they need to do is asssk~.",
			"^#aa99dd;Fayane^reset; may swallow down a sssnack for <player>. If they ask nicely~."
		},
		struggle = {
			"Keep moving, feelss almost like ^#aa99dd;Fayane^reset; is getting massssage.",
			"<player> really thinksss they can get out before turning to fat, iss cute~.",
			"Ssstruggling jusst makess it quicker~.",
			"^#aa99dd;Fayane^reset; can feel <player> sssquirming inside, it tickless.",
			"Place your betsss, can <player> get outss before ^#aa99dd;Fayane^reset; makess them mush~?"
		},
		stop = {
			"Floran ssstill hungry!",
			"^#aa99dd;Fayane^reset; not sssay you could leave!",
			"If ^#aa99dd;Fayane^reset; askss nicely, can she ssswallow <player> again?",
			"<player> leaving ssso soon?",
			"Can <player> sstay in floran for five more minutess? Please?",
			"Where doess <player> think <player> is going?",
			"<player> isn't allowed to leave ^#aa99dd;Fayane^reset;'s tummy!",
			"<player> knowsss they want to slide back insside."
		},
		digested = {
			"^#aa99dd;Fayane^reset; thankss <player> for the meal~.",
			"^#aa99dd;Fayane^reset; hopess <player> likesss being butt fat.",
			"<player> should bring friendss next time, floran ssstill hungry.",
			"<player> wass deliciouss, floran should find more like them.",
			"Is <player> going onto ^#aa99dd;Fayane^reset;'sss tum or tushy? Let'ss wait and ssee~.",
			"Aw, <player> didn't lasst long at all, ^#aa99dd;Fayane^reset; ssstill sstarving!",
			"Iss much easier to become fat when prey comesss to you, hehe~.",
			"Floran could really use a belly rub right about now.",
			"^#aa99dd;Fayane^reset; isss disappointed in <player>, turned to mush sso quick~.",
			"And people wonder how ^#aa99dd;Fayane^reset; got ssso big and ssoft~."
		}
	}

	regurgitateTimer = 0
	boostTimer = 0

	digestionBoost = false
end

function onInteraction(args)
	bigFatties.eatEntity(args.sourceId)
end

function onNpcPlay(npcId)
	onInteraction({sourceId = npcId})
end

function update(dt)
	-- Check promises.
	promises:update()

	bigFatties.voreCheck()
	bigFatties.digest(dt)
	bigFatties.gurgle(dt)

	if storage.bigFatties.entityStomach[1] then
		lastEntity = storage.bigFatties.entityStomach[1]
	end

	if regurgitateTimer > 0 and (regurgitateTimer - dt) <= 0 then
		playSound("talk", 1, 1.25)
		animator.burstParticleEmitter("emotesad")
		object.say(tostring(dialog.stop[math.random(1, #dialog.stop)]:gsub("<player>", world.entityName(lastEntity.id).."^reset;")))
		world.sendEntityMessage(lastEntity.id, "bigFatties.getReleased", entity.id())
	end

	regurgitateTimer = math.max(0, regurgitateTimer - dt)
end

function playSound(soundPool, volume, pitch, loops)
	if not ((soundPool == "digest" or soundPool == "struggle") and regurgitateTimer > 0) then
		animator.setSoundVolume(soundPool, volume or 1, 0)
		animator.setSoundPitch(soundPool, pitch or 1, 0)
		animator.playSound(soundPool, loops)
		if soundPool == "struggle" then
			if math.random(1, 600) == 1 then
				playSound("talk", 1, 1.25)
				animator.burstParticleEmitter("emotehappy")
				object.say(tostring(dialog.struggle[math.random(1, #dialog.struggle)]:gsub("<player>", world.entityName(storage.bigFatties.entityStomach[1].id).."^reset;")))
			end
		end
	end
end

bigFatties = {
	-- Mod functions
	----------------------------------------------------------------------------------
	digest = function(dt)
		bigFatties.voreDigest(dt)
	end,

	gurgle = function(dt)
		if #storage.bigFatties.entityStomach == 0 then return end
		-- Roughly every 30 seconds, gurgle (i.e. instantly digest 2.5 - 5 seconds worth of food).
		if math.random(1, math.round(30/dt)) == 1 then
			local seconds = math.random(25, 50)/10
			bigFatties.digest(seconds)
			playSound("digest", 0.75, (0.8 - seconds/10))
		end
	end,

	-- Vore functions
	----------------------------------------------------------------------------------
	voreCheck = function()
		-- Don't do anything if there's no eaten entities.
		if not (#storage.bigFatties.entityStomach > 0) then return end
		-- table.remove is very inefficient in loops, so we'll make a new table instead and just slap in the stuff we're keeping.
		local newStomach = jarray()
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if world.entityExists(prey.id) then
				table.insert(newStomach, prey)
			end
		end
		storage.bigFatties.entityStomach = newStomach
	end,

	voreDigest = function(digestionRate)
		-- Don't do anything if there's no eaten entities.
		if not (#storage.bigFatties.entityStomach > 0) then return end
		-- Reduce health of all entities.
		for _, prey in pairs(storage.bigFatties.entityStomach) do
			world.sendEntityMessage(prey.id, "bigFatties.getDigested", digestionRate)
		end
	end,

	eatEntity = function(preyId)
		-- Max 1 entity for this object.
		if #storage.bigFatties.entityStomach > 0 then return end
		-- Don't do anything if they're already eaten.
		local eatenEntity = nil
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if prey.id == preyId then
				eatenEntity = prey
			end
		end
		if eatenEntity then return false end
		-- Don't do anything if they not a compatible entity.
		if not contains({"player", "npc", "monster"}, world.entityType(preyId)) then return false end
		-- Ask the entity to be eaten, add to stomach if the promise is successful.
		promises:add(world.sendEntityMessage(preyId, "bigFatties.getEaten", entity.id()), function(prey)
			if not (prey and (prey.weight or prey.bloat)) then return end
			table.insert(storage.bigFatties.entityStomach, {
				id = preyId,
				weight = prey.weight or 0,
				bloat = prey.bloat or 0,
				experience = prey.experience or 0,
				type = world.entityType(preyId):gsub(".+", {player = "humanoid", npc = "humanoid", monster = "creature"})
			})

			-- Swallow/stomach rumble
			playSound("swallow", 1 + math.random(0, 10)/100, 1)
			playSound("digest", 1, 0.75)
			playSound("talk", 1, 1.25)
			animator.burstParticleEmitter("emotehappy")
			object.say(tostring(dialog.swallow[math.random(1, #dialog.swallow)]:gsub("<player>", world.entityName(preyId).."^reset;")))
			animator.setAnimationState("interactState", "swallow", true)
		end)
		return true
	end,

	digestEntity = function(preyId, items, preyStomach)
		-- Find the entity's entry in the stomach.
		local digestedEntity = nil
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if prey.id == preyId then
				digestedEntity = table.remove(storage.bigFatties.entityStomach, preyIndex)
				break
			end
		end
		-- Don't do anything if we didn't digest an entity.
		if not digestedEntity then return end
		playSound("digest", 0.75, 0.75)
		playSound("talk", 1, 1.25)
		animator.burstParticleEmitter("emotehappy")
		animator.setAnimationState("interactState", "digest", true)
		object.say(tostring(dialog.digested[math.random(1, #dialog.digested)]:gsub("<player>", world.entityName(digestedEntity.id).."^reset;")))
		return true
	end,

	preyStruggle = function(preyId)
		-- Only continue if they're actually eaten.
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if prey.id == preyId then
				local preyHealth = world.entityHealth(prey.id)
				local preyHealthPercent = preyHealth[1]/preyHealth[2]

				playSound("struggle", math.min(1, (0.25 + math.max(0.5 * prey.weight/120, 0.35)) * (0.75 + preyHealthPercent/4)))
				if world.entityType(preyId) == "player" and math.random() < 0.1 then
					bigFatties.releaseEntity(preyId)
				end
				-- 1 second worth of digestion per struggle.
				world.sendEntityMessage(preyId, "bigFatties.getDigested", 1)
				break
			end
		end
	end,
	releaseEntity = function(preyId)
		-- Delete the entity's entry in the stomach.
		local releasedEntity = nil
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if prey.id == preyId then
				releasedEntity = table.remove(storage.bigFatties.entityStomach, preyIndex)
				break
			end
			if not preyId then
				releasedEntity = table.remove(storage.bigFatties.entityStomach)
				break
			end
		end
		if releasedEntity and world.entityExists(releasedEntity.id) then
			if regurgitateTimer == 0 then
				regurgitateTimer = 2
				animator.setAnimationState("interactState", "regurgitate", true)
				playSound("swallow", 1.25, math.random(8, 12)/10, 2)
			end
		end
	end,

	messageHandlers = function()
		message.setHandler("bigFatties.digest", simpleHandler(bigFatties.digest))
		-- Ditto but vore.
		message.setHandler("bigFatties.eatEntity", simpleHandler(bigFatties.eatEntity))
		message.setHandler("bigFatties.digestEntity", simpleHandler(bigFatties.digestEntity))
		message.setHandler("bigFatties.preyStruggle", simpleHandler(bigFatties.preyStruggle))
		message.setHandler("bigFatties.releaseEntity", simpleHandler(bigFatties.releaseEntity))
		-- sounds
		message.setHandler("bigFatties.playSound", simpleHandler(playSound))
	end
}

-- Other functions
----------------------------------------------------------------------------------
function math.round(num, numDecimalPlaces)
	local format = string.format("%%.%df", numDecimalPlaces or 0)
	return tonumber(string.format(format, num))
end
