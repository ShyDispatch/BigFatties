require "/scripts/messageutil.lua"

function init()
  message.setHandler("bigFatties.expire", localHandler(effect.expire))
end

function update(dt)
  -- Cross script voodoo witch magic.
  local progress = getmetatable ''.bigFatties and getmetatable ''.bigFatties.progress or 0
  if effect.duration() > 0 then
    -- Weird numbers just kinda "center" the animation.
     effect.modifyDuration((progress*0.875) - effect.duration() + 6.25)
  end
end
