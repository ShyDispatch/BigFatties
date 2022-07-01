function init()
	activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
	world.sendEntityMessage(activeItem.ownerEntityId(), (shiftHeld and "bigFatties.releaseEntity" or "bigFatties.eatNearbyEntity"))
end
