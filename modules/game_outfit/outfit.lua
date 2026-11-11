local OutfitWindow, outfits
local maxperlist = 20
local currentpage = 1
local maxpages = 1
local selectedOutfit, selectedEntry, selectedWidget, currentClotheButtonBox, currentColorBox
local colorBoxes = {}
local onAddonCheckChange

ignoreNextOutfitWindow = 0
direction = 2

local function copyOutfit(outfit)
  return {
    type = outfit.type,
    head = outfit.head or 0,
    body = outfit.body or 0,
    legs = outfit.legs or 0,
    feet = outfit.feet or 0,
    addons = outfit.addons or 0,
    mount = outfit.mount or 0
  }
end

local function normalizeOutfitEntry(entry)
  local outfitType = entry[1] or entry.type or entry.lookType or entry.looktype
  local name = entry[2] or entry.name or ''
  local thirdValue = entry[3]
  local fourthValue = entry[4]
  local addons = 0
  local enabled = true

  if type(thirdValue) == 'boolean' then
    enabled = thirdValue
    addons = tonumber(fourthValue or entry.addons or 0) or 0
  else
    addons = tonumber(thirdValue or entry.addons or 0) or 0

    if entry.enabled ~= nil then
      enabled = entry.enabled
    elseif entry.unlocked ~= nil then
      enabled = entry.unlocked
    elseif fourthValue ~= nil then
      enabled = fourthValue ~= false and fourthValue ~= 0
    end
  end

  return {
    type = outfitType,
    name = name,
    addons = math.max(0, addons),
    enabled = enabled ~= false,
    raw = entry
  }
end

