require "/scripts/messageutil.lua"
bigFatties = getmetatable ''.bigFatties

function init()
  local buttonIcon = string.format("%s.png", bigFatties.enabled and "enabled" or "disabled")
  enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
	skills = root.assetJson("/scripts/bigfatties.config:skills")
  options = root.assetJson("/scripts/bigfatties.config:options")

  wasAdmin = player.isAdmin()
  weightDecrease:setVisible(wasAdmin)
  weightIncrease:setVisible(wasAdmin)
  barPadding:setVisible(not wasAdmin)

  canUpgrade = world.entityType(pane.sourceEntity()) == "object" or player.isAdmin()

  selectedSkill = nil
  skillTreeCanvas = widget.bindCanvas(skillCanvas.backingWidget)
  setProgress(bigFatties.experience)
  populateSkillTree()
  populateOptions()
  rootSkill:onClick()
  checkSkills()
  dt = script.updateDt()

  pendant:setItem(bigFatties.getAccessory("pendant"))
  accessoryChanged("pendant")
  ring:setItem(bigFatties.getAccessory("ring"))
  accessoryChanged("ring")
  trinket:setItem(bigFatties.getAccessory("trinket"))
  accessoryChanged("trinket")

end

function update()
  --skillTreeCover:setVisible(not canUpgrade)

  if not scrolled then
    skillTree:scrollTo({240, 160})
    scrolled = true
  end

  if wasAdmin ~= player.isAdmin() then
    checkSkills()
    if selectedSkill then
      _ENV[string.format("%sSkill", selectedSkill.name)].onClick()
    end
    weightDecrease:setVisible(player.isAdmin())
    weightIncrease:setVisible(player.isAdmin())
    barPadding:setVisible(not player.isAdmin())
  end

  if experience ~= bigFatties.experience then
    setProgress(bigFatties.experience)
    checkSkills()
  end

  if level ~= bigFatties.level then
    if selectedSkill then
      _ENV[string.format("%sSkill", selectedSkill.name)].onClick()
      experienceText:setText(string.format("%s XP", bigFatties.level))
    end
    checkSkills()
  end

  -- Check promises.
  promises:update()
  wasAdmin = player.isAdmin()
  level = bigFatties.level
  experience = bigFatties.experience
end

function uninit()
end

function enable:onClick()
  promises:add(world.sendEntityMessage(player.id(), "bigFatties.toggleEnable"), function(enabled)
    local buttonIcon = string.format("%s.png", enabled and "enabled" or "disabled")
    enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
  end)
end

function reset:onClick()
  local confirmLayout = root.assetJson("/interface/confirmation/resetinfusiontableconfirmation.config")
  confirmLayout.images.portrait = world.entityPortrait(player.id(), "full")
  promises:add(player.confirm(confirmLayout), function(response)
    if response then
      promises:add(world.sendEntityMessage(player.id(), "bigFatties.reset"), function()
        checkSkills()
        rootSkill:onClick()
        local buttonIcon = "disabled.png"
        enable:setImage(buttonIcon, buttonIcon, buttonIcon.."?border=2;00000000;00000000?crop=2;3;88;22")
      end)
    end
  end)
end


function populateOptions()
  for optionIndex, option in ipairs(options) do
    optionWidget = {
      type = "panel", style = "concave", expandMode = {1, 0}, children = {
        {type = "layout", mode = "manual", size = {131, 20}, children = {
          {id = string.format("%sOption", option.name), type = "checkBox", position = {4, 5}, size = {9, 9}, toolTip = option.description, radioGroup = option.group and option.name or nil},
          {type = "label", position = {15, 6}, size = {120, 9}, align = "left", text = option.pretty},
        }}
      }
    }

    _ENV[(string.format("optionsPanel_%s", option.panel))]:addChild(optionWidget)
    _ENV[string.format("%sOption", option.name)].onClick = function() toggleOption(option) end
    _ENV[string.format("%sOption", option.name)]:setChecked(bigFatties.hasOption(option.name))
  end
end

