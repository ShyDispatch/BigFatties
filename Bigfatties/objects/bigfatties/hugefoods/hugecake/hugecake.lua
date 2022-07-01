
function init()
  storage.stage = storage.stage or config.getParameter("stage", 0)
  storage.bites = storage.bites or config.getParameter("bites", 0)

  self.stages = config.getParameter("stages", 5)
  self.bitesPerStage = config.getParameter("bitesPerStage", 4)
  self.eatenUp = false

  object.setInteractive(true)

  updateSprite()
end

function onInteraction(args)
  animator.burstParticleEmitter("bite")
  animator.playSound("bite")

  world.sendEntityMessage(args.sourceId, "bigFatties.feed", 90)

  storage.bites = storage.bites + 1
  if storage.bites >= self.bitesPerStage then
    storage.stage = storage.stage + 1
    storage.bites = 0
  end
  if storage.stage >= self.stages then
    self.eatenUp = true
    object.smash()
  end

  updateSprite()
end

function die()
  if not self.eatenUp then
    world.spawnItem(config.getParameter("objectName"), entity.position(), 1, {stage = storage.stage, bites = storage.bites})
  end
end

function updateSprite()
  animator.setGlobalTag("stage", storage.stage)
end
