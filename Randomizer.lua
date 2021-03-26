function onLoad(save_state)
  self.setLock(true)
  self.interactable = false
end

function rando(_, option)
  if option ~= '-1' then return end
  local players = Player.getPlayers()

  if #players >= 2 then
    local chess_players = {}

    local n = #players
    for i,player in ipairs(players) do
      if player.color == 'White' or player.color == 'Green' then
        table.insert(chess_players, player)
        players[i] = nil
      end
    end
    compact(players, n)

    while #chess_players < 2 do
      local ri = math.random(#players)
      table.insert(chess_players, players[ri])
      table.remove(players, ri)
    end

    local temp_id = chess_players[1].steam_id
    if math.random() < 0.5 then
      chess_players[1].changeColor('Grey')
      chess_players[2].changeColor('Green')
      local temp = findSpectator(temp_id)
      if temp then temp.changeColor('White') end
    else
      chess_players[1].changeColor('Grey')
      chess_players[2].changeColor('White')
      local temp = findSpectator(temp_id)
      if temp then temp.changeColor('Green') end
    end
  else
    if math.random() < 0.5 then
      players[1].changeColor('White')
    else
      players[1].changeColor('Green')
    end
  end
  broadcastToAll("Done randomizing", {1,1,1})
end

function swap(_, option)
  if option ~= '-1' then return end
  local white_id, green_id

  if Player['White'].seated then
    white_id = Player['White'].steam_id
    Player['White'].changeColor('Grey')
  end
  if Player['Green'].seated then
    green_id = Player['Green'].steam_id
    Player['Green'].changeColor('Grey')
  end

  local orig_white = findSpectator(white_id)
  if orig_white then
    orig_white.changeColor('Green')
  end
  local orig_green = findSpectator(green_id)
  if orig_green then
    orig_green.changeColor('White')
  end

end

function findSpectator(id)
  if not id then return end
  for _,player in ipairs(Player.getSpectators()) do
    if player.steam_id == id then
      return player
    end
  end
end

function compact(input, n)
  local j = 0
  for i=1,n do
    if input[i] ~= nil then
      j = j + 1
      input[j] = input[i]
    end
  end
  for i=j+1,n do
    input[i] = nil
  end
end