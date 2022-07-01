function init()
end

function update(dt)
  local bigFatties = getmetatable ''.bigFatties
  -- lb text.
  widget.setText("lblDescription", string.format("%slb", math.floor((bigFatties and (bigFatties.weight + bigFatties.bloat.weight) or 0)*10 + 0.5)/10))
  -- Progress bar
  widget.setProgress("progressBar", bigFatties.progress/100)
  local fromWeight = bigFatties.sizes[bigFatties.currentSizeIndex].size
  local toWeight = #bigFatties.sizes == bigFatties.currentSizeIndex and bigFatties.sizes[bigFatties.currentSizeIndex].size or bigFatties.sizes[bigFatties.currentSizeIndex + 1].size
  widget.setImage("fromWeight", string.format("/interface/scripted/unfitbit/sizes/bigfatties%s.png", fromWeight))
  widget.setImage("toWeight", string.format("/interface/scripted/unfitbit/sizes/bigfatties%s.png", toWeight))
  -- Stomach bar
  widget.setProgress("stomachBar", bigFatties.stomach.contents/bigFatties.stomach.capacity)
  widget.setProgress("stomachBarFull", math.max(0, (bigFatties.stomach.contents/bigFatties.stomach.capacity) - 1))
end

function uninit()
end
