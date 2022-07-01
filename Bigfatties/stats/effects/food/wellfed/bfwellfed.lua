require "/scripts/messageutil.lua"

function init()
  bigFatties = getmetatable ''.bigFatties
  message.setHandler("bigFatties.expire", localHandler(expire))

  for _, statusScript in ipairs(root.assetJson("/stats/effects/food/wellfed/wellfed.statuseffect:scripts")) do
    if statusScript ~= "wellfed_bfpatch.lua" then
      require(string.format("/stats/effects/food/wellfed/%s", statusScript))
    end
  end

  init()
end

function expire()
  if bigFatties and not bigFatties.isEnabled() then
    effect.expire()
  end
end
