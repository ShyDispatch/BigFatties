require "/scripts/messageutil.lua"

local init_old = init or function() end
local update_old = update or function() end

function init()
  bigFatties = getmetatable ''.bigFatties
  message.setHandler("bigFatties.expire_Wellfed", localHandler(expire_Wellfed))
  status.removeEphemeralEffect("bfwellfed")
  init_old()
end

function update(dt)
  if bigFatties and bigFatties.isEnabled() then
    if status.resourcePercentage("food") > 0.99 then
      animator.setParticleEmitterActive("healing", config.getParameter("particles", true))
      update_old(dt)
    else
      animator.setParticleEmitterActive("healing", false)
    end
  else
    animator.setParticleEmitterActive("healing", config.getParameter("particles", true))
    update_old(dt)
  end
end

function expire_Wellfed()
  if bigFatties and bigFatties.isEnabled() then
    if status.resourcePercentage("food") > 0.99 then
      if effect.duration() > 0 then
        status.addEphemeralEffect("bfwellfed", effect.duration(), effect.sourceEntity())
      end
    end
  end
  effect.expire()
end
