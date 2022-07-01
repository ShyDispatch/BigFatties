-- param entity
function tryEatEntity(args, board)
  if args.entity == nil then return false end
  return bigFatties.eatEntity(args.entity)
end

-- param entity
function hasEatenEntity(args, board)
  if args.entity == nil then return false end
  local eatenEntity = false
	for _, prey in ipairs(storage.bigFatties.entityStomach) do
		if prey.id == args.entity then
			eatenEntity = true
			break
		end
	end
  return eatenEntity
end

function movementPenalty(args, board)
  return true, {number = (bigFatties.currentSize and bigFatties.currentSize.movementPenalty or 1)}
end

function fullStomach(args, board)
  return bigFatties.stomach.contents > bigFatties.stomach.capacity
end

function isEaten(args, board)
  return (storage.bigFatties.pred ~= nil) or status.uniqueStatusEffectActive("bigfattiesvore")
end
