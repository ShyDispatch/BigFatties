function init()
  if effect.duration() > 0 then
    world.sendEntityMessage(entity.id(), "bigFatties.gainExperience", effect.duration())
  end
end

function update()
  effect.expire()
end
