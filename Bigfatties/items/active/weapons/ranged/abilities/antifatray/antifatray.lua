require "/items/active/weapons/ranged/beamfire.lua"

function BeamFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self.transitionTimer = 0
    self:setState(self.fire)
  end

  if self.weapon.currentAbility == self then
    if self.weapon.currentState == self.fire then
      self.transitionTimer = math.min(self.transitionTimer + self.dt, self.beamTransitionTime)
    end
  end
end

function BeamFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)

  util.wait(self.stances.cooldown.duration, function()
    if self.transitionTimer > 0 then
      self.transitionTimer = math.max(0, self.transitionTimer - self.dt)

      if self.transitionTimer == 0 then
        activeItem.setScriptedAnimationParameter("chains", {})
      else
        local beamStart = self:firePosition()
        local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
        local collidePoint = world.lineCollision(beamStart, beamEnd)
		
        if collidePoint then
          beamEnd = collidePoint
        end


        self:drawBeam(beamEnd, collidePoint)
      end
    end
  end)
end

function BeamFire:fire()
  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)

  local wasColliding = false
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength

    local collidePoint = world.lineCollision(beamStart, beamEnd)
	
    if collidePoint then
      beamEnd = collidePoint

      beamLength = world.magnitude(beamStart, beamEnd)

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", {beamLength, 0})

      if self.impactSoundTimer == 0 then
        animator.setSoundPosition("beamImpact", {beamLength, 0})
        animator.playSound("beamImpact")
        self.impactSoundTimer = self.fireTime
      end
    else
      animator.setParticleEmitterActive("beamCollision", false)
    end

    self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2]}}, self.fireTime)

    self:drawBeam(beamEnd, collidePoint)

    coroutine.yield()
  end

  self:reset()
  animator.playSound("fireEnd")

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function BeamFire:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = self.weapon.muzzleOffset
  newChain.endPosition = endPos

  if didCollide then
    newChain.endSegmentImage = nil
  end

  local currentFrame = self:beamFrame()
  if newChain.startSegmentImage then
    newChain.startSegmentImage = newChain.startSegmentImage:gsub("<beamFrame>", currentFrame)
  end
  newChain.segmentImage = newChain.segmentImage:gsub("<beamFrame>", currentFrame)
  if newChain.endSegmentImage then
    newChain.endSegmentImage = newChain.endSegmentImage:gsub("<beamFrame>", currentFrame)
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function BeamFire:beamFrame()
  return math.max(1, math.min(self.beamTransitionFrames, math.floor(self.transitionTimer * self.beamTransitionFrames / self.beamTransitionTime + 1.25)))
end


function Weapon:damageSource(damageConfig, damageArea, damageTimeout)
  if damageArea then
    local knockback = damageConfig.knockback
    if knockback and damageConfig.knockbackDirectional ~= false then
      knockback = knockbackMomentum(damageConfig.knockback, damageConfig.knockbackMode, self.aimAngle, self.aimDirection)
    end
    local damage = damageConfig.baseDamage * self.damageLevelMultiplier * activeItem.ownerPowerMultiplier()

    local damageLine, damagePoly
    if #damageArea == 2 then
      damageLine = damageArea
    else
      damagePoly = damageArea
    end

    return {
      poly = damagePoly,
      line = damageLine,
      damage = damage,
      trackSourceEntity = damageConfig.trackSourceEntity,
      sourceEntity = activeItem.ownerEntityId(),
      teamType = "indiscriminate",
      damageSourceKind = damageConfig.damageSourceKind,
      statusEffects = damageConfig.statusEffects,
      knockback = knockback or 0,
      rayCheck = true,
      damageRepeatGroup = damageRepeatGroup(damageConfig.timeoutGroup),
      damageRepeatTimeout = damageTimeout or damageConfig.timeout
    }
  end
end
