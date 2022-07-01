-- Pass the item disable function.
local init_old = init or function() end
function init()
  init_old()
  getmetatable ''.bigFatties_disableItems = tech.setToolUsageSuppressed
end

-- DISTORTION SPHERE(S)
----------------------------------------------------------------------------------
function activate()
  if not self.active then
    animator.burstParticleEmitter("activateParticles")
    animator.playSound("activate")
    animator.setAnimationState("ballState", "activate")
    self.angularVelocity = 0
    self.angle = 0
    self.transformFadeTimer = self.transformFadeTime
  end
  tech.setParentHidden(true)
  tech.setParentOffset({0, positionOffset()})
  tech.setToolUsageSuppressed(true)
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 2}})
  self.active = true
end

-- WALL JUMP
----------------------------------------------------------------------------------
-- Allow bigger sizes to hang onto walls.
function buildSensors()
  local bounds = poly.boundBox(mcontroller.collisionPoly())
  self.wallSensors = {
    right = {},
    left = {}
  }
  for _, offset in pairs(config.getParameter("wallSensors")) do
    table.insert(self.wallSensors.left, {bounds[1] - 0.1, bounds[2] + offset})
    table.insert(self.wallSensors.right, {bounds[3] + 0.1, bounds[2] + offset})
  end
end

-- Refresh the size hitbox when checking for walls.
function checkWall(wall)
  local pos = mcontroller.position()
  local wallCheck = 0
  buildSensors()
  for _, offset in pairs(self.wallSensors[wall]) do
    -- world.debugPoint(vec2.add(pos, offset), world.pointCollision(vec2.add(pos, offset), self.wallCollisionSet) and "yellow" or "blue")
    if world.pointCollision(vec2.add(pos, offset), self.wallCollisionSet) then
      wallCheck = wallCheck + 1
    end
  end
  return wallCheck >= self.wallDetectThreshold
end