function populateSkillTree()
  local offset = {240, 160}
  local iconOffset = {-24, -24}

  local function adjustLinePosition(pos)
    return vec2.add(vec2.add({0, 320}, {24, -20}), vec2.mul(pos, {1, -1}))
  end

  -- First loop just edits all the positions values beforehand.
  for skillName, skill in pairs(skills) do
    skill.position = vec2.add(vec2.add(vec2.mul(skill.position, 24), offset), iconOffset)
    skill.name = skillName
  end

  for skillName, skill in pairs(skills) do
    local lineColour1 = {152, 133, 99, 255}
    local lineColour2 = {165, 147, 122, 255}

    if skill.connect then
      if skill.connect[2] then
        lineColour1 = skill.connect[2][1]
        lineColour2 = skill.connect[2][2]
      end
      for _, skillName in pairs(skill.connect[1]) do
        skillTreeCanvas:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[skillName].position), lineColour1, 5)
        skillTreeCanvas:drawLine(adjustLinePosition(skill.position), adjustLinePosition(skills[skillName].position), lineColour2, 3)
      end
    end
    skillWidgets:addChild(makeSkillWidget(skill))
    -- Make the button callback
    _ENV[string.format("%sSkill", skill.name)].onClick = function() selectSkill(skill) end
    _ENV[string.format("%sSkill_locked", skill.name)].onClick = function() widget.playSound("/sfx/interface/clickon_error.ogg") end
  end
end

function makeSkillWidget(skill)
  local skillWidget = {
    type = "layout", position = skill.position, size = {48, 48}, mode = "manual", children = {
      {id = string.format("%sSkill_back", skill.name), type = "image", noAutoCrop = true, position = {12, 8}, file = string.format("%s.png?multiply=%s", skill.circular and "backCircle" or "back", skill.colour)},
      {id = string.format("%sSkill", skill.name), toolTip = skill.pretty, position = {16, 12}, type = "iconButton", image = string.format("skills/%s.png", skill.name), hoverImage = string.format("skills/%s.png", skill.name), pressImage = string.format("skills/%s.png", skill.name).."?border=1;00000000;00000000?crop=1;2;17;18"},
      {id = string.format("%sSkill_locked", skill.name), toolTip = skill.pretty, visible = false, type = "iconButton", position = {12, 8}, image = "locked.png", hoverImage = "locked.png", pressImage = "locked.png"},
      {id = string.format("%sSkill_check", skill.name), visible = false, type = "image", noAutoCrop = true, position = {28, 20}, file = "check.png"}
    }
  }
  if skill.isStat then
    skill.levels = bigFatties.settings.stats[skill.name].maxLevel
  end
  -- Under skill level for multilevel skills.
  if skill.levels > 1 then
    local level = skill.isStat and bigFatties.getStatUnlockedLevel(skill.name) or bigFatties.getSkillUnlockedLevel(skill.name)
    local currentLevel = bigFatties.getStatLevel(skill.name) or bigFatties.getSkillLevel(skill.name)
    if currentLevel < level then
      level = string.format("^#ffaaaa;%s^reset;", currentLevel)
    end
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevel", skill.name), type = "image", position = {14, 29}, file = "backLevel.png"})
    table.insert(skillWidget.children, {id = string.format("%sSkill_backLevelText", skill.name), type = "label", position = {14, 32}, size = {20, 10}, fontSize = 5, align = "center", text = string.format("%s/%s", level, skill.levels)})
  end

  if skill.hidden then
    skillWidget.children[2] = {id = string.format("%sSkill", skill.name), position = {16, 12}, type = "iconButton", image = string.format("skills/%s.png", skill.hiddenIcon), hoverImage = string.format("skills/%s.png", skill.hiddenIcon), pressImage = string.format("skills/%s.png", skill.hiddenIcon).."?border=1;00000000;00000000?crop=1;2;17;18"}
    skillWidget.children[4].file = "check.png?multiply=00000000"
  end
  return skillWidget
end

