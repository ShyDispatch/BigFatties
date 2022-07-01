require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"

-- Dummy empty function so we save memory.
function nullFunction()
end

-- Old npc/monster functions. (we call these in functons we replace)
local init_old = init or nullFunction
local update_old = update or nullFunction
-- Run on load.
function init()
	-- Run old NPC/Monster stuff.
	init_old()
	-- Load values from config.
	bigFatties.sizes = root.assetJson("/scripts/bigfatties.config:sizes")
	bigFatties.settings = root.assetJson("/scripts/bigfatties.config:settings")
	bigFatties.skills = root.assetJson("/scripts/bigfatties.config:skills")
	bigFatties.compatibleSpecies = root.assetJson("/scripts/bigfatties.config:compatibleSpecies")
	-- Grab or create the data.
	storage.bigFatties = sb.jsonMerge(root.assetJson("/scripts/bigfatties.config:baseData"), storage.bigFatties)
	--[[storage.bigFatties.stats = {}
	storage.bigFatties.unlockedStats = {}
	storage.bigFatties.skills = {}
	storage.bigFatties.unlockedSkills = {}
	storage.bigFatties.level = 0
	storage.bigFatties.experience = 0]]
	if player then
		-- Cross script voodoo witch magic.
		getmetatable ''.bigFatties = bigFatties
		bigFatties.type = "player"
		if not contains(bigFatties.compatibleSpecies, player.species()) then
			message.setHandler("bigFatties.feed", simpleHandler(function(amount) status.giveResource("food", amount) end))
			bigFatties.getChestVariant = function() return "" end
			bigFatties.getDirectives = function() return "" end
			bigFatties.getBreasts = function() return {capacity = 10 * bigFatties.getStat("breastCapacity"), contents = 0, fullness = 0} end
			bigFatties.equipSize = nullFunction
			bigFatties.equipCheck = nullFunction
			bigFatties.gainBloat = nullFunction
			bigFatties.gainWeight = nullFunction
			bigFatties.loseWeight = nullFunction
			bigFatties.setWeight = nullFunction
			bigFatties.getSize = function() return bigFatties.sizes[1], 1 end
		end
	end

	if npc then
		bigFatties.type = "npc"
		if not contains(bigFatties.compatibleSpecies, npc.species()) then
			bigFatties.getChestVariant = function() return "" end
			bigFatties.getDirectives = function() return "" end
			bigFatties.getBreasts = function() return {capacity = 10 * bigFatties.getStat("breastCapacity"), contents = 0, fullness = 0} end
			bigFatties.equipSize = nullFunction
			bigFatties.equipCheck = nullFunction
			bigFatties.gainBloat = nullFunction
			bigFatties.gainWeight = nullFunction
			bigFatties.loseWeight = nullFunction
			bigFatties.setWeight = nullFunction
			bigFatties.getSize = function() return bigFatties.sizes[1], 1 end
		end
	end

	if monster then
		bigFatties.type = "monster"
	end

	-- Override functions for script compatibility on different entities.
	bigFatties.overrides()
	-- Setup message handlers
	bigFatties.messageHandlers()
	-- Reload whenever the entity loads in/beams/etc.
	bigFatties.accessoryModifiers = bigFatties.getAccessoryModfiers()
	bigFatties.stomach = bigFatties.getStomach()
	bigFatties.breasts = bigFatties.getBreasts()
	bigFatties.gainWeight(0)
	-- Damage listener for fall/fire damage.
	bigFatties.damageListener = damageListener("damageTaken", function(notifications)
		for _, notification in pairs(notifications) do
			if notification.sourceEntityId == entity.id() and notification.targetEntityId == entity.id() then
				if notification.damageSourceKind == "falling" and bigFatties.currentSizeIndex > 1 and not bigFatties.hasOption("disableGroundDamage") then
					local lowDamageTiles = jarray()
					local highDamageTiles = jarray()
					local groundLevel = 0
					local width = {0, 0}
					local position = mcontroller.position()
					-- "explosive" damage (ignores tilemods) to blocks is reduced by 80%, for a total of 5% damage applied to blocks.
					local	tileDamage = math.min(status.resource("health"), notification.damageDealt) * 0.25
					-- Find how wide the player's hitbox is, and how far down the ground is.
					for _,v in ipairs(mcontroller.collisionPoly()) do
						width[1] = (v[1] < width[1]) and v[1] or width[1]
						width[2] = (v[1] > width[2]) and v[1] or width[2]
						groundLevel = (v[2] < groundLevel) and v[2] or groundLevel
					end
					-- Create tile damage polys.
					local lowPoly = {
						vec2.add({width[1] - 1, groundLevel - 0.5}, position), vec2.add({width[2] + 1, groundLevel - 0.5}, position),
						vec2.add({math.max(0, width[2] - 1.5), groundLevel - 2.5}, position), vec2.add({math.min(0, width[1] + 1.5), groundLevel - 2.5}, position)
					}
					local highPoly = {
						vec2.add({math.min(-0.5, width[1] + 0.5), groundLevel - 0.5}, position), vec2.add({math.max(0.5, width[2] - 0.5), groundLevel - 0.5}, position),
						vec2.add({math.max(0, width[2] - 1.5), groundLevel - 1.5}, position), vec2.add({math.min(0, width[1] + 1.5), groundLevel - 1.5}, position)
					}
					-- Check if nearby tiles fall in the damage poly.
					for _,tile in pairs(world.radialTileQuery(position, 0.5 * (math.abs(width[1]) + width[2]) - groundLevel + 1, "foreground")) do
						if world.polyContains(lowPoly, tile) then
							table.insert(lowDamageTiles, tile)
						end
						if world.polyContains(highPoly, tile) then
							table.insert(highDamageTiles, tile)
						end
					end
					-- Damage valid tiles based on fall damage.
					world.damageTiles(lowDamageTiles, "foreground", position, "explosive", tileDamage * 0.25, 1)
					world.damageTiles(highDamageTiles, "foreground", position, "explosive", tileDamage  * 0.75, 1)
					break
				end

				if bigFatties.currentSizeIndex > 1 and string.find(notification.damageSourceKind, "fire") and bigFatties.getStat("firePenalty") > 0 then
					local percentLost = math.round(notification.healthLost/status.resourceMax("health"), 2)
					percentLost = percentLost * bigFatties.getStat("firePenalty") * (bigFatties.currentSizeIndex - 1)/(#bigFatties.sizes - 1)

					if percentLost > 0.01 then
						status.overConsumeResource("energy", status.resourceMax("energy") * percentLost)
						status.addEphemeralEffect("sweat")
					end
				end
			end
		end
	end)
end

function update(dt)
	-- Run old NPC/Monster stuff.
	update_old(dt)
	-- Check promises.
	promises:update()
	-- Update fall damage listener.
	bigFatties.damageListener:update()
	-- Check if the entity has gone up a size.
	bigFatties.currentSize, bigFatties.currentSizeIndex = bigFatties.getSize(storage.bigFatties.weight + bigFatties.stomach.bloat.weight)
	bigFatties.stomach = bigFatties.getStomach()
	bigFatties.breasts = bigFatties.getBreasts()
	bigFatties.currentVariant = bigFatties.getChestVariant(modifierSize or bigFatties.currentSize)
	bigFatties.level = storage.bigFatties.level
	bigFatties.experience = storage.bigFatties.experience
	bigFatties.weightMultiplier = math.round(1 + (storage.bigFatties.weight + bigFatties.stomach.contents + bigFatties.stomach.bloat.weight)/entity.weight, 2)
	if bigFatties.type == "player" then
		-- Only need to do the fall damage -> ground damage for players, while enabled.
		if bigFatties.isEnabled() then
			bigFatties.damageListener:update()
			if bigFatties.currentSize.isBlob and not bigFatties.hasOption("disableBlobHitbox") then
				if not bigFatties.hitboxProjectile or not world.entityExists(bigFatties.hitboxProjectile) then
					bigFatties.hitboxProjectile = world.spawnProjectile("blobhitbox", mcontroller.position(), entity.id(), {0, 0}, true)
				end
			end
		end
		-- Cross script voodoo witch magic.
		getmetatable ''.bigFatties.progress = math.round((storage.bigFatties.weight + bigFatties.stomach.bloat.weight - bigFatties.currentSize.weight)/((bigFatties.sizes[bigFatties.currentSizeIndex + 1] and bigFatties.sizes[bigFatties.currentSizeIndex + 1].weight or bigFatties.settings.maxWeight) - bigFatties.currentSize.weight) * 100)
		getmetatable ''.bigFatties.weight = storage.bigFatties.weight
		getmetatable ''.bigFatties.enabled = bigFatties.isEnabled()
		bigFatties.swapSlotItem = player.swapSlotItem()
		if bigFatties.swapSlotItem and root.itemType(bigFatties.swapSlotItem.name) == "consumable" then
			local replaceItem = bigFatties.updateFoodItem(bigFatties.swapSlotItem)
			if replaceItem then
				player.setSwapSlotItem(replaceItem)
			end
		end
	end

	if bigFatties.currentSize.size ~= (oldSize and oldSize.size or nil) then
		-- Update status effect trackers.
		bigFatties.createStatuses()
		-- Don't play the sound on the first load.
		if oldSize then
			-- Play sound to indicate size change.
			world.sendEntityMessage(entity.id(), "bigFatties.playSound", "digest", 0.75, math.random(10,15) * 0.1 - storage.bigFatties.weight/(bigFatties.settings.maxWeight * 2))
		end
	end
	-- Checks
	bigFatties.voreCheck()
	bigFatties.equipCheck(bigFatties.currentSize, {
		chestVariant = bigFatties.currentVariant,
		chestSize = bigFatties.hasOption("extraTopHeavy") and 2 or (bigFatties.hasOption("topHeavy") and 1 or nil),
		legsSize = bigFatties.hasOption("extraBottomHeavy") and 2 or (bigFatties.hasOption("bottomHeavy") and 1 or nil)
	})
	-- Actions.
	bigFatties.eaten(dt)
	bigFatties.digest(dt)
	bigFatties.gurgle(dt)
	bigFatties.exercise(dt)
	bigFatties.drink(dt)
	bigFatties.lactating(dt)
	-- Stat/status updating stuff.
	bigFatties.hunger(dt)
	bigFatties.updateStatuses()
	bigFatties.updateStats(bigFatties.optionChanged)
	bigFatties.updateSkills(dt)
	-- Save for comparison later.
	oldSize = bigFatties.currentSize
	oldVariant = bigFatties.currentVariant
	oldWeightMultiplier = bigFatties.weightMultiplier

	if bigFatties.isEnabled() then
		if bigFatties.stomach.contents > storage.bigFatties.stomachLerp and (bigFatties.stomach.contents - storage.bigFatties.stomachLerp) > 1 then
			storage.bigFatties.stomachLerp = math.round(util.lerp(5 * dt, storage.bigFatties.stomachLerp, bigFatties.stomach.contents), 4)
		else
			storage.bigFatties.stomachLerp = bigFatties.stomach.contents
		end
	end

	if bigFatties.type == "player" then
		bigFatties.debug("currentSize", string.format("%s", bigFatties.getSize(storage.bigFatties.weight + bigFatties.stomach.bloat.weight)))
		bigFatties.debug("experience", string.format("Level: %s | Experience: %s", storage.bigFatties.level, storage.bigFatties.experience))
		bigFatties.debug("stomach", string.format("Capacity: %s/%s | Contents: %s", bigFatties.stomach.contents, bigFatties.stomach.capacity, storage.bigFatties.stomach))
		bigFatties.debug("breasts", string.format("Capacity: %s/%s | Contents: %s", bigFatties.breasts.contents, bigFatties.breasts.capacity, storage.bigFatties.breasts))
		bigFatties.debug("size", string.format("%s | %slb (Bloat: %slb)", bigFatties.currentSize.size..(bigFatties.currentVariant and " + "..bigFatties.currentVariant or ""), storage.bigFatties.weight + bigFatties.stomach.bloat.weight, bigFatties.stomach.bloat.weight))
	end
	bigFatties.optionChanged = false
end

bigFatties = {
	-- Mod functions
	----------------------------------------------------------------------------------
	isEnabled = function()
		return storage.bigFatties.enabled
	end,

	digest = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Run stuff for vore.
		bigFatties.voreDigest(dt)
		-- Don't do anything if stomach is empty.
		if storage.bigFatties.stomach == 0 and storage.bigFatties.bloat == 0 then return end
		-- Amount is 1 + 1% of food value, or the remaining food value.
		local amount = math.min(math.round((storage.bigFatties.stomach/100 + 1) * bigFatties.getStat("digestion") * dt, 4), storage.bigFatties.stomach)
		storage.bigFatties.stomach = math.round(math.max(storage.bigFatties.stomach - amount, 0), 4)
		-- Ditto, but 3 + 1% for bloat.
		local bloatAmount = math.min(math.round((storage.bigFatties.bloat/100 + 3) * bigFatties.getStat("digestion") * bigFatties.getStat("bloatDigestion") * dt, 4), storage.bigFatties.bloat)
		storage.bigFatties.bloat = math.round(math.max(storage.bigFatties.bloat - bloatAmount, 0), 4)
		-- Gain weight based on amount digested, milk production, and digestion efficiency.
		local breastAmount = 0
		if bigFatties.breasts.contents < bigFatties.breasts.capacity then
			-- How much milk liquid/unit (50% efficient)
			local milkRatio = bigFatties.settings.drinkables.milk * 2
			breastAmount = math.round(math.min(amount * bigFatties.getStat("absorption") * bigFatties.getStat("breastProduction"), bigFatties.breasts.capacity - bigFatties.breasts.contents), 4)
			bigFatties.gainMilk(breastAmount/milkRatio)
		end
		bigFatties.gainWeight((amount * bigFatties.getStat("absorption")) - breastAmount)
		-- Don't heal if eaten.
		if not storage.bigFatties.pred then
			-- Base amount 1 health (100 food would restore 100 health, increased by healing)
			status.modifyResource("health", amount * bigFatties.getStat("healing"))
			-- Energy regenerates 100x as fast, but without the healing stat.
			if status.isResource("energy") and not status.resourcePositive("energyRegenBlock") and bigFatties.hasSkill("digestionEnergy") then
				status.modifyResource("energy", amount * 100)
			end
		end
	end,

	gurgle = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if the stomach is empty.
		if storage.bigFatties.stomach == 0 and storage.bigFatties.bloat == 0 and not (#storage.bigFatties.entityStomach > 0) then return end
		-- Roughly every 30 seconds (lowered with skill), gurgle (i.e. instantly digest 1 - 3 seconds worth of food).
		if not bigFatties.hasOption("disableGurgles") and math.random(1, math.round((30/bigFatties.getStat("gurgleRate"))/dt)) == 1 then
			local seconds = bigFatties.getStat("gurgleAmount") * math.random(100, 300)/100
			bigFatties.digest(seconds)
			if storage.bigFatties.bloat > 0 and bigFatties.getStat("bloatDigestion") > 0 and math.random(1, 3) == 1 then
				-- Every 100 bloat pitches the sound down and volume up by 10%, max 25%
				local belchMultiplier = math.min(storage.bigFatties.bloat/1000, 0.25)
				world.sendEntityMessage(entity.id(), "bigFatties.playSound", "belch", 0.5 + belchMultiplier, (math.random(110,130)/100) * (1 - belchMultiplier))
			end
			world.sendEntityMessage(entity.id(), "bigFatties.playSound", "digest", 0.75, (2 - seconds/5) - storage.bigFatties.weight/(bigFatties.settings.maxWeight * 2))
		end
		-- Rumble sound every 10 seconds.
		if not bigFatties.hasOption("disableRumbles") and math.random(1, math.round(10/dt)) == 1 then
			world.sendEntityMessage(entity.id(), "bigFatties.playSound", "rumble", 0.75, (math.random(90,110)/100))
		end
	end,

	exercise = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Jumping > Running > Walking
		local effort = 0
		if mcontroller.groundMovement() then
			if mcontroller.walking() then
				effort = 0.125
			end
			if mcontroller.running() then
				effort = 0.25
				-- Consume 5% energy/second if the entity is more than double their capacity.
				if bigFatties.stomach.fullness > bigFatties.getStat("strainedThreshhold") then
					status.overConsumeResource("energy", status.resourceMax("energy") * bigFatties.getStat("strainedResistance") * 0.05 * (bigFatties.stomach.fullness - bigFatties.getStat("strainedThreshhold")) * dt)
				end
			end
			-- Reset jump checker while on ground.
			didJump = false
			-- Moving through liquid takes up to 50% more effort.
			effort = effort * (1 + math.min(math.round(mcontroller.liquidPercentage(), 1), 0.5))
		elseif not mcontroller.liquidMovement() and mcontroller.jumping() and not didJump then
			effort = 1
		else
			didJump = true
		end
		-- Slow down up to 50% depending on capacity, and disable running without energy if over 2x.
		mcontroller.controlModifiers({
			runningSuppressed = (not status.resourcePositive("energy") or status.resourceLocked("energy")) and (bigFatties.stomach.fullness > bigFatties.getStat("strainedThreshhold")),
			speedModifier = math.max(0.5, (1 - math.max(0, (bigFatties.stomach.fullness - bigFatties.getStat("strainedThreshhold"))/4) * bigFatties.getStat("strainedResistance")))
		})
		-- Lose weight based on weight, effort, and the multiplier.
		local exerciseMultiplier = math.round((1 + storage.bigFatties.weight/entity.weight)^0.75, 2)
		local amount = effort * exerciseMultiplier * bigFatties.getStat("metabolism") * bigFatties.getStat("metabolismReduction") * dt
		bigFatties.loseWeight(amount)
	end,

	drink = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if drinking is disabled.
		if bigFatties.hasOption("disableDrinking") then return end
		-- Can only drink if you're below capacity.
		if bigFatties.stomach.contents > bigFatties.stomach.capacity then return end
		-- More accurately calculate where the enities's mouth is.
		local mouthOffset = {0.375 * mcontroller.facingDirection() * (mcontroller.crouching() and 1.5 or 1), (mcontroller.crouching() and 0 or 1) - 1}
		local mouthPosition = vec2.add(world.entityMouthPosition(entity.id()), mouthOffset)
		local mouthLiquid = world.liquidAt(mouthPosition) or world.liquidAt(vec2.add(mouthPosition, {0, 0.25}))
		-- Space out 'drinks', otherwise they'll happen every script update.
		drinkTimer = math.max((drinkTimer or 0) - dt, 0)
		drinkCounter = drinkCounter or 0
		-- Check if drinking isn't on cooldown.
		if drinkTimer == 0 then
			-- Check if there is liquid in front of the entities's mouth, and if it is milk/jelly/lard/chocolate.
			if mouthLiquid and bigFatties.settings.drinkables[root.liquidName(mouthLiquid[1])] then
				-- Remove liquid at the entities's mouth, and store how much liquid was removed.
				local consumedLiquid = world.destroyLiquid(mouthPosition) or world.destroyLiquid(vec2.add(mouthPosition, {0, 0.25}))
				if consumedLiquid and consumedLiquid[1] and consumedLiquid[2] then
					-- Increment counter by one, up to twenty.
					drinkCounter = math.min(drinkCounter + 1, 20)
					-- Reset the drink cooldown, shorter based on how high drinkCounter is.
					drinkTimer = 1/(1 + drinkCounter/10)
					-- Add to entities's stomach based on liquid consumed.
					local foodAmount = bigFatties.settings.drinkables[root.liquidName(consumedLiquid[1])]
					local bloatAmount = math.max(0, 10 - (foodAmount or 0))
					bigFatties.feed(foodAmount * consumedLiquid[2])
					bigFatties.gainBloat(bloatAmount * consumedLiquid[2])
					-- Play drinking sound. Volume increased by amount of liquid consumed.
					world.sendEntityMessage(entity.id(), "bigFatties.playSound", "drink", 0.5 + 0.5 * consumedLiquid[2], math.random(8, 12)/10)
				end
			else
				-- Reset the drink counter if there is nothing to drink.
				if drinkCounter >= 10 then
					-- Gets up to 25% deeper depending on how many 'sips' over 10 were taken.
					local belchMultiplier = 1 - (drinkCounter - 10) * 0.25/10
					world.sendEntityMessage(entity.id(), "bigFatties.playSound", "belch", 0.75, (math.random(110,130)/100) * belchMultiplier)
				end
				drinkCounter = 0
			end
		end
	end,

	updateFoodItem = function(item)
		if configParameter(item, "foodValue") and not configParameter(item, "bf_effectApplied", false) then
			local experienceRatio = {
				common = 1,
				uncommon = 1.1,
				rare = 1.25,
				legendary = 1.5,
				essential = 1.5
			}
			item.parameters.bf_effectApplied = true
			local effects = configParameter(item, "effects", jarray())
			if not effects[1] then
				table.insert(effects, jarray())
			end
			table.insert(effects[1], {effect = "bigfattiesfood", duration = configParameter(item, "foodValue", 0)})
			table.insert(effects[1], {effect = "bigfattiesexperience", duration = configParameter(item, "foodValue", 0) * experienceRatio[string.lower(configParameter(item, "rarity", "common"))]})
			item.parameters.effects = effects
			item.parameters.bf_foodValue = configParameter(item, "foodValue", 0)
			item.parameters.foodValue = 0

			return item
		end
		return false
	end,

	updateStatuses = function()
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Check if statuses don't exist. (using the sound handler since it doesn't change)
		if not status.uniqueStatusEffectActive("bigfattiessoundhandler") then
			bigFatties.createStatuses()
		end
	end,

	updateStats = function(force)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Give the entity hitbox, bonus stats, and effects based on fatness.
		if bigFatties.currentSize.size ~= (oldSize and oldSize.size or nil) or force then
			status.setPersistentEffects("bigfatties", {
				{stat = "maxHealth", effectiveMultiplier = 1 + (bigFatties.currentSize.healthMultiplier - 1) * bigFatties.getStat("health")},
				{stat = "fallDamageMultiplier", effectiveMultiplier = 1 + (bigFatties.currentSize.healthMultiplier - 1) * bigFatties.getStat("health") * (1 - bigFatties.getStat("fallDamageReduction"))},
				{stat = "poisonStatusImmunity", amount = bigFatties.getSkillLevel("tungstenStomach")},
				{stat = "iceStatusImmunity", amount = bigFatties.currentSizeIndex >= 3 and bigFatties.getSkillLevel("iceImmunity") or 0},
				{stat = "iceResistance", amount = math.min(bigFatties.getStat("iceResistance") * (bigFatties.currentSizeIndex - 1)/3, bigFatties.getStat("iceResistance"))}
			})
		end
		-- Check if the entity is using a morphball (Tech patch bumps this number for the morphball).
		if status.stat("activeMovementAbilities") > 1 then return end
		baseParameters = baseParameters or mcontroller.baseParameters()

		if (not controlParameters or bigFatties.currentSize.size ~= (oldSize and oldSize.size or nil) or oldWeightMultiplier ~= bigFatties.weightMultiplier) or force then
			local movementModifier = math.max(0, 1 - (bigFatties.currentSize.movementPenalty + bigFatties.currentSize.movementPenalty * (1 - bigFatties.getStat("movement"))))
			if bigFatties.currentSize.movementPenalty >= 1 then
				movementModifier = 0
			end
			controlParameters = sb.jsonMerge(
				{
					mass = baseParameters.mass * bigFatties.weightMultiplier,
					walkSpeed = baseParameters.walkSpeed * movementModifier,
					runSpeed = baseParameters.runSpeed * movementModifier,
					flySpeed = baseParameters.flySpeed * movementModifier,
					bounceFactor = bigFatties.currentSize.bounce and (bigFatties.currentSize.bounce * bigFatties.getSkillLevel("bounce")) or nil,
					groundForce = baseParameters.groundForce * bigFatties.weightMultiplier,
					airForce = baseParameters.airForce * bigFatties.weightMultiplier,
					liquidForce = baseParameters.liquidForce * bigFatties.weightMultiplier,
					airFriction = baseParameters.airFriction * bigFatties.weightMultiplier^(1/3),
				  liquidBuoyancy = baseParameters.liquidBuoyancy + math.min(bigFatties.weightMultiplier * 0.1, 0.95),
					liquidFriction = baseParameters.liquidFriction * bigFatties.weightMultiplier^(1/3),
					normalGroundFriction = baseParameters.normalGroundFriction * bigFatties.weightMultiplier,
					ambulatingGroundFriction = baseParameters.ambulatingGroundFriction * bigFatties.weightMultiplier,
					airJumpProfile = {
						jumpSpeed = baseParameters.airJumpProfile.jumpSpeed * movementModifier,
						jumpControlForce = baseParameters.airJumpProfile.jumpControlForce * bigFatties.weightMultiplier,
					},
					liquidJumpProfile = {
						jumpSpeed = baseParameters.liquidJumpProfile.jumpSpeed * movementModifier,
						jumpControlForce = baseParameters.liquidJumpProfile.jumpControlForce * bigFatties.weightMultiplier,
					}
				},
				((not bigFatties.currentSize.isBlob and bigFatties.hasOption("disableHitbox")) and {} or bigFatties.currentSize.controlParameters)
			)
		end
		mcontroller.controlParameters(controlParameters)
	end,

	updateSkills = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Check for Iron Stomach/Tungsten Stomach upgrades.
		if bigFatties.hasSkill("ironStomach") and not bigFatties.hasSkill("tungstenStomach") then
			if status.uniqueStatusEffectActive("foodpoison") then
				status.removeEphemeralEffect("foodpoison")
			end
		end
	end,

	createStatuses = function()
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Remove all old statuses.
		world.sendEntityMessage(entity.id(), "bigFatties.expire")
		status.addEphemeralEffect("bigfattiessoundhandler")
		if bigFatties.type == "player" then
			-- Removing them just puts them back in order (Size tracker before stomach tracker)
			local fatTracker = "bigfatties"..bigFatties.currentSize.size
			status.removeEphemeralEffect(fatTracker)
			status.addEphemeralEffect(fatTracker)
			status.removeEphemeralEffect("bigfattiesstomach")
			status.addEphemeralEffect("bigfattiesstomach")
		end
		status[((storage.bigFatties.pred or not status.resourcePositive("health")) and "add" or "remove").."EphemeralEffect"]("bigfattiesvore")
	end,

	gainExperience = function(amount, multiplier)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		local multiplier = multiplier or bigFatties.getStat("experienceMultiplier")
		local amount = math.round((amount or 0) * multiplier, 2)

		local levelModifier = 1/(1 + storage.bigFatties.level * 0.05)

		storage.bigFatties.experience = storage.bigFatties.experience + math.round(amount * levelModifier, 3)

		if storage.bigFatties.experience >= 100 then
			storage.bigFatties.level = storage.bigFatties.level + 1
			storage.bigFatties.experience = storage.bigFatties.experience - 100

			bigFatties.gainExperience(nil, multiplier)
		end
	end,

	toggleOption = function(option)
		storage.bigFatties.options[option] = not storage.bigFatties.options[option] and true or nil
		bigFatties.optionChanged = true
		return storage.bigFatties.options[option]
	end,

	hasOption = function(option)
		return storage.bigFatties.options[option]
	end,

	getSkillUnlockedLevel = function(skill)
		return (storage.bigFatties.unlockedSkills[skill] or 0)
	end,

	hasUnlockedSkill = function(skill, level)
		return (bigFatties.getSkillUnlockedLevel(skill) >= (level or 1))
	end,

	getSkillLevel = function(skill)
		return (storage.bigFatties.skills[skill] or 0)
	end,

	hasSkill = function(skill, level)
		return (bigFatties.getSkillLevel(skill) >= (level or 1) or (bigFatties.settings.stats[skill] and bigFatties.getStatLevel(skill) >= (level or 1)))
	end,

	upgradeSkill = function(skill, cost)
		if bigFatties.settings.stats[skill] then
			if bigFatties.getStatUnlockedLevel(skill) == bigFatties.getStatLevel(skill) then
			storage.bigFatties.stats[skill] = math.min(bigFatties.getStatUnlockedLevel(skill) + 1, bigFatties.settings.stats[skill].maxLevel)
			end
			storage.bigFatties.unlockedStats[skill] = math.min(bigFatties.getStatUnlockedLevel(skill) + 1, bigFatties.settings.stats[skill].maxLevel)
		else
			if bigFatties.getSkillUnlockedLevel(skill) == bigFatties.getSkillLevel(skill) then
				storage.bigFatties.skills[skill] = math.min(bigFatties.getSkillUnlockedLevel(skill) + 1, bigFatties.skills[skill].levels or math.huge)
			end
			storage.bigFatties.unlockedSkills[skill] = math.min(bigFatties.getSkillUnlockedLevel(skill) + 1, bigFatties.skills[skill].levels or math.huge)
		end
		storage.bigFatties.level = math.max(storage.bigFatties.level - math.round(cost or 0), 0)
		bigFatties.gainExperience()
	end,

	setSkill = function(skill, level)
		if bigFatties.settings.stats[skill] then
			storage.bigFatties.stats[skill] = math.max(math.min(level, bigFatties.getStatUnlockedLevel(skill)), 0)
		else
			storage.bigFatties.skills[skill] = math.max(math.min(level, bigFatties.getSkillUnlockedLevel(skill)), 0)
		end
	end,

	getStatUnlockedLevel = function(stat)
		return math.min(storage.bigFatties.unlockedStats[stat] or 0, bigFatties.settings.stats[stat].maxLevel)
	end,

	getStatLevel = function(stat)
		return math.min(storage.bigFatties.stats[stat] or 0, bigFatties.settings.stats[stat].maxLevel)
	end,

	getStatBonus = function(stat)
		return math.min(bigFatties.settings.stats[stat].base + bigFatties.getStatLevel(stat) * bigFatties.settings.stats[stat].increase, bigFatties.settings.stats[stat].maxValue or math.huge)
	end,

	getStatMultiplier = function(stat)
		local multiplier = 1
		if bigFatties.settings.statusEffectModifiers.multipliers[stat] then
			for k, v in pairs(bigFatties.settings.statusEffectModifiers.multipliers[stat]) do
				if status.uniqueStatusEffectActive(k) then multiplier = multiplier * v end
			end
		end
		return multiplier
	end,

	getEffectBonus = function(stat)
		local bonus = 0
		if bigFatties.settings.statusEffectModifiers.bonuses[stat] then
			for k, v in pairs(bigFatties.settings.statusEffectModifiers.bonuses[stat]) do
				if status.uniqueStatusEffectActive(k) then bonus = bonus + v end
			end
		end
		return bonus
	end,

	getAccessory = function(slot)
		return storage.bigFatties.accessories[slot]
	end,

	getAccessoryModfiers = function(stat)
		if not stat then
			local accessoryModifiers = {}
			for _, accessory in pairs(storage.bigFatties.accessories) do
				for _, stat in pairs(configParameter(accessory, "stats", {})) do
					accessoryModifiers[stat.name] = math.round((accessoryModifiers[stat.name] or 0) + stat.modifier, 3)
				end
			end
			return accessoryModifiers
		else
			return math.max(-1, bigFatties.accessoryModifiers[stat] or 0)
		end
	end,

	setAccessory = function(item, slot)
		storage.bigFatties.accessories[slot] = item
		bigFatties.accessoryModifiers = bigFatties.getAccessoryModfiers()
		bigFatties.optionChanged = true
	end,

	getStat = function(stat)
		return math.max(bigFatties.getStatBonus(stat) + ((bigFatties.settings.stats[stat].base ~= 0 and bigFatties.settings.stats[stat].base or 1) * bigFatties.getAccessoryModfiers(stat)) + bigFatties.getEffectBonus(stat), 0) * bigFatties.getStatMultiplier(stat)
	end,

	getSize = function(weight)
		-- Default to base size if the mod is off.
		if not bigFatties.isEnabled() then
			return bigFatties.sizes[1], 1
		end

		local sizeIndex = 0
		-- Go through all bigFatties.sizes (smallest to largest) to find which size.
		for i in ipairs(bigFatties.sizes) do
			if weight >= bigFatties.sizes[i].weight and not (bigFatties.sizes[i].isBlob and bigFatties.hasOption("disableBlob")) then
				sizeIndex = i
			end
		end

		return bigFatties.sizes[sizeIndex], sizeIndex
	end,

	hunger = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Upgrade for preventing starving.
		if bigFatties.hasSkill("preventStarving") then
			-- Check if the player is about to starve (< 1% food).
			local isHungry = status.resource("food") < 0.01
			if isHungry then
				local minimumOffset = bigFatties.getSkillLevel("minimumSize")
				local foodAmount = math.min((minimumOffset > 0 and (storage.bigFatties.weight - bigFatties.sizes[minimumOffset + 1].weight) or storage.bigFatties.weight) * 0.1, 0.01 - status.resource("food"))
				status.giveResource("food", foodAmount)
				bigFatties.loseWeight(foodAmount * 10)
			end
		end
		-- Set the statuses.
		if bigFatties.stomach.fullness >= 1 then
			status.addEphemeralEffect("wellfed")
		elseif status.uniqueStatusEffectActive("wellfed") then
			world.sendEntityMessage(entity.id(), "bigFatties.expire_Wellfed")
		end
	end,

	getStomach = function()
			local stomachContents = storage.bigFatties.stomach
			local stomachCapacity = 70 * bigFatties.getStat("capacity")
			-- Add how heavy every entity in the stomach is to the counter.
			for _, v in pairs(storage.bigFatties.entityStomach) do
				stomachContents = stomachContents + v.weight + v.bloat
			end

			local bloatAmount = storage.bigFatties.bloat
			-- Bloat up to twice your stomach capacity (or max threshhold, whatever is greater), the rest becomes temporary fat.
			local bloatStomach = math.max(0, math.min(bloatAmount, math.max(stomachCapacity, bigFatties.settings.threshholds.stomach[#bigFatties.settings.threshholds.stomach].amount) - stomachContents))
			-- Cap weight at max weight.
			local bloatWeight = math.min(bloatAmount - bloatStomach, bigFatties.settings.maxWeight - storage.bigFatties.weight)
			-- Add to stomach capacity.
			stomachContents = stomachContents + bloatStomach

			return {
				capacity = stomachCapacity,
				food = math.round(storage.bigFatties.stomach, 3),
				contents = math.round(stomachContents, 3),
				fullness = math.round(stomachContents/stomachCapacity, 2),
				bloat = {
					total = math.round(bloatAmount, 3),
					stomach = math.round(bloatStomach, 3),
					weight = math.round(bloatWeight, 3)
				}
			}
	end,

	getBreasts = function()
			local breastContents = storage.bigFatties.breasts
			local breastCapacity = 10 * bigFatties.getStat("breastCapacity")

			return {
				capacity = breastCapacity,
				contents = math.round(breastContents, 3),
				fullness = math.round(breastContents/breastCapacity, 2)
			}
	end,

	getChestVariant = function(size)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end

		local variant = nil

		local breastSize = math.max(bigFatties.breasts.contents,
			bigFatties.hasOption("busty") and bigFatties.settings.threshholds.breasts[1].amount or (
			bigFatties.hasOption("milky") and bigFatties.settings.threshholds.breasts[2].amount or 0)
		)

		local stomachSize = math.max(storage.bigFatties.stomachLerp,
			bigFatties.hasOption("stuffed") and bigFatties.settings.threshholds.stomach[2].amount or (
			bigFatties.hasOption("filled") and bigFatties.settings.threshholds.stomach[5].amount or (
			bigFatties.hasOption("gorged") and bigFatties.settings.threshholds.stomach[6].amount or 0))
		)

		for _, v in ipairs(bigFatties.settings.threshholds.breasts) do
			if contains(size.variants, v.name) then
				if breastSize >= v.amount then
					variant = v.name
				end
			end
		end

		for _, v in ipairs(bigFatties.settings.threshholds.stomach) do
			if contains(size.variants, v.name) then
				if stomachSize >= v.amount then
					variant = v.name
				end
			end
		end

		if bigFatties.hasOption("hyper") then
			variant = "hyper"
		end

		return variant
	end,

	getDirectives = function()
		local directives = ""
		-- Get entity species.
		local species = world.entitySpecies(entity.id())
		-- Generate a nude portrait.
		for _,v in ipairs(world.entityPortrait(entity.id(), "fullnude")) do
			-- Find the player's body sprite.
			if string.find(v.image, "body.png") then
				-- Seperate the body sprite's image directives.
				directives = string.sub(v.image,(string.find(v.image, "?")))
				break
			end
		end
		-- If the species is fullbright (novakids), append 'fe' to hexcodes to make them fullbright. (99%+ opacity)
		local fullbrightSpecies = root.assetJson(string.format("/species/%s.species", species)).humanoidOverrides and root.assetJson(string.format("/species/%s.species", species)).humanoidOverrides.bodyFullbright
		if fullbrightSpecies then
			directives = (directives..";"):gsub("(%x)(%?)", function(a) return a..";?" end):gsub(";;", ";"):gsub("(%x+=%x%x%x%x%x%x);", function(colour)
				return string.format("%sfe;", colour)
			end)
		end
		-- Novakids have this white patch that doesn't change with default species colours, account for that too.
		if species == "novakid" then directives = string.format("%s;ffffff=fffffffe;", directives) end
		return directives
	end,

	equipSize = function(size, modifiers)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Get entity species.
		local species = world.entitySpecies(entity.id())
		-- Get entity directives
		local directives = bigFatties.getDirectives()
		-- Setup base parameters for item.
		local items = {
			legs = {name = (modifiers.legsSize or size.size)..species:lower().."legs", count=1},
			chest = {name = (modifiers.chestSize or size.size)..(modifiers.chestVariant or "")..species:lower().."chest", count=1}
		}

		-- Give the items parameters to track/prevent dupes.
		items.legs.parameters = {directives = directives, price = 0, size = (modifiers.legsSize or size.size), rarity = "essential"}
		items.chest.parameters = {directives = directives, price = 0, size = (modifiers.chestSize or size.size), variant = modifiers.chestVariant, rarity = "essential"}
		-- Base size doesn't have any items.
		if (modifiers.legsSize or size.size) == "" then items.legs = nil end
		if (modifiers.chestSize or size.size) == "" and (modifiers.chestVariant or "") == "" then items.chest = nil end
		-- Grab current worn clothing.
		local currentItems = {
			legs = player.equippedItem("legsCosmetic"),
			chest = player.equippedItem("chestCosmetic")
		}
		-- Shorthand instead of 2 blocks.
		for _, itemType in ipairs({"legs", "chest"}) do
			currentItem = currentItems[itemType]
			-- If the item isn't a generated item, give it back.
			if currentItems[itemType] and not currentItems[itemType].parameters.size and not currentItems[itemType].parameters.tempSize == size.size then
				player.giveItem(currentItems[itemType])
			end
			-- Replace the item if it isn't generated.
			if not (currentItem and currentItems[itemType].parameters.tempSize) then
				player.setEquippedItem(itemType.."Cosmetic", items[itemType])
			end
		end
	end,

	equipCheck = function(size, modifiers)
		-- Cap size in certain vehicles to prevent clipping.
		local leftCappedVehicle = false
		if mcontroller.anchorState() then
			local anchorEntity = world.entityName(mcontroller.anchorState())
			if anchorEntity and bigFatties.settings.vehicleSizeCap[anchorEntity] then
				if bigFatties.currentSizeIndex > bigFatties.settings.vehicleSizeCap[anchorEntity] then
					modifiers.chestVariant = "busty"
					modifiers.legsSize = nil
					modifiers.chestSize = nil
					size = bigFatties.sizes[bigFatties.settings.vehicleSizeCap[anchorEntity]]
					inCappedVehicle = true
				end
			end
		else
			if inCappedVehicle then
				leftCappedVehicle = true
				inCappedVehicle = false
			end
		end
		-- Skip if no changes.
		if
			size.size == (oldSize and oldSize.size or nil) and
			bigFatties.currentVariant == oldVariant and
			not leftCappedVehicle and
			not (bigFatties.swapSlotItem ~= nil and bigFatties.swapSlotItem.parameters ~= nil and (bigFatties.swapSlotItem.parameters.size ~= nil or bigFatties.swapSlotItem.parameters.tempSize ~= nil)) and not
			bigFatties.optionChanged
		then return end
		-- Check the item the player is holding.
		if bigFatties.swapSlotItem and bigFatties.swapSlotItem.parameters then
			local item = bigFatties.swapSlotItem
			-- If it's a base one then bye bye item.
			if bigFatties.swapSlotItem.parameters.size then
				player.setSwapSlotItem(nil)
			-- If it's a clothing one then reset it to the normal item in their cursor.
			elseif item.parameters.tempSize and item.parameters.baseName then
				-- Restore the original item
				item = {
					name = item.parameters.baseName,
					parameters = item.parameters,
					count = item.count
				}
				item.parameters.tempSize = nil
				item.parameters.baseName = nil
				player.setSwapSlotItem(item)
			end
		end

		modifierSize = nil
		-- Get the entity size, and what index it is in the config.
		sizeIndex = bigFatties.currentSizeIndex
		-- Check if there's a leg size modifier, and if it exists.
		if modifiers.legsSize then
			for i = 1, modifiers.legsSize do
				if bigFatties.sizes[sizeIndex + i] and bigFatties.sizes[sizeIndex + i].thickLegs then
					 modifiers.legsSize = bigFatties.sizes[sizeIndex + i].size
				end
			end
			if type(modifiers.legsSize) == "number" then modifiers.legsSize = nil end
		end
		-- Check if there's a chest size modifier, and if it exists.
		if modifiers.chestSize then
			for i = 1, modifiers.chestSize do
				if bigFatties.sizes[sizeIndex + i] and bigFatties.sizes[sizeIndex + i].thickChest then
					 modifiers.chestSize = bigFatties.sizes[sizeIndex + i].size
					 modifierSize = bigFatties.sizes[sizeIndex + i]
				end
			end
			if type(modifiers.chestSize) == "number" then modifiers.chestSize = nil end
		end
		-- Check if there's a chest variant, and if it exists.
		if modifiers.chestVariant then
			 modifiers.chestVariant = contains(bigFatties.sizes[sizeIndex].variants, modifiers.chestVariant) and modifiers.chestVariant or nil
		end

		-- Undo modifier sizes if the mod is disabled.
		if not bigFatties.isEnabled() then
			modifiers = {}
		end
		-- Iterate over worn clothing.
		local doEquip = false
		for _, itemType in ipairs({"legs", "chest"}) do
			local currentItem = player.equippedItem(itemType.."Cosmetic")
			local currentSize = modifiers[itemType.."Size"] or size.size
			-- Check if the entity is wearing something, if it's not a base item, and if it's generated but the size is wrong.
			if currentItem and not currentItem.parameters.size and currentItem.parameters.tempSize ~= currentSize then
				-- Attempt to find the item for the current size.
				if pcall(root.itemType, currentSize..(currentItem.parameters.baseName or currentItem.name)) then
					-- If found, give the new item some parameters for easier checking.
					currentItem.parameters.baseName = (currentItem.parameters.baseName or currentItem.name)
					currentItem.parameters.tempSize = currentSize
					currentItem.name = currentSize..(currentItem.parameters.baseName or currentItem.name)
					player.setEquippedItem(itemType.."Cosmetic", currentItem)
				else
					-- Reset and give the item back/remove it from the slot if an updated one couldn't be found.
					currentItem.name = currentItem.parameters.baseName or currentItem.name
					currentItem.parameters.tempSize = nil
					currentItem.parameters.baseName = nil
					player.giveItem(currentItem)
					player.setEquippedItem(itemType.."Cosmetic", nil)
					currentItem = nil
				end
			end
			-- If the entity isn't wearing an item, or the item they are wearing has the wrong size/variant.
			if not currentItem or
				currentItem and currentSize ~= "" or currentItem and not (
					currentItem.parameters.size == currentSize and currentItem.parameters.variant == modifiers[itemType.."Variant"] or
					currentItem.parameters.tempSize == currentSize or
					bigFatties.currentSizeIndex == 1 and not currentItem.parameters.size
				)
			then
				player.consumeItemWithParameter("size", currentSize, 2)
				doEquip = true
			end
			for _, removedSize in ipairs(bigFatties.sizes) do
				if removedSize ~= size then
					-- Delete all base items.
					player.consumeItemWithParameter("size", removedSize.size, 2)
				end
			end
		end
		if doEquip then
			bigFatties.equipSize(size, modifiers)
		end
	end,

	feed = function(amount)
		-- Just runs eat, but adapts based on player food.
		-- Use this rather than eat() unless you don't want to fill the hunger bar for some reason.
    local foodAmount = amount - status.giveResource("food", amount)
    local bloatAmount = amount - foodAmount
		bigFatties.eat(foodAmount)
		bigFatties.gainBloat(bloatAmount)
	end,

	eat = function(amount)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Insert food into stomach.
		amount = math.round(amount, 3)
		storage.bigFatties.stomach = storage.bigFatties.stomach + amount
	end,

	gainBloat = function(amount)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Set bloat, rounded to 4 decimals.
		amount = math.round(amount * bigFatties.getStat("bloatReduction"), 3)
		storage.bigFatties.bloat = storage.bigFatties.bloat + amount
	end,

	gainWeight = function(amount)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if weight gain is disabled.
		if bigFatties.hasOption("disableGain") then return end
		-- Increase weight by amount.
		amount = math.min(amount, bigFatties.settings.maxWeight - storage.bigFatties.weight)
		bigFatties.setWeight(storage.bigFatties.weight + amount)
		return amount
	end,

	loseWeight = function(amount)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if weight loss is disabled.
		if bigFatties.hasOption("disableLoss") then return end
		-- Decrease weight by amount (min: 0)
		amount = math.min(amount, storage.bigFatties.weight)
		bigFatties.setWeight(storage.bigFatties.weight - amount)
		return amount
	end,

	setWeight = function(amount)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Set weight, rounded to 4 decimals.
		amount = math.round(amount, 4)
		storage.bigFatties.weight = math.max(math.min(amount, bigFatties.settings.maxWeight), bigFatties.sizes[(bigFatties.getSkillLevel("minimumSize") + 1)].weight)
	end,

	-- Milky functions
	----------------------------------------------------------------------------------
	lactating = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Check if breast capacity is exceeded.
		if bigFatties.breasts.fullness > 1 then
			if math.random(1, math.round(3/dt)) == 1 then
				local amount = math.min(math.round(bigFatties.breasts.fullness * 0.5, 1), 1, bigFatties.breasts.contents - bigFatties.breasts.capacity)
				-- Lactate away excess
				bigFatties.lactate(amount)
			end
		end
	end,

	lactate = function(amount, noConsume)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if amount is 0.
		if amount <= 0 then return end
		amount = math.min(math.round(amount, 3), bigFatties.breasts.contents)
		-- Slightly below and in front the head.
		local spawnPosition = vec2.add(world.entityMouthPosition(entity.id()), {mcontroller.facingDirection(), -1})
		-- Only remove the milk if it actually spawns.
		if world.spawnLiquid(spawnPosition, root.liquidId("milk"), amount) and not noConsume then
			storage.bigFatties.breasts = math.round(storage.bigFatties.breasts - amount, 3)
		end
	end,

	gainMilk = function(amount)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Set add, rounded to 4 decimals.
		amount = math.max(math.round(math.min(amount, (bigFatties.breasts.capacity * 1.25) - bigFatties.breasts.contents), 4), 0)
		storage.bigFatties.breasts = math.round(storage.bigFatties.breasts + amount, 4)
	end,

	-- Vore functions
	----------------------------------------------------------------------------------
	voreCheck = function()
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if there's no eaten entities.
		if not (#storage.bigFatties.entityStomach > 0) then return end
		-- table.remove is very inefficient in loops, so we'll make a new table instead and just slap in the stuff we're keeping.
		local newStomach = jarray()
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if world.entityExists(prey.id) then
				table.insert(newStomach, prey)
			-- If not beaming out or disabled, digest any missing entities.
		elseif not status.uniqueStatusEffectActive("beamin") and not bigFatties.hasOption("disablePredDigestion") then
				bigFatties.digestEntity(prey.id)
			end
		end
		storage.bigFatties.entityStomach = newStomach
	end,

	voreDigest = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if disabled.
		if bigFatties.hasOption("disablePredDigestion") then return end
		-- Don't do anything if there's no eaten entities.
		if not (#storage.bigFatties.entityStomach > 0) then return end
		-- Eaten entities take less damage the more food/entities the player has eaten (While over capacity). Max of 10x slower.
		local vorePenalty = 1
		local damageMultiplier = math.max(1, status.stat("powerMultiplier")) * bigFatties.getStat("voreDamage")
		if bigFatties.stomach.contents > bigFatties.stomach.capacity then
			vorePenalty = math.max(math.round(1/(math.max(#storage.bigFatties.entityStomach, 1) + math.max(0, bigFatties.stomach.contents - 120)/120), 2), 0.1)
		end
		-- Reduce health of all entities.
		for _, prey in pairs(storage.bigFatties.entityStomach) do
			world.sendEntityMessage(prey.id, "bigFatties.getDigested", vorePenalty * damageMultiplier * dt)
		end
	end,

	eatNearbyEntity = function(range)
		local mouthOffset = {0.375 * mcontroller.facingDirection() * (mcontroller.crouching() and 1.5 or 1), (mcontroller.crouching() and 0 or 1) - 1}
		local mouthPosition = vec2.add(world.entityMouthPosition(entity.id()), mouthOffset)
		local nearbyEntities = world.entityQuery(mouthPosition, (range or 3), {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = entity.id()})
		local eatenTargets = {}

		for _, prey in ipairs(storage.bigFatties.entityStomach) do
			table.insert(eatenTargets, prey.id)
		end

		for _, target in ipairs(nearbyEntities) do
			if not contains(eatenTargets, target) and not world.lineTileCollision(mouthPosition, world.entityPosition(target), {"Null", "Block", "Dynamic", "Slippery"}) then
				return bigFatties.eatEntity(target)
			end
		end
	end,

	eatEntity = function(preyId, force)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return false end
		-- Need the upgrades for the skill to work.
		if not (
			bigFatties.hasSkill("voreCritter") or
			bigFatties.hasSkill("voreMonster") or
			bigFatties.hasSkill("voreHumanoid")
		) then return false end
		-- Don't do anything if eaten.
		if storage.bigFatties.pred then return false end
		-- Can only eat if you're below capacity.
		if bigFatties.stomach.contents > bigFatties.stomach.capacity then return false end
		-- Don't do anything if they're already eaten.
		local eatenEntity = nil
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if prey.id == preyId then
				eatenEntity = prey
			end
		end
		if eatenEntity then return false end
		-- Don't do anything if they're not a compatible entity.
		local compatibleEntities = jarray()
		if bigFatties.hasSkill("voreMonster") or bigFatties.hasSkill("voreCritter") then
			table.insert(compatibleEntities, "monster")
		end
		if bigFatties.hasSkill("voreHumanoid") then
			table.insert(compatibleEntities, "npc")
			table.insert(compatibleEntities, "player")
		end

		if not force then
			if not contains(compatibleEntities, world.entityType(preyId)) then return false end
			if status.resourceLocked("energy") then return false end
			-- Need the upgrades for the specific entity type
			if world.entityType(preyId) == "monster" then
				if not bigFatties.hasSkill("voreMonster") then
					if not world.entityTypeName(preyId):find("critter") then
						return false
					end
				end
				if not bigFatties.hasSkill("voreCritter") then
					if world.entityTypeName(preyId):find("critter") then
						return false
					end
				end
			end
		end
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
			if not force then
				local preyHealth = world.entityHealth(preyId)
				local preyHealthPercent = preyHealth[1]/preyHealth[2]
				local energyCost = 0.05 + 0.2 * preyHealthPercent * (0.5 + ((prey.weight or 0) + (prey.bloat or 0))/240) * status.resourceMax("energy")
				status.overConsumeResource("energy", energyCost)
			end
			-- Swallow/stomach rumble
			world.sendEntityMessage(entity.id(), "bigFatties.playSound", "swallow", 1 + math.random(0, 10)/100, 1)
			world.sendEntityMessage(entity.id(), "bigFatties.playSound", "digest", 1, 0.75)
		end)
		return true
	end,

	digestEntity = function(preyId, items, preyStomach)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if disabled.
		if bigFatties.hasOption("disablePredDigestion") then return end
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
		-- Transfer eaten entities.
		storage.bigFatties.entityStomach = util.mergeLists(storage.bigFatties.entityStomach, preyStomach or jarray())
		for _, prey in ipairs(preyStomach or jarray()) do
			world.sendEntityMessage(prey.id, "bigFatties.predEaten", entity.id())
		end
		-- More accurately calculate where the enities's mouth is.
		local mouthOffset = {0.375 * mcontroller.facingDirection() * (mcontroller.crouching() and 1.5 or 1), (mcontroller.crouching() and 0 or 1) - 1}
		local mouthPosition = vec2.add(world.entityMouthPosition(entity.id()), mouthOffset)
		-- Burp/Stomach rumble.
		local belchMultiplier = 1 - math.round((digestedEntity.weight - 120)/(bigFatties.settings.maxWeight * 4), 2)
		world.sendEntityMessage(entity.id(), "bigFatties.playSound", "belch", 0.75, (math.random(110,130)/100) * belchMultiplier)
		world.sendEntityMessage(entity.id(), "bigFatties.playSound", "digest", 0.75, 0.75)
		-- Fancy little particles similar to the normal death animation.
		if not bigFatties.hasOption("disableBelches") then
			local particle = {
				action = "particle",
				specification = {
					type = "ember",
					size = 1,
					color = {188, 235, 96},
					position = {0, 0},
					initialVelocity = {2 * mcontroller.facingDirection(), 0},
					finalVelocity = {mcontroller.facingDirection(), 10},
			    approach = {5, 10},
					destructionAction = "fade",
					destructionTime = 0.25,
					layer = "middle",
					timeToLive = 0.1,
					variance = {
						initialVelocity = {2.0, 1.0},
						size = 0.5
					}
				}
			}
			local particle2 = {
				action = "particle",
				specification = sb.jsonMerge(particle.specification, {color = {144, 217, 0}})
			}

			-- Humanoids get glowy death particles.
			if digestedEntity.type == "humanoid" then
				particle.specification = sb.jsonMerge(particle.specification, {color = {96, 184, 235}, fullbright = true, timeToLive = 0.5})
				particle2.specification = sb.jsonMerge(particle2.specification, {color = {0, 140, 217}, fullbright = true, timeToLive = 0.5})
			end

			world.spawnProjectile("invisibleprojectile", mouthPosition, entity.id(), {0,0}, false, {
				damageKind = "hidden",
				universalDamage = false,
				onlyHitTerrain = true,
				timeToLive = 0,
				actionOnTimeout = {{action = "loop", count = 5, body = {particle, particle2}}}
			})
		end
		-- Iterate over and edit the items.
		for _, item in pairs(items or jarray()) do
			if math.random() < bigFatties.getStat("regurgitateChance") then
				-- Make sure this exists to start with.
				item.parameters = item.parameters or {}
				-- First time digesting the item.
				if not item.parameters.baseParameters then
					local baseParameters = {}
					for k, v in pairs(item.parameters) do
						baseParameters[k] = v
					end
					item.parameters.baseParameters = baseParameters
				end
				item.parameters.digestCount = item.parameters.digestCount and math.min(item.parameters.digestCount + 1, 3) or 1
				-- Reset values before editing.
				item.parameters.category = item.parameters.baseParameters.category
				item.parameters.price = item.parameters.baseParameters.price
				item.parameters.level = item.parameters.baseParameters.level
				item.parameters.directives = item.parameters.baseParameters.directives
				item.parameters.colorIndex = item.parameters.baseParameters.colorIndex
				item.parameters.colorOptions = item.parameters.baseParameters.colorOptions
				-- Add visual flair and reduce rarity down to common.
				local label = root.assetJson("/items/categories.config:labels")[configParameter(item, "category", ""):gsub("enviroProtectionPack", "backwear")]
				item.parameters.category = string.format("^#a6ba5d;Digested %s%s", label, ((item.parameters.digestCount > 1) and string.format(" (x%s)", item.parameters.digestCount) or ""))
				item.parameters.rarity = configParameter(item, "rarity", "common"):lower():gsub(".+", {
					uncommon = "common",
					rare = "uncommon",
					legendary = "rare"
				})
				-- Reduce price to 25% (30% - 5% per digestion) of the original value.
				item.parameters.price = math.round(configParameter(item, "price", 0) * (0.3 - 0.05 * item.parameters.digestCount))
				-- Reduce armor values by 25% per digestion. (Capped at the planet threat level)
				item.parameters.level = math.max(math.min(configParameter(item, "level", 0) - item.parameters.digestCount, world.threatLevel()), 0)
				-- Disable status effects.
				item.parameters.statusEffects = root.itemConfig(item).statusEffects and jarray() or nil
				-- Disable effects.
				item.parameters.effectSources = root.itemConfig(item).effectSources and jarray() or nil
				-- Disable augments.
				if configParameter(item, "acceptsAugmentType") then
					item.parameters.acceptsAugmentType = ""
				end
				if configParameter(item, "tooltipKind") == "baseaugment" then
					item.parameters.tooltipKind = "back"
				end
				-- Give the armor some colour changes to make it look digested.
				item.parameters.colorOptions = configParameter(item, "colorOptions", {})
				item.parameters.colorIndex = configParameter(item, "colorIndex", 0) % (#item.parameters.colorOptions > 0 and #item.parameters.colorOptions or math.huge)
				-- Convert colorOptions and colorIndex to directives.
				if item.parameters.colorOptions and #item.parameters.colorOptions > 0 and not configParameter(item, "directives", "") ~= "" then
					item.parameters.directives = "?replace;"
					for fromColour, toColour in pairs(item.parameters.colorOptions[item.parameters.colorIndex + 1]) do
						item.parameters.directives = string.format("%s%s=%s;", item.parameters.directives, fromColour, toColour)
					end
				end
				item.parameters.directives = configParameter(item, "directives", "")..string.rep("?brightness=-20?multiply=e9ffa6?saturation=-20", item.parameters.digestCount)
				item.parameters.colorIndex = nil
				item.parameters.colorOptions = jarray()
				-- Spawn the item.
				world.spawnItem(item.name, mouthPosition, 1, item.parameters, {math.random(5,10) * mcontroller.facingDirection(), math.random(-3, 3)}, 1)
			-- Twice the chance to regurgitate 'scrap' item instead.
		elseif math.random() < 2 * bigFatties.getStat("regurgitateChance") then
				for _, item in pairs(root.createTreasure("regurgitatedClothing", 0)) do
					world.spawnItem(item, mouthPosition, 1, nil, {math.random(5, 10) * mcontroller.facingDirection(), math.random(-3, 3)}, 1)
				end
			end
		end
		bigFatties.feed(digestedEntity.weight, digestedEntity.type)
		bigFatties.gainBloat(digestedEntity.bloat)
		bigFatties.gainExperience(digestedEntity.experience)
		return true
	end,

	preyStruggle = function(preyId, struggleStrength)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Only continue if they're actually eaten.
		for preyIndex, prey in ipairs(storage.bigFatties.entityStomach) do
			if prey.id == preyId then
				local preyHealth = world.entityHealth(prey.id)
				local preyHealthPercent = preyHealth[1]/preyHealth[2]
				local struggleStrength = (1 - bigFatties.getStat("struggleResistance")) * struggleStrength/math.max(1, status.stat("powerMultiplier"))

				local vorePenalty = 1
				local damageMultiplier = math.max(1, status.stat("powerMultiplier")) * bigFatties.getStat("voreDamage")
				if bigFatties.stomach.contents > bigFatties.stomach.capacity then
					vorePenalty = math.max(math.round(1/(math.max(#storage.bigFatties.entityStomach, 1) + math.max(0, bigFatties.stomach.contents - 120)/120), 2), 0.1)
				end
				world.sendEntityMessage(entity.id(), "bigFatties.playSound", "struggle", math.min(1, (0.25 + math.max(0.5 * prey.weight/120, 0.35)) * (0.75 + preyHealthPercent/4)))
				if math.random() < (world.entityType(preyId) == "player" and 0.1 or (0.5 * struggleStrength)) then
					if world.entityType(preyId) == "player" or (status.resourceLocked("energy") and preyHealthPercent > 0.25) then
						bigFatties.releaseEntity(preyId)
					end
				end

				local energyAmount = status.resourceMax("energy") * (0.05 + 0.45 * struggleStrength)
				if status.resource("energy") > energyAmount then
					status.modifyResource("energy", -energyAmount)
				else
					status.overConsumeResource("energy", energyAmount)
				end

				-- Don't do anything if disabled.
				if not bigFatties.hasOption("disablePredDigestion") then
					-- 1 second worth of digestion per struggle.
					world.sendEntityMessage(preyId, "bigFatties.getDigested", vorePenalty * damageMultiplier)
				end
				break
			end
		end
	end,

	releaseEntity = function(preyId)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
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
		-- Call back to release the entity incase the pred is releasing them.
		if releasedEntity and world.entityExists(releasedEntity.id) then
			local belchMultiplier = 1 - math.round((releasedEntity.weight - 120)/(bigFatties.settings.maxWeight * 4), 2)
			world.sendEntityMessage(entity.id(), "bigFatties.playSound", "belch", 0.75, (math.random(110,130)/100) * belchMultiplier)
			world.sendEntityMessage(releasedEntity.id, "bigFatties.getReleased", entity.id())
		end
	end,

	eaten = function(dt)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if we're not eaten.
		if not storage.bigFatties.pred then return end
		-- Check that the entity actually exists.
		if not world.entityExists(storage.bigFatties.pred) or bigFatties.hasOption("disablePrey") then
			bigFatties.getReleased()
			return
		end
		-- Disable tool usage.
		 if getmetatable ''.bigFatties_disableItems then
			 getmetatable ''.bigFatties_disableItems(true)
		 end
		-- Disable knockback while eaten.
		entity.setDamageOnTouch(false)
		-- Stop entities trying to move.
		mcontroller.clearControls()
		-- Stun the entity.
		if status.isResource("stunned") then
		  status.setResource("stunned", math.max(status.resource("stunned"), dt))
		end
		-- Stop lounging.
		mcontroller.resetAnchorState()
		-- Loose calculation for how "powerful" the prey is.
		local struggleStrength = math.max(1, status.stat("powerMultiplier")) * (0.5 + status.resourcePercentage("health")/2)

		-- Stop NPCs attacking.
		if world.entityType(entity.id()) == "npc" then
			npc.endPrimaryFire()
			npc.endAltFire()
		end
		-- Monsters don't have a powerMultiplier stat.
		if world.entityType(entity.id()) == "monster" then
			struggleStrength = 0.75 * monster.level() * (0.5 + status.resourcePercentage("health")/2)
		end
		if world.entityType(entity.id()) == "player" then
			-- Follow the pred's position, struggle if the player is using movement keys.
			local horizontalDirection = (mcontroller.xVelocity() > 0) and 1 or ((mcontroller.xVelocity() < 0) and -1 or 0)
			local verticalDirection = (mcontroller.yVelocity() > 0) and 1 or ((mcontroller.yVelocity() < 0) and -1 or 0)
			bigFatties.cycle = 1 + math.sin((os.clock() - (bigFatties.startedStruggling or os.clock())) * 2 * math.pi)
			if not (horizontalDirection == 0 and verticalDirection == 0) then
				if (bigFatties.cycle - 1) > 0.7 and not bigFatties.struggled then
					bigFatties.struggled = true
					world.sendEntityMessage(storage.bigFatties.pred, "bigFatties.preyStruggle", entity.id(), struggleStrength)
				elseif math.round(bigFatties.cycle - 1, 1) == 0 then
					bigFatties.struggled = false
				end
			else
				bigFatties.struggled = false
				bigFatties.startedStruggling = os.clock()
			end
			local predPosition = vec2.add(world.entityPosition(storage.bigFatties.pred), {
				horizontalDirection * bigFatties.cycle,
				verticalDirection * bigFatties.cycle + math.sin(os.clock() * 0.5) - 1
			})
			local distance = world.distance(predPosition, mcontroller.position())
			mcontroller.translate(vec2.lerp(10 * dt, {0, 0}, distance))
		else
			bigFatties.cycle = bigFatties.cycle and bigFatties.cycle - (dt * (0.5 + status.resourcePercentage("health")/2)) or 1
			if bigFatties.cycle <= 0 then
				world.sendEntityMessage(storage.bigFatties.pred, "bigFatties.preyStruggle", entity.id(), struggleStrength)
				bigFatties.cycle = math.random(5, 15)/10
			end
			mcontroller.setPosition(world.entityPosition(storage.bigFatties.pred))
		end
		mcontroller.setVelocity({0,0})
		-- Stop the player from colliding/moving normally.
		mcontroller.controlParameters({airFriction = 0, groundFriction = 0, liquidFriction = 0, collisionEnabled = false, gravityEnabled = false})
	end,

	getEaten = function(predId)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return false end
		-- Don't do anything if disabled.
		if bigFatties.hasOption("disablePrey") then return false end
		-- Don't do anything if already eaten.
		if storage.bigFatties.pred then return false end
		-- Check that the entity actually exists.
		if not world.entityExists(predId) then return false end
		-- Don't get eaten if already dead.
		if not status.resourcePositive("health") then return false end
		-- Override techs
		bigFatties.oldTech = {}
		for _,v in pairs({"head", "body", "legs"}) do
			local equippedTech = player.equippedTech(v)
			if equippedTech then
				bigFatties.oldTech[v] = equippedTech
			end
			player.makeTechAvailable("vore"..v)
			player.enableTech("vore"..v)
			player.equipTech("vore"..v)
		end
		-- Save the entityId of the pred.
		storage.bigFatties.pred = predId
		if npc then
			local nearbyNpcs = world.npcQuery(mcontroller.position(), 50, {withoutEntityId = entity.id(), callScript = "entity.entityInSight", callScriptArgs = {entity.id()}, callScriptResult = true})
			for _, nearbyNpc in ipairs(nearbyNpcs) do
				world.callScriptedEntity(nearbyNpc, "notify", {type = "attack", sourceId = entity.id(), targetId = storage.bigFatties.pred})
			end
		end
		-- Make the entity immune to outside damage/invisible, and disable regeneration.
		status.addEphemeralEffect("bigfattiesvore")
		entity.setDamageOnTouch(false)
		return {
			weight = entity.weight + storage.bigFatties.weight,
			bloat = entity.bloat,
			experience = math.round(entity.weight * entity.experienceRatio)
		}
	end,

	predEaten = function(predId)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if disabled.
		if bigFatties.hasOption("disablePrey") then return end
		-- Don't do anything if not already eaten.
		if not storage.bigFatties.pred then return end
		-- New pred.
		storage.bigFatties.pred = predId
		return true
	end,

	getDigested = function(digestionRate)
		-- Don't do anything if the mod is disabled.
		if not bigFatties.isEnabled() then return end
		-- Don't do anything if disabled.
		if bigFatties.hasOption("disablePreyDigestion") then return end
		-- Don't do anything if we're not eaten.
		if not storage.bigFatties.pred then return end
		-- 1% of current health + 1 or 1% max health, whichever is smaller. (Stops low hp entities dying instantly)
		local amount = (status.resource("health") * 0.01 + math.min(0.01 * status.resourceMax("health"), 1)) * digestionRate
		amount = root.evalFunction2("protection", amount, status.stat("protection"))
		-- Remove the health.
		status.overConsumeResource("health", amount)

		if not status.resourcePositive("health") then
			local items = {}
			for _, slot in ipairs({"head", "chest", "legs", "back"}) do
				local item = player.equippedItem(slot.."Cosmetic") or player.equippedItem(slot)
				if item then
					if (item.parameters and item.parameters.tempSize) then
						item.name = item.parameters.baseName
						item.parameters.tempSize = nil
						item.parameters.baseName = nil
					end
					if not (item.parameters and item.parameters.size) and not configParameter(item, "hideBody") then
						table.insert(items, item)
					end
				end
			end
			-- Enable tool usage.
			if getmetatable ''.bigFatties_disableItems then
	 			getmetatable ''.bigFatties_disableItems(false)
			end
			-- Restore techs.
			for _,v in pairs({"head", "body", "legs"}) do
				player.unequipTech("vore"..v)
				player.makeTechUnavailable("vore"..v)
			end
			for _,v in pairs(bigFatties.oldTech or {}) do
				player.equipTech(v)
			end

			world.sendEntityMessage(storage.bigFatties.pred, "bigFatties.digestEntity", entity.id(), items, storage.bigFatties.entityStomach)

			-- Are they a crewmate?
			if recruitable then
				-- Did their owner eat them?
				local predId = storage.bigFatties.pred
				storage.bigFatties.pred = nil
				if recruitable.ownerUuid() and world.entityUniqueId(predId) == recruitable.ownerUuid() then
					recruitable.messageOwner("recruits.digestedRecruit", recruitable.recruitUuid())
				end
				recruitable.despawn()
				return
			end

			die()
		end
	end,

	getReleased = function()
		-- Don't do anything if we're not eaten.
		if not storage.bigFatties.pred then return end
		-- Tell the pred we're out.
		if world.entityExists(storage.bigFatties.pred) then
			-- Callback incase the entity calls this.
			world.sendEntityMessage(storage.bigFatties.pred, "bigFatties.releaseEntity", entity.id())
			-- Don't get stuck in the ground.
			mcontroller.setPosition(world.entityPosition(storage.bigFatties.pred))
			-- Make them wet.
			status.addEphemeralEffect("wet")
			-- NPCs become hostile when released (as if damaged normally).
			if npc then
				notify({type = "attack", sourceId = entity.id(), targetId = storage.bigFatties.pred})
			end
		end
		-- Remove the pred id from storage.
		storage.bigFatties.pred = nil
		status.removeEphemeralEffect("bigfattiesvore")
		entity.setDamageOnTouch(true)
		-- Enable tool usage.
		if getmetatable ''.bigFatties_disableItems then
 			getmetatable ''.bigFatties_disableItems(false)
		end
		-- Restore techs.
		for _,v in pairs({"head", "body", "legs"}) do
			player.unequipTech("vore"..v)
			player.makeTechUnavailable("vore"..v)
		end
		for _,v in pairs(bigFatties.oldTech or {}) do
			player.equipTech(v)
		end
	end,

	messageHandlers = function()
		-- Handler for enabling the mod.
		message.setHandler("bigFatties.toggleEnable", localHandler(bigFatties.toggleEnable))
		-- Handler for grabbing data.
		message.setHandler("bigFatties.getData", simpleHandler(function() return storage.bigFatties end))
		message.setHandler("bigFatties.isEnabled", simpleHandler(bigFatties.isEnabled))
		message.setHandler("bigFatties.getSize", simpleHandler(bigFatties.getSize))
		message.setHandler("bigFatties.getStomach", simpleHandler(bigFatties.getStomach))
		message.setHandler("bigFatties.getBreasts", simpleHandler(bigFatties.getBreasts))
		message.setHandler("bigFatties.getChestVariant", simpleHandler(bigFatties.getChestVariant))
		message.setHandler("bigFatties.getDirectives", simpleHandler(bigFatties.getDirectives))
		-- Handlers for skills/stats/options
		message.setHandler("bigFatties.hasOption", simpleHandler(bigFatties.hasOption))
		message.setHandler("bigFatties.gainExperience", simpleHandler(bigFatties.gainExperience))
		message.setHandler("bigFatties.upgradeSkill", simpleHandler(bigFatties.upgradeSkill))
		message.setHandler("bigFatties.getStat", simpleHandler(bigFatties.getStat))
		message.setHandler("bigFatties.getSkillLevel", simpleHandler(bigFatties.getSkillLevel))
		message.setHandler("bigFatties.hasSkill", simpleHandler(bigFatties.hasSkill))
		message.setHandler("bigFatties.getStatLevel", simpleHandler(bigFatties.getStatLevel))
		message.setHandler("bigFatties.getAccessory", simpleHandler(bigFatties.getAccessory))
		message.setHandler("bigFatties.getAccessoryModfiers", simpleHandler(bigFatties.getAccessoryModfiers))
		-- Handlers for affecting the entity.
		message.setHandler("bigFatties.digest", simpleHandler(bigFatties.digest))
		message.setHandler("bigFatties.gurgle", simpleHandler(bigFatties.gurgle))
		message.setHandler("bigFatties.feed", simpleHandler(bigFatties.feed))
		message.setHandler("bigFatties.eat", simpleHandler(bigFatties.eat))
		message.setHandler("bigFatties.gainBloat", simpleHandler(bigFatties.gainBloat))
		message.setHandler("bigFatties.gainWeight", simpleHandler(bigFatties.gainWeight))
		message.setHandler("bigFatties.loseWeight", simpleHandler(bigFatties.loseWeight))
		message.setHandler("bigFatties.setWeight", simpleHandler(bigFatties.setWeight))
		-- Ditto but lactation.
		message.setHandler("bigFatties.gainMilk", simpleHandler(bigFatties.gainMilk))
		message.setHandler("bigFatties.lactate", simpleHandler(bigFatties.lactate))
		-- Ditto but vore.
		message.setHandler("bigFatties.eatNearbyEntity", simpleHandler(bigFatties.eatNearbyEntity))
		message.setHandler("bigFatties.eatEntity", simpleHandler(bigFatties.eatEntity))
		message.setHandler("bigFatties.digestEntity", simpleHandler(bigFatties.digestEntity))
		message.setHandler("bigFatties.preyStruggle", simpleHandler(bigFatties.preyStruggle))
		message.setHandler("bigFatties.releaseEntity", simpleHandler(bigFatties.releaseEntity))
		message.setHandler("bigFatties.getEaten", simpleHandler(bigFatties.getEaten))
		message.setHandler("bigFatties.predEaten", simpleHandler(bigFatties.predEaten))
		message.setHandler("bigFatties.getDigested", simpleHandler(bigFatties.getDigested))
		message.setHandler("bigFatties.getReleased", simpleHandler(bigFatties.getReleased))
		-- Interface/debug stuff.
		message.setHandler("bigFatties.reset", localHandler(bigFatties.reset))
		message.setHandler("bigFatties.resetWeight", localHandler(bigFatties.resetWeight))
		message.setHandler("bigFatties.resetStomach", localHandler(bigFatties.resetStomach))
		message.setHandler("bigFatties.resetBreasts", localHandler(bigFatties.resetBreasts))
	end,

	-- Other functions
	----------------------------------------------------------------------------------
	toggleEnable = function()
		bigFatties.getReleased()
		for _, prey in ipairs(storage.bigFatties.entityStomach) do
			bigFatties.releaseEntity(prey.id)
		end
		-- Do a barrel roll (just flip the boolean).
		storage.bigFatties.enabled = not bigFatties.isEnabled()
		-- Make sure the movement penalty stuff gets reset as well.
		bigFatties.updateStats(true)
		bigFatties.optionChanged = true
		if not bigFatties.isEnabled() then
			world.sendEntityMessage(entity.id(), "bigFatties.expire")
			bigFatties.equipCheck(bigFatties.getSize(0), {})
			status.clearPersistentEffects("bigfatties")
		end
		return storage.bigFatties.enabled
	end,

	reset = function()
		-- Save accessories.
		local accessories = storage.bigFatties.accessories
		-- Reset to base data.
		storage.bigFatties = root.assetJson("/scripts/bigfatties.config:baseData")
		-- Restore accessories.
		storage.bigFatties.accessories = accessories
		-- If we set this to true, the enable function sets it back to false.
		-- Means we can keep all the 'get rid of stuff' code in one place.
		storage.bigFatties.enabled = true
		bigFatties.toggleEnable()

		return true
	end,

	resetWeight = function()
		-- Set weight.
		storage.bigFatties.weight = bigFatties.sizes[(bigFatties.getSkillLevel("minimumSize") + 1)].weight
		storage.bigFatties.bloat = 0
		bigFatties.currentSize, bigFatties.currentSizeIndex = bigFatties.getSize(storage.bigFatties.weight)
		-- Reset the fat items.
		bigFatties.equipCheck(bigFatties.getSize(storage.bigFatties.weight), {
			chestVariant = bigFatties.getChestVariant(bigFatties.currentSize),
		})

		return true
	end,

	resetStomach = function()
		storage.bigFatties.stomach = 0
		return true
	end,

	resetBreasts = function()
		storage.bigFatties.breasts = 0
		return true
	end,

	debug = function(k, v)
		sb.setLogMap(string.format("%s%s", "^#b8eb00;BigFatties_", k), sb.print(v))
	end,

	-- Override functions
	----------------------------------------------------------------------------------
	overrides = function()
		if not bigFatties.didOverrides then
			-- Players
			if player then
				entity = {
					id = player.id,
					setDropPool = nullFunction,
					setDeathParticleBurst = nullFunction,
					setDeathSound = nullFunction,
					setDamageOnTouch = nullFunction,
					weight = 120,
					experienceRatio = 1,
					bloat = 0
				}
			end
			-- NPCs
			if npc then
				-- NPCs start with the mod enabled (and stuff for pred npcs)
				storage.bigFatties.enabled = true
				storage.bigFatties.stats = sb.jsonMerge(storage.bigFatties.stats, config.getParameter("initialStats", {}))
				storage.bigFatties.skills = sb.jsonMerge(storage.bigFatties.skills, config.getParameter("initialSkills", {}))
				if config.getParameter("disablePrey", false) then
					 bigFatties.getEaten = function() return false end
					 message.setHandler("bigFatties.getEaten", simpleHandler(getEaten))
				end
				-- No debug stuffs for NPCs
				bigFatties.debug = nullFunction
				-- Shortcuts to make functions work for NPCs.
				player = {
					equippedItem = npc.getItemSlot,
					setEquippedItem = npc.setItemSlot,
					isLounging = npc.isLounging,
					loungingIn = npc.loungingIn,
					equippedTech = nullFunction,
					enableTech = nullFunction,
					makeTechAvailable = nullFunction,
					makeTechUnavailable = nullFunction,
					equipTech = nullFunction,
					unequipTech = nullFunction,
					swapSlotItem = nullFunction,
					setSwapSlotItem = nullFunction,
					giveItem = nullFunction,
					consumeItemWithParameter = function(parameter, value)
						for _, v in pairs({"chest", "legs", "chestCosmetic", "legsCosmetic"}) do
							local item = npc.getItemSlot(v)
						 	if item and item.parameters and item.parameters[parameter] == value then
								npc.setItemSlot(v, nil)
							end
						end
					end
				}
				entity.setDropPool = function(...) return npc.setDropPools({...}) end
				entity.setDeathParticleBurst = npc.setDeathParticleBurst
				entity.setDeathSound = nullFunction
				entity.damageOnTouch = nullFunction
				entity.setDamageOnTouch = npc.setDamageOnTouch
				entity.weight = 120
				entity.experienceRatio = 0.5
				entity.bloat = 0
				-- NPCs don't have a food stat, and trying to adjust it crashes the script.
				bigFatties.feed = bigFatties.eat
				-- Disable stuff NPCs don't use.
				bigFatties.hunger = nullFunction
				bigFatties.drink = nullFunction
				-- Save default functions.
				npc.say_old = npc.say_old or npc.say
				openDoors_old = openDoors_old or openDoors
				closeDoors_old = closeDoors_old or closeDoors
				closeDoorsBehind_old = closeDoorsBehind_old or closeDoorsBehind
				preservedStorage_old = preservedStorage_old or preservedStorage
				-- Override default functions.
				npc.say = function(...) if not storage.bigFatties.pred then npc.say_old(...) end end
				closeDoorsBehind = function() if storage.bigFatties.pred then closeDoorsBehind_old() end end
				openDoors = function(...) return storage.bigFatties.pred and false or openDoors_old(...) end
				closeDoors = function(...) return storage.bigFatties.pred and false or closeDoors_old(...) end
				preservedStorage = function()
					-- Grab old NPC stuff
					local preserved = preservedStorage_old()
					-- Add to preserved storage so it persists in crewmembers/bounties/etc.
					preserved.bigFatties = storage.bigFatties
				  return preserved
				end
			end
			-- Monsters
			if monster then
				-- Monsters start with the mod enabled.
				storage.bigFatties.enabled = true
				-- No debug stuffs for monsters
				bigFatties.debug = nullFunction
				-- Shortcuts to make functions work for monsters.
				player = {
					equippedItem = nullFunction,
					setEquippedItem = nullFunction,
					isLounging = nullFunction,
					loungingIn = nullFunction,
					equippedTech = nullFunction,
					enableTech = nullFunction,
					makeTechAvailable = nullFunction,
					makeTechUnavailable = nullFunction,
					equipTech = nullFunction,
					unequipTech = nullFunction,
					swapSlotItem = nullFunction,
					setSwapSlotItem = nullFunction,
					giveItem = nullFunction,
					consumeItemWithParameter = nullFunction
				}
				entity.setDropPool = monster.setDropPool
				entity.setDeathParticleBurst = monster.setDeathParticleBurst
				entity.setDeathSound = monster.setDeathSound
				entity.setDamageOnTouch = monster.setDamageOnTouch
				-- Monsters cause a lot of bloat to make the stomach look full, but not be too overpowered for food.
				-- ~ 15 bloat and 10 food per block the entity's bounding box occupies.
				local boundBox = mcontroller.boundBox()
				local area = math.abs(boundBox[1]) + math.abs(boundBox[3]) * math.abs(boundBox[2]) + math.abs(boundBox[4])
				entity.bloat = math.min(math.round(area * 15 * mcontroller.baseParameters().mass), 120)
				entity.weight = 2 * entity.bloat/3
				entity.experienceRatio = 0.5
				-- Monsters don't have a food stat, and trying to adjust it crashes the script.
				bigFatties.feed = bigFatties.eat
				bigFatties.hunger = nullFunction
				-- Disable stuff monsters don't use
				bigFatties.gainExperience = nullFunction
				bigFatties.drink = nullFunction
				bigFatties.getChestVariant = function() return "" end
				bigFatties.getDirectives = function() return "" end
				bigFatties.getBreasts = function() return {capacity = 10 * bigFatties.getStat("breastCapacity"), contents = 0, fullness = 0} end
				bigFatties.equipSize = nullFunction
				bigFatties.equipCheck = nullFunction
				bigFatties.updateSkills = nullFunction
				bigFatties.updateStats = nullFunction
				bigFatties.gainBloat = nullFunction
				bigFatties.gainWeight = nullFunction
				bigFatties.loseWeight = nullFunction
				bigFatties.setWeight = nullFunction
				bigFatties.gainMilk = nullFunction
				bigFatties.lactate = nullFunction
				bigFatties.lactating = nullFunction
				-- Save default functions.
				openDoors_old = openDoors_old or openDoors
				closeDoors_old = closeDoors_old or closeDoors
				closeDoorsBehind_old = closeDoorsBehind_old or closeDoorsBehind
				-- Override default functions.
				closeDoorsBehind = function() if storage.bigFatties.pred then closeDoorsBehind_old() end end
				openDoors = function(...) return storage.bigFatties.pred and false or openDoors_old(...) end
				closeDoors = function(...) return storage.bigFatties.pred and false or closeDoors_old(...) end
			end
		end
		-- Only ever run this once per load.
		bigFatties.didOverrides = true
	end
}

-- Other functions
----------------------------------------------------------------------------------
function math.round(num, numDecimalPlaces)
	local format = string.format("%%.%df", numDecimalPlaces or 0)
	return tonumber(string.format(format, num))
end

-- Grabs a parameter, or a config, or defaultValue
configParameter = function(item, keyName, defaultValue)
	if item.parameters[keyName] ~= nil then
		return item.parameters[keyName]
	elseif root.itemConfig(item).config[keyName] ~= nil then
		return root.itemConfig(item).config[keyName]
	else
		return defaultValue
	end
end

-- Default override functions
----------------------------------------------------------------------------------
die_old = die or nullFunction
setDying = setDying or nullFunction
function die()
	if storage.bigFatties.pred then
		storage.bigFatties.pred = nil
		setDying({shouldDie = true})
		entity.setDropPool(nil)
		entity.setDeathSound(nil)
		status.setResource("health", 0)
		entity.setDeathParticleBurst(nil)
		if bigFatties.type == "monster" then
			self.deathBehavior = nil
		end
	end
	die_old()
end