local function normalizeOutfitList(outfitList)
  local normalizedOutfits = {}

  for _, entry in ipairs(outfitList or {}) do
    local outfitData = normalizeOutfitEntry(entry)

    if outfitData.type then
      normalizedOutfits[#normalizedOutfits + 1] = outfitData
    end
  end

  return normalizedOutfits
end

local function getOutfitPanel()
  return OutfitWindow and OutfitWindow:recursiveGetChildById('outfitPanel') or nil
end

local function getPagePanel()
  return OutfitWindow and OutfitWindow:recursiveGetChildById('pagePanel') or nil
end

local function getOutfitListWidget()
  return OutfitWindow and OutfitWindow:recursiveGetChildById('outfitList') or nil
end

local function getAddonCheckBox()
  return getOutfitPanel():getChildById('addon')
end

local function updatePreview()
  if not OutfitWindow or not selectedOutfit or not selectedEntry then
    return
  end

  local outfitPanel = getOutfitPanel()
  local addonCheckBox = getAddonCheckBox()
  local hasAddons = selectedEntry.addons > 0
  local addonChecked = hasAddons and (selectedOutfit.addons or 0) > 0

  addonCheckBox:setVisible(hasAddons)
  addonCheckBox.onCheckChange = nil
  addonCheckBox:setChecked(addonChecked)
  addonCheckBox.onCheckChange = onAddonCheckChange

  outfitPanel:getChildById('confirm'):setEnabled(selectedEntry.enabled)
  outfitPanel:getChildById('outfit'):setOutfit(selectedOutfit)
  outfitPanel:getChildById('name'):setText(selectedEntry.name)
end

local function selectOutfit(outfitData, widget)
  if not outfitData or not selectedOutfit then
    return
  end

  local currentOutfit = selectedOutfit
  local addonValue = 0

  if currentOutfit.type == outfitData.type and outfitData.addons > 0 and (currentOutfit.addons or 0) > 0 then
    addonValue = currentOutfit.addons
  end

  selectedOutfit = {
    type = outfitData.type,
    head = currentOutfit.head or 0,
    body = currentOutfit.body or 0,
    legs = currentOutfit.legs or 0,
    feet = currentOutfit.feet or 0,
    addons = addonValue,
    mount = currentOutfit.mount or 0
  }
  selectedEntry = outfitData
  selectedWidget = widget

  if selectedWidget then
    selectedWidget:focus()
  end

  updatePreview()
end

onAddonCheckChange = function(widget)
  if not selectedEntry or not selectedOutfit then
    return
  end

  selectedOutfit.addons = widget:isChecked() and selectedEntry.addons or 0
  updatePreview()
end

function init()
  connect(g_game, {
    onOpenOutfitWindow = create,
    onGameEnd = destroy
  })
end

function terminate()
  disconnect(g_game, {
    onOpenOutfitWindow = create,
    onGameEnd = destroy
  })
  destroy()
end

function create(creatureOutfit, outfitList, creatureMount, mountList)
  if ignoreNextOutfitWindow and g_clock.millis() < ignoreNextOutfitWindow + 1000 then
    return
  end

  if OutfitWindow and not OutfitWindow:isHidden() then
    return
  end

  currentpage = 1
  maxpages = 1
  selectedWidget = nil
  selectedEntry = nil
  currentColorBox = nil
  selectedOutfit = copyOutfit(creatureOutfit)
  outfits = normalizeOutfitList(outfitList)

  OutfitWindow = g_ui.displayUI('outfitwindow')
  if not OutfitWindow then
    return
  end

  maxpages = math.max(1, math.ceil(#outfits / maxperlist))

  for num, out in ipairs(outfits) do
    if selectedOutfit.type == out.type then
      currentpage = math.ceil(num / maxperlist)
      selectedEntry = out
      break
    end
  end

  if not selectedEntry then
    selectedEntry = outfits[1]
    if selectedEntry then
      selectedOutfit.type = selectedEntry.type
      selectedOutfit.addons = 0
    end
  end

  drawOutfitList()
  updatePageButtons()
  updatePreview()

  currentClotheButtonBox = getOutfitPanel():getChildById('template'):getChildById('head')
  getOutfitPanel():getChildById('template'):getChildById('head').onCheckChange = onClotheCheckChange
  getOutfitPanel():getChildById('template'):getChildById('primary').onCheckChange = onClotheCheckChange
  getOutfitPanel():getChildById('template'):getChildById('secondary').onCheckChange = onClotheCheckChange
  getOutfitPanel():getChildById('template'):getChildById('detail').onCheckChange = onClotheCheckChange
  for j = 0, 6 do
    for i = 0, 18 do
      local colorBox = g_ui.createWidget('ColorBox', getOutfitPanel():getChildById('colorBoxPanel'))
      local colorId = j * 19 + i
      local outfitColor = getOutfitColor(colorId)

      colorBox:setImageColor(outfitColor)
      colorBox:setId('colorBox' .. colorId)
      colorBox.colorId = colorId

      if colorId == selectedOutfit.head then
        currentColorBox = colorBox
        colorBox:setChecked(true)
      end

      colorBox.onCheckChange = onColorCheckChange
      colorBoxes[#colorBoxes + 1] = colorBox
    end
  end

  if not currentColorBox and colorBoxes[1] then
    currentColorBox = colorBoxes[1]
    currentColorBox:setChecked(true)
  end
end

function drawOutfitList()
  local pagePanel = getPagePanel()
  local outfitListWidget = getOutfitListWidget()
  if not pagePanel or not outfitListWidget then
    return
  end

  pagePanel:getChildById('page'):setText(tr('%s de %s', string.format('%02d', currentpage), string.format('%02d', maxpages)))
  outfitListWidget:destroyChildren()

  for num, out in ipairs(outfits) do
    if math.ceil(num / maxperlist) == currentpage then
      local ot = {
        type = out.type,
        head = selectedOutfit.head,
        body = selectedOutfit.body,
        legs = selectedOutfit.legs,
        feet = selectedOutfit.feet,
        addons = out.addons
      }
      local widget = g_ui.createWidget('OutfitBox', outfitListWidget)

      widget.outfit:setOutfit(ot)
      widget.ot = ot
      widget.outfitData = out

      widget:setTooltip(out.name)
      widget.lock:setVisible(not out.enabled)

      if selectedEntry and selectedEntry.type == out.type then
        selectedWidget = widget
        widget:focus()
      end

      function widget.onClick()
        selectOutfit(out, widget)
      end
    end
  end
end

function setOutfitAnimation(button)
  button:setOn(not OutfitWindow.outfitPanel.outfit:isAnimating())
  OutfitWindow.outfitPanel.outfit:setAnimate(not OutfitWindow.outfitPanel.outfit:isAnimating())
end

function setOutfitRotate()
  direction = (direction + 1) % 4

  OutfitWindow.outfitPanel.outfit:setDirection(direction)
end

function randomize()
  local outfitTemplate = {
    getOutfitPanel():getChildById('template'):getChildById('head'),
    getOutfitPanel():getChildById('template'):getChildById('primary'),
    getOutfitPanel():getChildById('template'):getChildById('secondary'),
    getOutfitPanel():getChildById('template'):getChildById('detail')
  }

  for i = 1, #outfitTemplate do
    outfitTemplate[i]:setChecked(true)
    colorBoxes[math.random(1, #colorBoxes)]:setChecked(true)
    outfitTemplate[i]:setChecked(false)
  end

  outfitTemplate[1]:setChecked(true)
end

function onClotheCheckChange(clotheButtonBox)
  if clotheButtonBox == currentClotheButtonBox then
    clotheButtonBox.onCheckChange = nil
    clotheButtonBox:setChecked(true)
    clotheButtonBox.onCheckChange = onClotheCheckChange
  else
    currentClotheButtonBox.onCheckChange = nil
    currentClotheButtonBox:setChecked(false)
    currentClotheButtonBox.onCheckChange = onClotheCheckChange
    currentClotheButtonBox = clotheButtonBox

    local colorId = 0

    if currentClotheButtonBox:getId() == 'head' then
      colorId = selectedOutfit.head
    elseif currentClotheButtonBox:getId() == 'primary' then
      colorId = selectedOutfit.body
    elseif currentClotheButtonBox:getId() == 'secondary' then
      colorId = selectedOutfit.legs
    elseif currentClotheButtonBox:getId() == 'detail' then
      colorId = selectedOutfit.feet
    end

    getOutfitPanel():getChildById('colorBoxPanel'):recursiveGetChildById('colorBox' .. colorId):setChecked(true)
  end
end

function onColorCheckChange(colorBox)
  if colorBox == currentColorBox then
    colorBox.onCheckChange = nil
    colorBox:setChecked(true)
    colorBox.onCheckChange = onColorCheckChange
  else
    currentColorBox.onCheckChange = nil
    currentColorBox:setChecked(false)
    currentColorBox.onCheckChange = onColorCheckChange
    currentColorBox = colorBox

    if currentClotheButtonBox:getId() == 'head' then
      selectedOutfit.head = currentColorBox.colorId
    elseif currentClotheButtonBox:getId() == 'primary' then
      selectedOutfit.body = currentColorBox.colorId
    elseif currentClotheButtonBox:getId() == 'secondary' then
      selectedOutfit.legs = currentColorBox.colorId
    elseif currentClotheButtonBox:getId() == 'detail' then
      selectedOutfit.feet = currentColorBox.colorId
    end

    currentColorBox:setBorderColor(getOutfitColor(currentColorBox.colorId))
    getOutfitPanel():getChildById('outfit'):setOutfit(selectedOutfit)

    local outfitListWidget = getOutfitListWidget()
    if not outfitListWidget then
      return
    end

    for _, child in ipairs(outfitListWidget:getChildren()) do
      local out = child.ot

      out.head = selectedOutfit.head
      out.body = selectedOutfit.body
      out.legs = selectedOutfit.legs
      out.feet = selectedOutfit.feet

      child.outfit:setOutfit(out)
    end
  end
end

function destroy()
  if OutfitWindow then
    OutfitWindow:destroy()

    OutfitWindow = nil
    outfits = nil
    selectedOutfit = nil
    selectedEntry = nil
    selectedWidget = nil
    currentColorBox = nil
    currentClotheButtonBox = nil
    colorBoxes = {}
  end
end

function accept()
  if not selectedOutfit or not selectedEntry then
    return
  end

  selectedOutfit.addons = getAddonCheckBox():isVisible() and getAddonCheckBox():isChecked() and selectedEntry.addons or 0

  g_game.changeOutfit(selectedOutfit)
  destroy()
end

function firstPage()
  currentpage = 1

  updatePageButtons()
  drawOutfitList()
end

function lastPage()
  currentpage = maxpages

  updatePageButtons()
  drawOutfitList()
end

function prevPage()
  currentpage = math.max(1, currentpage - 1)

  updatePageButtons()
  drawOutfitList()
end

function nextPage()
  currentpage = math.min(maxpages, currentpage + 1)

  updatePageButtons()
  drawOutfitList()
end

function updatePageButtons()
  local pagePanel = getPagePanel()
  if not pagePanel then
    return
  end

  if maxpages == 1 then
    pagePanel:getChildById('firstPage'):disable()
    pagePanel:getChildById('prevPage'):disable()
    pagePanel:getChildById('nextPage'):disable()
    pagePanel:getChildById('lastPage'):disable()
  elseif currentpage == maxpages then
    pagePanel:getChildById('firstPage'):enable()
    pagePanel:getChildById('prevPage'):enable()
    pagePanel:getChildById('nextPage'):disable()
    pagePanel:getChildById('lastPage'):disable()
  elseif currentpage == 1 then
    pagePanel:getChildById('firstPage'):disable()
    pagePanel:getChildById('prevPage'):disable()
    pagePanel:getChildById('nextPage'):enable()
    pagePanel:getChildById('lastPage'):enable()
  else
    pagePanel:getChildById('firstPage'):enable()
    pagePanel:getChildById('prevPage'):enable()
    pagePanel:getChildById('nextPage'):enable()
    pagePanel:getChildById('lastPage'):enable()
  end
end