function rootSkill:onClick()
  selectSkill()
  selectedSkill = {name = "root", colour = "ffffff", circular = true}
  rootSkill_back:setFile("backCircle.png?multiply=ffffff?brightness=10?saturation=-10")
  rootSkill_back:queueRedraw()
  infoPanel:setVisible(false)
  unlockPanel:setVisible(false)
  descriptionTitle:setText("Skills")
  descriptionIcon:setFile("skills/rootSkill.png")
  descriptionIcon:queueRedraw()
  descriptionText:setText("This section allows you to modify your fat-related abilities!\n\nTo improve a skill, select its icon on the paper.\n\nSkills cost ^#b8eb00;XP^reset; to improve, which you can gain by eating food!")
end

function toggleOption(option)
  local toggled = bigFatties.toggleOption(option.name)
  if option.group then
    for _, disableOption in ipairs(options) do
      if disableOption.name ~= option.name then
        if disableOption.group == option.group then
          if bigFatties.hasOption(disableOption.name) then
            _ENV[string.format("%sOption", disableOption.name)]:setChecked(bigFatties.toggleOption(disableOption.name))
          end
        end
      end
    end
  end
  _ENV[string.format("%sOption", option.name)]:setChecked(toggled)
end

function selectSkill(skill)
  unlockPanel:setVisible(true)
  infoPanel:setVisible(false)
  local canIncrease = false
  local canDecrease = false
  local canUpgrade = false
  local skillMaxed = false
  local experienceCost = 0
  descriptionWidget:clearChildren()
  if selectedSkill and (not skill or selectedSkill.name ~= skill.name) then
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:setFile(string.format("%s.png?multiply=%s", selectedSkill.circular and "backCircle" or "back", selectedSkill.colour))
    _ENV[string.format("%sSkill_back", selectedSkill.name)]:queueRedraw()
  end
  if skill then
    _ENV[string.format("%sSkill_back", skill.name)]:setFile(string.format("%s.png?multiply=%s?brightness=30?saturation=-30", skill.circular and "backCircle" or "back", skill.colour))
    _ENV[string.format("%sSkill_back", skill.name)]:queueRedraw()

    descriptionTitle:setText(skill.pretty)
    descriptionIcon:setFile(string.format("skills/%s.png", skill.name))
    descriptionIcon:queueRedraw()
    descriptionText:setText(skill.description)

    if skill.isStat then
      infoPanel:setVisible(true)
      local baseAmount = bigFatties.settings.stats[skill.name].base
      local currentAmount = bigFatties.getStatBonus(skill.name)
      local currentIncrease = math.floor(0.5 + (100 * (currentAmount - baseAmount)/(baseAmount > 0 and baseAmount or 1)) * 10)/10
      local nextAmount = math.min(baseAmount + (bigFatties.getStatUnlockedLevel(skill.name) + 1) * bigFatties.settings.stats[skill.name].increase, bigFatties.settings.stats[skill.name].maxValue or math.huge)
      local nextIncrease = math.floor(0.5 + (100 * (nextAmount - baseAmount)/(baseAmount > 0 and baseAmount or 1)) * 10)/10

      infoCurrent:setText(string.format("Current\n^#%s;%s%s%%",
        skill.colour,
        currentIncrease > 0 and "+" or "",
        string.format("%.0f", currentIncrease)
      ))

      if bigFatties.getStatUnlockedLevel(skill.name) == skill.levels then
        infoNext:setText(string.format("Next\n^#%s;Fully levelled!", skill.colour))
      else
        infoNext:setText(string.format("Next\n^#%s;%s%s%%",
          skill.colour,
          nextIncrease > 0 and "+" or "",
          string.format("%.0f", nextIncrease)
        ))
      end

      local experienceLevel = math.min(bigFatties.getStatUnlockedLevel(skill.name) + 1, skill.levels) - 1
      experienceCost = player.isAdmin() and 0 or (skill.cost.base + skill.cost.increase * experienceLevel)
      canDecrease = bigFatties.getStatLevel(skill.name) > 0
      canIncrease = bigFatties.getStatLevel(skill.name) < bigFatties.getStatUnlockedLevel(skill.name)
      skillMaxed = bigFatties.getStatUnlockedLevel(skill.name) == skill.levels
      canUpgrade = (bigFatties.level >= experienceCost) and not skillMaxed
      unlockText:setText(string.format("%s/%s", bigFatties.getStatLevel(skill.name), bigFatties.getStatUnlockedLevel(skill.name)))
    else
      local experienceLevel = math.min(bigFatties.getSkillUnlockedLevel(skill.name) + 1, skill.levels) - 1
      experienceCost = player.isAdmin() and 0 or (skill.cost.base + skill.cost.increase * experienceLevel)
      canDecrease = bigFatties.getSkillLevel(skill.name) > 0
      canIncrease = bigFatties.getSkillLevel(skill.name) < bigFatties.getSkillUnlockedLevel(skill.name)
      skillMaxed = bigFatties.getSkillUnlockedLevel(skill.name) == skill.levels
      canUpgrade = (bigFatties.level >= experienceCost) and not skillMaxed
      unlockText:setText(string.format("%s/%s", bigFatties.getSkillLevel(skill.name), bigFatties.getSkillUnlockedLevel(skill.name)))
    end

    unlockExperience:setText(string.format("^%s;%s XP", skillMaxed and "darkgray" or (canUpgrade and "green" or "red"), skillMaxed and "-" or experienceCost))
    unlockButton:setImage(
      string.format("unlock%s.png", canUpgrade and "" or "Disabled"),
      string.format("unlock%s.png", canUpgrade and "" or "Disabled"),
      string.format("unlock%s.png?border=1;00000000;00000000?crop=1;2;25;27", canUpgrade and "" or "Disabled")
    )
    unlockIncrease:setImage(
      string.format("unlockIncrease%s.png", canIncrease and "" or "Disabled"),
      string.format("unlockIncrease%s.png", canIncrease and "" or "Disabled"),
      string.format("unlockIncrease%s.png?border=1;00000000;00000000?crop=1;2;13;15", canIncrease and "" or "Disabled")
    )
    unlockDecrease:setImage(
      string.format("unlockDecrease%s.png", canDecrease and "" or "Disabled"),
      string.format("unlockDecrease%s.png", canDecrease and "" or "Disabled"),
      string.format("unlockDecrease%s.png?border=1;00000000;00000000?crop=1;2;13;15", canDecrease and "" or "Disabled")
    )

    if skill.widget and bigFatties.hasSkill(skill.name) then
      descriptionWidget:addChild(skill.widget).onClick = descriptionFunctions[skill.widget.id]
    end
  end

  selectedSkill = skill
