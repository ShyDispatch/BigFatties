function init()
  if effect.duration() > 0 then
    world.sendEntityMessage(entity.id(), string.format("bigFatties.%s", effect.getParameter("type", "feed")), effect.duration(), effect.getParameter("foodType"))
  end
end

function update()
  effect.expire()
end
