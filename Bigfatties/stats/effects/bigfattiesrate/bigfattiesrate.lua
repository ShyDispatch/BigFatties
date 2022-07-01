function init()
end

function update(dt)
  world.sendEntityMessage(entity.id(), string.format("bigFatties.%s", effect.getParameter("type", "eat")), dt * effect.getParameter("rate", 5))
end
