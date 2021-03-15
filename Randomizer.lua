function onLoad(save_state)
    self.setLock(true)
    self.interactable = false
  end
  function rando()
    local players = Player.getPlayers()
  
    if #players >= 2 then
      local chess_players = {}
  
      for i,player in ipairs(players) do
        if player.color == 'White' or player.color == 'Green' then
          table.insert(chess_players, player)
          players[i] = nil
        end
      end
      players = compact(players)
  
      while #chess_players < 2 do
        local ri = math.random(#players)
        table.insert(chess_players, players[ri])
        table.remove(players, ri)
      end
      if math.random() < 0.5 then
        chess_players[1].changeColor('White')
        chess_players[2].changeColor('Green')
      else
        chess_players[1].changeColor('Green')
        chess_players[2].changeColor('White')
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
  
  function compact(input)
    local j = 0
    local n = #input
    for i=1,n do
      if input[i] ~= nil then
        j = j + 1
        input[j] = input[i]
      end
    end
    for i=j+1,n do
      input[i] = nil
    end
    return input
  end