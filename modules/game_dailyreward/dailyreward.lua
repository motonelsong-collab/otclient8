-- chunkname: @/modules/game_dailyreward/dailyreward.lua

local DAILY_REWARD_OPCODE = 140

local DAILY_REWARD_ACTIONS = {
  SendRewardsInfo = 1,
  ParseOpenWindow = 2,
  SendClaimReward = 3
}

local REWARD_STATUS_ICONS = {
  check = "/images/game/icons/icon_check",
  missed = "/images/game/icons/button-close.png"
}

local REWARD_STATUS_COLORS = {
  check = "white",
  missed = "#d64545"
}

local DailyRewardWindow
local DailyRewardButton

PlayerDailyRewardConfig = {}

local function resetPlayerDailyRewardConfig()
  PlayerDailyRewardConfig = {
    stack = 0,
    currentDay = 1,
    visualDay = 1,
    hasClaimed = false,
    claimedDays = {},
    rewards = {},
    vipRewards = {},
    rewardMaxStacks = nil
  }
end

local function getRewardDisplayLimit()
  return math.max(#PlayerDailyRewardConfig.rewards, #PlayerDailyRewardConfig.vipRewards, 1)
end

local function isRecurringBonusStage()
  return (tonumber(PlayerDailyRewardConfig.currentDay) or 1) > getRewardDisplayLimit()
end

local function isRewardDayClaimed(day)
  return PlayerDailyRewardConfig.claimedDays[day] == true
end

local function setDailyRewardText(widget, text)
  if not widget then
    return
  end

  if widget.setMultiColorText then
    widget:setMultiColorText(text)
    return
  end

  widget:setText((text or ""):gsub("{#.-|", ""):gsub("}", ""))
end

local function setDailyRewardItem(widget, rewardConfig)
  if not widget then
    return
  end

  if not rewardConfig then
    widget:setItem(nil)
    widget:setItemCount(0)
    return
  end

  local count = tonumber(rewardConfig.count) or 1
  local clientId = tonumber(rewardConfig.clientId) or 0
  local itemId = tonumber(rewardConfig.itemId) or 0

  widget:setItemCount(count)

  if clientId > 0 then
    widget:setItem(nil)
    widget:setItemId(clientId)
    return
  end

  if itemId > 0 then
    local tmpItem = Item.create(itemId, count)
    if tmpItem then
      widget:setItem(tmpItem)
      return
    end

    widget:setItemId(itemId)
    return
  end

  widget:setItem(nil)
  widget:setItemCount(0)
end

local function sanitizeRewardIndex(index)
  index = tonumber(index)
  if not index or index < 1 then
    return nil
  end

  return index
end

local function buildClaimedDaysLookup(days)
  local claimedDays = {}

  for _, day in pairs(days or {}) do
    day = sanitizeRewardIndex(day)
    if day then
      claimedDays[day] = true
    end
  end

  return claimedDays
end

local function buildRewardStackLookup(rewardList)
  local rewards = {}

  for index, config in pairs(rewardList or {}) do
    index = sanitizeRewardIndex(index)
    if index then
      rewards[index] = config
    end
  end

  return rewards
end

local function applyRewardPayload(data)
  resetPlayerDailyRewardConfig()

  PlayerDailyRewardConfig.stack = tonumber(data.stack) or 0
  PlayerDailyRewardConfig.currentDay = math.max(tonumber(data.currentDay) or 1, 1)
  PlayerDailyRewardConfig.claimedDays = buildClaimedDaysLookup(data.claimedDays)
  PlayerDailyRewardConfig.rewards = buildRewardStackLookup(data.rewardStacks)
  PlayerDailyRewardConfig.vipRewards = buildRewardStackLookup(data.vipRewardStacks)
  PlayerDailyRewardConfig.rewardMaxStacks = data.rewardMaxStacks
  PlayerDailyRewardConfig.hasClaimed = tonumber(data.hasClaimed) == 1

  local rewardLimit = math.max(#PlayerDailyRewardConfig.rewards, 1)
  local visualDay = tonumber(data.visualDay) or PlayerDailyRewardConfig.currentDay
  PlayerDailyRewardConfig.visualDay = math.max(1, math.min(visualDay, rewardLimit))
end

local function applyRewardDayState(widget, dayLabel, statusIcon, item, index, isCurrentDay, allowRecurringState)
  local claimed = isRewardDayClaimed(index)
  local recurringBonusDay = allowRecurringState and isCurrentDay and isRecurringBonusStage() and not PlayerDailyRewardConfig.hasClaimed
  local missed = index < PlayerDailyRewardConfig.visualDay and not claimed

  dayLabel:setOn(false)
  dayLabel:setColor("#FFFFFF")
  statusIcon:setVisible(false)
  statusIcon:setImageSource("")
  statusIcon:setImageColor("white")
  item:setOpacity(1)
  widget:setOn(false)

  if claimed then
    dayLabel:setOn(true)
    statusIcon:setVisible(true)
    statusIcon:setImageSource(REWARD_STATUS_ICONS.check)
    statusIcon:setImageColor(REWARD_STATUS_COLORS.check)
    item:setOpacity(0.5)
    return "claimed"
  end

  if recurringBonusDay then
    widget:setOn(true)
    return "recurring"
  end

  if missed then
    statusIcon:setVisible(true)
    statusIcon:setImageSource(REWARD_STATUS_ICONS.missed)
    statusIcon:setImageColor(REWARD_STATUS_COLORS.missed)
    item:setOpacity(0.35)
    return "missed"
  end

  if isCurrentDay then
    widget:setOn(not PlayerDailyRewardConfig.hasClaimed)
    return "current"
  end

  return "future"
end

local function getRewardTooltip(rewardConfig, state, isVip)
  local rewardName = rewardConfig.itemName or "Unknown"
  local rewardText = string.format("%dx %s", tonumber(rewardConfig.count) or 0, rewardName)

  if state == "claimed" then
    return "Voce recebeu\n" .. rewardText
  end

  if state == "missed" then
    return "Recompensa indisponivel\n" .. rewardText
  end

  if state == "recurring" then
    local recurringReward = PlayerDailyRewardConfig.rewardMaxStacks
    if recurringReward and not isVip then
      return string.format(
        "Recompensa recorrente ativa\nUse Claim para receber\n%dx %s",
        tonumber(recurringReward.count) or 0,
        recurringReward.itemName or "Unknown"
      )
    end

    return "Bonus VIP indisponivel apos o dia 21."
  end

  if state == "current" then
    if isVip then
      return "Clique para resgatar bonus VIP\n" .. rewardText
    end

    return "Clique para resgatar\n" .. rewardText
  end

  return "Voce recebera\n" .. rewardText
end

local function populateRewardList(container, rewardList, isVip)
  local rewardLimit = getRewardDisplayLimit()

  for index = 1, rewardLimit do
    local rewardConfig = rewardList[index]

    if rewardConfig then
      local widget = g_ui.createWidget("RewardDay", container)
      local isCurrentDay = index == PlayerDailyRewardConfig.visualDay
      local state = applyRewardDayState(widget, widget.day, widget.statusIcon, widget.item, index, isCurrentDay, not isVip)

      widget.vip:setVisible(isVip)
      widget.day:setText(index)
      setDailyRewardItem(widget.item, rewardConfig)
      widget:setTooltip(getRewardTooltip(rewardConfig, state, isVip))

      if state == "current" then
        widget.onClick = claimReward
      end
    end
  end
end

local function refreshRecurringRewardPanel()
  local rewardMaxStacks = PlayerDailyRewardConfig.rewardMaxStacks
  if not DailyRewardWindow or not rewardMaxStacks then
    return
  end

  local lastDayOfMonth = getLastDayOfMonth()
  local monthName = getMonthString()
  local rewardName = rewardMaxStacks.itemName or "Unknown"
  local rewardCount = tonumber(rewardMaxStacks.count) or 0
  local isRecurringActive = isRecurringBonusStage()

  setDailyRewardItem(DailyRewardWindow.messagePanel.maxStackReward, rewardMaxStacks)

  if isRecurringActive then
    DailyRewardWindow.messagePanel.maxStackReward:setTooltip("Recompensa recorrente\n" .. rewardCount .. "x " .. rewardName)
    setDailyRewardText(
      DailyRewardWindow.messagePanel.messageLabel,
      "Recompensa recorrente ativa.\nVoce recebe {#f3c402|" .. rewardCount .. "x " .. rewardName .. "}\ntodos os dias ate o dia " .. lastDayOfMonth .. " de " .. monthName .. "."
    )
    return
  end

  DailyRewardWindow.messagePanel.maxStackReward:setTooltip("Voce recebera\n" .. rewardCount .. "x " .. rewardName)
  setDailyRewardText(
    DailyRewardWindow.messagePanel.messageLabel,
    "Apos coletar a recompensa #21,\nvoce recebera {#f3c402|" .. rewardCount .. "x " .. rewardName .. "}\ntodos os dias ate o dia " .. lastDayOfMonth .. " de " .. monthName .. "."
  )
end

local function displayRewards()
  if not DailyRewardWindow then
    return
  end

  DailyRewardWindow.rewardsList:destroyChildren()
  DailyRewardWindow.vipRewardsList:destroyChildren()

  populateRewardList(DailyRewardWindow.rewardsList, PlayerDailyRewardConfig.rewards, false)
  populateRewardList(DailyRewardWindow.vipRewardsList, PlayerDailyRewardConfig.vipRewards, true)
  refreshRecurringRewardPanel()
  DailyRewardWindow.claimButton:setEnabled(not PlayerDailyRewardConfig.hasClaimed)

  showWindow()
end

function init()
  resetPlayerDailyRewardConfig()

  connect(g_game, {
    onGameEnd = closeWindow
  })

  DailyRewardButton = modules.client_topmenu.addTopGameToggleButton("dailyrewardButton", tr("Daily Reward"), "/images/topbuttons/icon_daily_gift", toggle, false, 5)
  DailyRewardWindow = g_ui.displayUI("dailyreward")
  if not DailyRewardWindow then
    DailyRewardWindow = g_ui.loadUI("dailyreward", rootWidget)
  end
  if not DailyRewardWindow then
    return
  end

  DailyRewardWindow:setVisible(false)
  ProtocolGame.registerExtendedJSONOpcode(DAILY_REWARD_OPCODE, parseDailyReward)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = closeWindow
  })

  ProtocolGame.unregisterExtendedJSONOpcode(DAILY_REWARD_OPCODE)
  closeWindow()

  if DailyRewardWindow then
    DailyRewardWindow:destroy()
    DailyRewardWindow = nil
  end

  if DailyRewardButton then
    DailyRewardButton:destroy()
    DailyRewardButton = nil
  end

  resetPlayerDailyRewardConfig()
