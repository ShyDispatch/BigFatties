function init()
  local skill = effect.getParameter("skill")
  if skill then
    world.sendEntityMessage(entity.id(), "bigFatties.upgradeSkill", skill)
  end
end

function update()
  effect.expire()
end