end

function checkSkills()
  for skillName, skill in pairs(skills) do
    _ENV[string.format("%sSkill_locked", skill.name)]:setVisible(false)
    -- Under skill level for multilevel skills.
    if skill.levels > 1 then
      local level = skill.isStat and bigFatties.getStatUnlockedLevel(skill.name) or bigFatties.getSkillUnlockedLevel(skill.name)
      local currentLevel = skill.isStat and bigFatties.getStatLevel(skill.name) or bigFatties.getSkillLevel(skill.name)
      if currentLevel < level then
        level = string.format("^#ffaaaa;%s^reset;", currentLevel)
      end
      _ENV[string.format("%sSkill_backLevelText", skill.name)]:setText(string.format("%s/%s", level, skill.levels))
    end
    if skill.requirements then
      local requirements = "Requires"
      local hasRequirements = true
      for requirement, requirementLevel in pairs(skill.requirements) do
        local hasRequirement =  (skills[requirement].isStat and bigFatties.getStatUnlockedLevel(requirement) >= requirementLevel) or bigFatties.getSkillUnlockedLevel(requirement) >= requirementLevel
        hasRequirements = hasRequirements and hasRequirement
        requirements = string.format("%s\n^%s;%s",
          requirements,
          hasRequirement and "green" or "red",
          skills[requirement].pretty..((skills[requirement].isStat or requirementLevel > 1) and ": "..requirementLevel or "")
        )
      end
      if selectedSkill and selectedSkill.name == skill.name then
        if not (hasRequirements or player.isAdmin() or bigFatties.hasSkill(skill.name)) then
          rootSkill:onClick()
        end
      end
      _ENV[string.format("%sSkill_locked", skill.name)]:setVisible(not (hasRequirements or player.isAdmin() or (skill.isStat and bigFatties.getStatUnlockedLevel(skill.name) == skill.levels) or bigFatties.getSkillUnlockedLevel(skill.name) > 0))
      _ENV[string.format("%sSkill_locked", skill.name)].toolTip = requirements
    end
    _ENV[string.format("%sSkill_check", skill.name)]:setVisible((skill.isStat and bigFatties.getStatUnlockedLevel(skill.name) == skill.levels) or bigFatties.getSkillUnlockedLevel(skill.name) == skill.levels)
  end