end

function closeWindow()
  if DailyRewardButton then
    DailyRewardButton:setOn(false)
  end

  if DailyRewardWindow then
    DailyRewardWindow:setVisible(false)
  end
end

function showWindow()
  if not DailyRewardWindow then
    return
  end

  DailyRewardWindow:setVisible(true)

  if DailyRewardButton then
    DailyRewardButton:setOn(true)
  end

  DailyRewardWindow:focus()
end

function toggle()
  if not DailyRewardWindow then
    return
  end

  if DailyRewardButton:isOn() then
    closeWindow()
    return
  end

  loadDailyReward()
end

function parseDailyReward(protocol, opcode, jsonData)
  if type(jsonData) ~= "table" or type(jsonData.data) ~= "table" then
    return
  end

  applyRewardPayload(jsonData.data)
  displayRewards()

  if jsonData.action == DAILY_REWARD_ACTIONS.ParseOpenWindow then
    showWindow()
  end
end

function claimReward()
  local protocol = g_game.getProtocolGame()

  if not protocol or PlayerDailyRewardConfig.hasClaimed then
    return
  end

  protocol:sendExtendedOpcode(DAILY_REWARD_OPCODE, tostring(DAILY_REWARD_ACTIONS.SendClaimReward))
  scheduleEvent(loadDailyReward, 150)
end

function loadDailyReward()
  local protocol = g_game.getProtocolGame()

  if not protocol then
    return
  end

  protocol:sendExtendedOpcode(DAILY_REWARD_OPCODE, tostring(DAILY_REWARD_ACTIONS.SendRewardsInfo))
end

function getLastDayOfMonth()
  local currentDate = os.date("*t")
  local year = currentDate.year
  local month = currentDate.month

  return tonumber(os.date("%d", os.time({
    day = 0,
    year = year,
    month = month + 1
  })))
end

function getMonthString()
  local month = tonumber(os.date("%m"))
  local monthNames = {
    "Janeiro",
    "Fevereiro",
    "Marco",
    "Abril",
    "Maio",
    "Junho",
    "Julho",
    "Agosto",
    "Setembro",
    "Outubro",
    "Novembro",
    "Dezembro"
  }

  return monthNames[month]
end
