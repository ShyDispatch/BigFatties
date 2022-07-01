require "/scripts/messageutil.lua"

function init()
  message.setHandler("bigFatties.expire", localHandler(effect.expire))
end

function update(dt)
  -- Cross script voodoo witch magic.
  local stomach = getmetatable ''.bigFatties and getmetatable ''.bigFatties.stomach or {contents = 0, capacity = 1}
  local stomachPercent = math.max(math.round(stomach.contents/stomach.capacity, 2) * 100,  1)
  if effect.duration() > 0 then
    -- Weird numbers just kinda "center" the animation.
     effect.modifyDuration(stomachPercent * 0.875 - effect.duration() + 6.25)
  end
end