end

function unlockButton:onClick()
  local experienceLevel = math.min((selectedSkill.isStat and bigFatties.getStatUnlockedLevel(selectedSkill.name) or bigFatties.getSkillUnlockedLevel(selectedSkill.name)) + 1, selectedSkill.levels) - 1
  local experienceCost = selectedSkill.cost.base + selectedSkill.cost.increase * experienceLevel
  local canUpgrade = player.isAdmin() or bigFatties.level >= experienceCost
  if (selectedSkill.isStat and bigFatties.getStatUnlockedLevel(selectedSkill.name) == selectedSkill.levels) or bigFatties.getSkillUnlockedLevel(selectedSkill.name) == selectedSkill.levels or not canUpgrade then
    widget.playSound("/sfx/interface/clickon_error.ogg")
    return
  end
  bigFatties.upgradeSkill(selectedSkill.name, player.isAdmin() and 0 or experienceCost)
  bigFatties.updateStats(true)
  local level = selectedSkill.isStat and bigFatties.getStatUnlockedLevel(selectedSkill.name) or bigFatties.getSkillUnlockedLevel(selectedSkill.name)
  local currentLevel = selectedSkill.isStat and bigFatties.getStatLevel(selectedSkill.name) or bigFatties.getSkillLevel(selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end
  if selectedSkill.levels > 1 then
    _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
  end
  checkSkills()
  selectSkill(selectedSkill)
  widget.playSound("/sfx/interface/crafting_medical.ogg")
end

function unlockDecrease:onClick()
  bigFatties.setSkill(selectedSkill.name, selectedSkill.isStat and (bigFatties.getStatLevel(selectedSkill.name) - 1) or (bigFatties.getSkillLevel(selectedSkill.name) - 1))
  bigFatties.updateStats(true)
  local level = selectedSkill.isStat and bigFatties.getStatUnlockedLevel(selectedSkill.name) or bigFatties.getSkillUnlockedLevel(selectedSkill.name)
  local currentLevel = selectedSkill.isStat and bigFatties.getStatLevel(selectedSkill.name) or bigFatties.getSkillLevel(selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end
  if selectedSkill.levels > 1 then
    _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
  end
  selectSkill(selectedSkill)
end

function unlockIncrease:onClick()
  bigFatties.setSkill(selectedSkill.name, selectedSkill.isStat and (bigFatties.getStatLevel(selectedSkill.name) + 1) or (bigFatties.getSkillLevel(selectedSkill.name) + 1))
  bigFatties.updateStats(true)
  local level = selectedSkill.isStat and bigFatties.getStatUnlockedLevel(selectedSkill.name) or bigFatties.getSkillUnlockedLevel(selectedSkill.name)
  local currentLevel = selectedSkill.isStat and bigFatties.getStatLevel(selectedSkill.name) or bigFatties.getSkillLevel(selectedSkill.name)
  if currentLevel < level then
    level = string.format("^#ffaaaa;%s^reset;", currentLevel)
  end
  if selectedSkill.levels > 1 then
    _ENV[string.format("%sSkill_backLevelText", selectedSkill.name)]:setText(string.format("%s/%s", level, selectedSkill.levels))
  end
  selectSkill(selectedSkill)
end

function setProgress(progress)
  experienceBar:setFile(string.format("bar.png?crop;0;0;%s;14", math.floor(0.7 * (progress or 0) + 0.5)))
end

function weightDecrease:onClick()
  local progress = (bigFatties.weight - bigFatties.currentSize.weight)/((bigFatties.sizes[bigFatties.currentSizeIndex + 1] and bigFatties.sizes[bigFatties.currentSizeIndex + 1].weight or bigFatties.settings.maxWeight) - bigFatties.currentSize.weight)
  local targetWeight = bigFatties.sizes[math.max(bigFatties.currentSizeIndex - 1, 1)].weight
  local targetWeight2 = bigFatties.sizes[bigFatties.currentSizeIndex].weight
  bigFatties.setWeight(targetWeight + (targetWeight2 - targetWeight) * progress)
end

function weightIncrease:onClick()
  local progress = math.max(0.01, (bigFatties.weight - bigFatties.currentSize.weight)/((bigFatties.sizes[bigFatties.currentSizeIndex + 1] and bigFatties.sizes[bigFatties.currentSizeIndex + 1].weight or bigFatties.settings.maxWeight) - bigFatties.currentSize.weight))
  local targetWeight = bigFatties.sizes[bigFatties.currentSizeIndex + 1] and bigFatties.sizes[bigFatties.currentSizeIndex + 1].weight or bigFatties.settings.maxWeight
  local targetWeight2 = bigFatties.sizes[bigFatties.currentSizeIndex + 2] and bigFatties.sizes[bigFatties.currentSizeIndex + 2].weight or bigFatties.settings.maxWeight
  bigFatties.setWeight(targetWeight + (targetWeight2 - targetWeight) * progress)
end

function pendant:acceptsItem(item)
  return configParameter(item, "accessoryType") == "pendant"
end

function pendant:onItemModified()
  bigFatties.setAccessory(pendant:item(), "pendant")
  accessoryChanged("pendant")
end

function ring:acceptsItem(item)
  return configParameter(item, "accessoryType") == "ring"
end

function ring:onItemModified()
  bigFatties.setAccessory(ring:item(), "ring")
  accessoryChanged("ring")
end

function trinket:acceptsItem(item)
  return configParameter(item, "accessoryType") == "trinket"
end

function trinket:onItemModified()
  bigFatties.setAccessory(trinket:item(), "trinket")
  accessoryChanged("trinket")
end

function accessoryChanged(slot)
  local description = ""
  local item = _ENV[slot]:item()

  if item then
    for _, stat in ipairs(configParameter(item, "stats", {})) do
      local statName = bigFatties.settings.stats[stat.name].pretty
      local statValue = stat.modifier * (bigFatties.settings.stats[stat.name].invertValue and -1 or 1)
      local descriptorInvert = (statValue * (bigFatties.settings.stats[stat.name].invertDescriptor and -1 or 1)) > 0
      local statBeneficial = (statValue * (bigFatties.settings.stats[stat.name].negative and -1 or 1)) > 0
      description = description..string.format("- ^#b8eb00;%s^reset; %s %s%%^reset;\n", bigFatties.settings.stats[stat.name].pretty, (descriptorInvert and "increased by" or "reduced by")..(statBeneficial and "^green;" or "^red;"), math.floor(100 * math.abs(statValue) + 0.5))
    end
  end
  _ENV[slot.."Description"]:setText(description)

end

descriptionFunctions = {
  voreTool = function()
    if not player.hasItem("voretool") then
      player.giveItem("voretool")
    end
  end,

  lactate = function()
    bigFatties.lactate(math.random(5, 10)/10)
  end
}

configParameter = function(item, keyName, defaultValue)
  if item.parameters[keyName] ~= nil then
    return item.parameters[keyName]
  elseif root.itemConfig(item).config[keyName] ~= nil then
    return root.itemConfig(item).config[keyName]
  else
    return defaultValue
  end
end
