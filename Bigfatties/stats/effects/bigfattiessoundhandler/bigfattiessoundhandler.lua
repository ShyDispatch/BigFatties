require "/scripts/messageutil.lua"

function init()
	message.setHandler("bigFatties.playSound", simpleHandler(playSound))
	message.setHandler("bigFatties.expire", localHandler(effect.expire))
end

function update(dt)
	effect.modifyDuration(dt)
end

function playSound(soundPool, volume, pitch, loops)
	if getmetatable ''.bigFatties then
		-- Don't do anything if disabled.
		if getmetatable ''.bigFatties.hasOption("disableBelches") and soundPool == "belch" then return end
		if getmetatable ''.bigFatties.hasSkill("secret") then
			soundPool = "secret"
			volume = (volume + 0.5)/2
			pitch = (pitch + 1)/2
		end
	end
	animator.setSoundVolume(soundPool, volume or 1, 0)
	animator.setSoundPitch(soundPool, pitch or 1, 0)
	animator.playSound(soundPool, loops)
end
