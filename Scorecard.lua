local scores = {}

function onLoad(save_state)
  self.setName('Scorecard')
  if save_state and save_state ~= '' then
    scores = JSON.decode(save_state)
    for name,_ in pairs(scores) do
      if not isPlayerHere(name) then scores[name] = nil end
    end
  end
  updateDisplay()
end

function isPlayerHere(name)
  for _,player in ipairs(Player.getPlayers()) do
    if player.steam_name == name then return true end
  end
  return false
end

function onSave()
  return JSON.encode(scores)
end

function tryRandomize()
  for name,_ in pairs(scores) do
    scores[name] = 0
  end
  updateDisplay()
  return false
end

function increment(p)
  local name, ct = p[1], p[2]
  if scores[name] then
    scores[name] = scores[name] + ct
  else
    scores[name] = ct
  end
  updateDisplay()
end

function updateDisplay()
  local items = {}
  for name, score in pairs(scores) do
    table.insert(items, {name, score})
  end
  if #items == 0 then
    self.setDescription('[808080][i]Feel free to delete\nPress R over this to reset[/i][-]')
    return
  end

  local cmp = function(a, b)
    if a[2] ~= b[2] then return a[2] < b[2] end
    return a[1] < b[1]
  end
  table.sort(items, cmp)

  local str = ''
  for _,item in ipairs(items) do
    if item[2] % 1 == 0 then
      str = str .. string.format('[b]%d[/b] - %s\n', item[2], item[1])
    else
      str = str .. string.format('[b]%.1f[/b] - %s\n', item[2], item[1])
    end
  end

  self.setDescription(str)
end