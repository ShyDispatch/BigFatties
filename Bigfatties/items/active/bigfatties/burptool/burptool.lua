function init()
	activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
	world.sendEntityMessage(activeItem.ownerEntityId(), "bigFatties.playSound", "belch", 0.75, math.random(10,13)/10)	
end
