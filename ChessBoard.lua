INFO = {}
INFO[1] = {
  ['P'] = {height=2.78, wbag_guid='b795f6', bbag_guid='c70db4'},
  ['R'] = {height=2.89, wbag_guid='0a44d3', bbag_guid='b7adf5'},
  ['N'] = {height=3.21, wbag_guid='5d7621', bbag_guid='0dfee7'},
  ['B'] = {height=3.07, wbag_guid='325444', bbag_guid='66240d'},
  ['Q'] = {height=3.41, wbag_guid='b87cbe', bbag_guid='7d6441'},
  ['K'] = {height=3.52, wbag_guid='68baf5', bbag_guid='66aa94'}
}
INFO[2] = {
  ['P'] = {height=2.78, wbag_guid='e3cf91', bbag_guid='f190d1'},
  ['R'] = {height=2.89, wbag_guid='a1352b', bbag_guid='539aa2'},
  ['N'] = {height=3.21, wbag_guid='92aec0', bbag_guid='8833e7'},
  ['B'] = {height=3.07, wbag_guid='faaf0a', bbag_guid='b108d3'},
  ['Q'] = {height=3.41, wbag_guid='e93bb7', bbag_guid='4b1574'},
  ['K'] = {height=3.52, wbag_guid='17ac80', bbag_guid='8da8a3'}
}
game = nil
promo = {}
ZONE_GUID = '1ab955'
SCORECARD_GUID = '82a739'
RANDOMIZER_GUID = '0f3ed5'
RANDOMIZER = nil

-- Buttons 170 width/height, 593 xyoffset

function onLoad(save_state)
  self.setSnapPoints({})
  self.interactable = false
  Turns.enable = true
  Turns.pass_turns = false
  RANDOMIZER = getObjectFromGUID(RANDOMIZER_GUID)

  clearBoard()

  if save_state and save_state ~= '' then
    game = JSON.decode(save_state)
    setup(game.over)

    local check_check = function(player)
      if player.in_check then
        highlightCoord(player.king, "#FF000088")
        if not game.over then
          broadcastToAll('Check!', {1,1,1})
        end
      end
    end
    check_check(game.white)
    check_check(game.black)
    if game.last_move_from then
      highlightCoord(game.last_move_from, "#FFFF0055")
      highlightCoord(game.last_move_to, "#FFFF0055")
    end

    if game.over then
      gameOver(game.over_code, game.over_msg, true)
      if game.over_msg == 'by checkmate' then
        local loser = game.over_code and game.black or game.white
        highlightCoord(loser.king, "#FF000088")
      end
      -- Force these off, for some reason doesn't work in gameOver()
      Wait.frames(function()
        self.UI.setAttribute('white_ctrl', 'active', false)
        self.UI.setAttribute('black_ctrl', 'active', false)
      end, 5)
    elseif game.timed then
      Global.UI.setAttribute('white_timers', 'active', true)
      Global.UI.setAttribute('black_timers', 'active', true)
      updateTimers()
      Wait.time(function()
        game.white.delta_time = Time.time
        game.black.delta_time = game.white.delta_time
        time_live = true
      end, 3)
    end
  else -- Fresh save
    self.UI.setAttribute('main', 'active', true)
    RANDOMIZER.UI.setAttribute('buttons', 'active', true)
  end
end

function clearBoard()
  local del_objs = getObjectFromGUID(ZONE_GUID).getObjects()
  for _,del_obj in ipairs(del_objs) do
    if del_obj ~= self then
      del_obj.destruct()
    end
  end
  for i=1,8 do
    for j=1,8 do
      self.UI.setAttribute(string.format("%d%d", i, j), 'color', '#00000000')
      self.UI.setAttribute(string.format("i%d%d", i, j), 'image', 'empty')
    end
  end
end

function onSave()
  if not game or not game.board then return end

  -- Create a copy with no piece references or specials
  local copy = {}
  for orig_key, orig_value in pairs(game) do
      copy[orig_key] = orig_value
  end
  copy.board = {}
  for i=1,8 do
    copy.board[i] = {{},{},{},{},{},{},{},{}}
  end
  for i,row in ipairs(game.board) do
    for j,sq in ipairs(row) do
      if sq.ptype then
        local copy_sq = copy.board[i][j]
        copy_sq.ptype = sq.ptype
        copy_sq.white = sq.white
        copy_sq.specials = {}
      end
    end
  end

  return JSON.encode(copy)
end

local menu_selected = 'untimed'
local menu_pool, menu_incr = '', ''
local menu_material = 1
function menuClicked(_, button, id)
  if button == '-1' then
    menu_selected = id
  end
end
function menuTimedSwitched(_, on)
  local enable = on == 'True'
  self.UI.setAttribute('pool', 'interactable', enable)
  self.UI.setAttribute('incr', 'interactable', enable)
end
function menuWooden(_, on)
  if on == 'True' then menu_material = 1 end
end
function menuMetallic(_, on)
  if on == 'True' then menu_material = 2 end
end
function menuPoolEdited(_, text) menu_pool = text end
function menuIncrEdited(_, text) menu_incr = text end
function startClicked(player, button, id)
  if button == '-1' then
    if menu_selected == 'untimed' then
      Global.UI.setAttribute('white_timers', 'active', 'false')
      Global.UI.setAttribute('black_timers', 'active', 'false')
      startBoardStatus(menu_material)
      setup()
    elseif menu_selected == 'stopwatched' then
      startBoardStatus(menu_material)
      setup()
      setupTimers()
    else
      local pool, incr = 30, 0
      if menu_pool ~= '' then pool = tonumber(menu_pool) end
      if menu_incr ~= '' then incr = tonumber(menu_incr) end
      if pool and incr and pool > 0 and incr >= 0 then
        startBoardStatus(menu_material)
        setup()
        setupTimers(pool * 60, incr)
      else
        broadcastToColor('Invalid time settings.', player.color, {1,1,1})
      end
    end

  end
end

local resign = {white_resign = false, black_resign = false}
function ctrlResign(player, button)
  local who_str = (player.color == 'White') and 'white_resign' or 'black_resign'
  if button == '-2' and resign[who_str] then
    gameOver(player.color ~= 'White', 'by resignation')
  elseif button == '-1' then
    resign[who_str] = not resign[who_str]
    if resign[who_str] then
      self.UI.setAttribute(who_str, 'colors', '#888888|#888888|#FFFFFF|#FFFFFF')
      self.UI.setAttribute(who_str, 'text', 'Left click to cancel\nRight click to confirm')
    else
      self.UI.setAttribute(who_str, 'colors', '#FFFFFF|#FFFFFF|#888888|#FFFFFF')
      self.UI.setAttribute(who_str, 'text', 'Resign')
    end
  end
end

local draw = {white_draw = false, black_draw = false}
function ctrlDraw(player, on)
  local who_str = (player.color == 'White') and 'white_draw' or 'black_draw'
  local other_str = (player.color == 'White') and 'black_draw' or 'white_draw'
  draw[who_str] = on == 'True'
  if draw[who_str] then
    if draw[other_str] then
      gameOver(nil, 'by agreement')
    else
      local to_player = (player.color == 'White') and 'Green' or 'White'
      if Player[to_player].seated then
        broadcastToColor('Draw offered by opponent', to_player)
      end
      self.UI.setAttribute(who_str, 'text', 'Wating for response')
      self.UI.setAttribute(other_str, 'text', 'Accept draw')
    end
  else
    self.UI.setAttribute(who_str, 'text', 'Offer Draw')
    self.UI.setAttribute(other_str, 'text', 'Offer Draw')
  end
end

local rematch = {white_rematch = false, black_rematch = false}
function ctrlRematch(player, on)
  local who_str = (player.color == 'White') and 'white_rematch' or 'black_rematch'
  local other_str = (player.color == 'White') and 'black_rematch' or 'white_rematch'
  rematch[who_str] = on == 'True'
  if rematch[who_str] and rematch[other_str] then
    clearBoard()
    game = {}
    self.UI.setAttribute('white_rematch', 'active', false)
    self.UI.setAttribute('black_rematch', 'active', false)
    self.UI.setAttribute('white_msg1', 'active', false)
    self.UI.setAttribute('black_msg1', 'active', false)
    self.UI.setAttribute('white_msg2', 'active', false)
    self.UI.setAttribute('black_msg2', 'active', false)
    Global.UI.setAttribute('white_timers', 'active', false)
    Global.UI.setAttribute('black_timers', 'active', false)
    self.UI.setAttribute('main', 'active', true)
    RANDOMIZER.UI.setAttribute('buttons', 'active', true)
  end
end

function ctrlReset()
  resign = {white_resign = false, black_resign = false}
  self.UI.setAttribute('white_resign', 'colors', '#FFFFFF|#FFFFFF|#888888|#FFFFFF')
  self.UI.setAttribute('white_resign', 'text', 'Resign')
  self.UI.setAttribute('black_resign', 'colors', '#FFFFFF|#FFFFFF|#888888|#FFFFFF')
  self.UI.setAttribute('black_resign', 'text', 'Resign')
  draw = {white_draw = false, black_draw = false}
  self.UI.setAttribute('white_draw', 'text', 'Offer Draw')
  self.UI.setAttribute('white_draw', 'isOn', false)
  self.UI.setAttribute('black_draw', 'text', 'Offer Draw')
  self.UI.setAttribute('black_draw', 'isOn', false)
  rematch = {white_rematch = false, black_rematch = false}
  self.UI.setAttribute('white_rematch', 'isOn', false)
  self.UI.setAttribute('black_rematch', 'isOn', false)
end

function startBoardStatus(material)
  game = {}
  game.board = {}
  for i=1,8 do
    game.board[i] = {{},{},{},{},{},{},{},{}}
  end
  game.white_to_move = true
  game.white, game.black = {}, {}
  game.white.castle, game.black.castle = true, true
  game.white.qcastle, game.black.qcastle = true, true
  game.white.in_check, game.black.in_check = false, false
  game.white.king, game.black.king = {1, 5}, {8, 5}
  game.en_passant_coord = nil
  game.last_move_from, game.last_move_to = nil, nil
  game.turn = 1
  game.material = material

  local set_coord = function(coord, ptype, white)
    setSquareAt(coord, {
      ptype = ptype,
      white = white,
      specials = {}
      -- Special fields: move, castle, en passant, double_move
    })
  end

  local set_side = function(white)
    local backRank = white and 1 or 8
    local frontRank = white and 2 or 7

    set_coord({backRank, 1}, 'R', white)
    set_coord({backRank, 2}, 'N', white)
    set_coord({backRank, 3}, 'B', white)
    set_coord({backRank, 4}, 'Q', white)
    set_coord({backRank, 5}, 'K', white)
    set_coord({backRank, 6}, 'B', white)
    set_coord({backRank, 7}, 'N', white)
    set_coord({backRank, 8}, 'R', white)

    for file=1,8 do
      set_coord({frontRank, file}, 'P', white)
    end
  end

  set_side(true)
  set_side(false)
end

BUTTON_SIZE = 840
function setup(freeze_all)
  local setup_square = function(coord, ptype, white)
    local bag_guid = white and 'wbag_guid' or 'bbag_guid'
    getObjectFromGUID(INFO[game.material][ptype][bag_guid]).takeObject({
      position = coordToPos(coord, ptype),
      rotation = {0, white and 180 or 0, 0},
      smooth = false,
      callback_function = function(p)
        p.interactable = (game.white_to_move == white) and not freeze_all
        squareAt(coord).piece = p
        p.setVar('chesspiece', true)
      end
    })
  end

  self.clearButtons()
  local pos = 5.92
  local step = -pos / 3.5
  for i=0,7 do
    for j=0,7 do
      local func_string = string.format('click%d%d', i + 1, j + 1)
      _G[func_string] = function(_, color, alt) click({i + 1, j + 1}, color, alt) end
      self.createButton({
        click_function = func_string,
        function_owner = self,
        position = {pos+step*j,0,-pos-step*i},
        width = 0, height = 0,
        color={0,0,0,0}
      })
    end
  end

  -- local xml_table = self.UI.getXmlTable()
  -- local START, STOP = -592, 592
  -- local step = (STOP - START) / 7.0
  -- for i=1,8 do
  --   for j=1,8 do
  --     table.insert(xml_table, {
  --       tag = 'Image',
  --       attributes = {
  --         id = string.format("i%d%d", i, j),
  --         width = step, height = step,
  --         offsetXY = string.format("%f %f",
  --           START + (j - 1) * step,
  --           START + (i - 1) * step
  --         ),
  --         color = "#00000000",
  --         image = 'circle'
  --       }
  --     })
  --   end
  -- end
  -- self.UI.setXmlTable(xml_table)
  -- Wait.frames(function() log(self.UI.getXml()) end, 10)
  -- table.insert(xml_table, {
  --   tag = 'Button',
  --   attributes = {
  --     id = string.format("%d%d", i, j),
  --     active = false,
  --     width = step, height = step,
  --     offsetXY = string.format("%f %f",
  --       START + (j - 1) * step,
  --       START + (i - 1) * step
  --     ),
  --     icon = 'circle',
  --     color = '#00000000',
  --     onClick = 'buttonClicked',
  --     onMouseEnter = 'buttonEntered',
  --     onMouseExit = 'buttonExited'
  --   }
  -- })

  for i=1,8 do
    for j=1,8 do
      local coord = {i, j}
      local sq = squareAt(coord)
      if sq.ptype then
        setup_square(coord, sq.ptype, sq.white)
      end
    end
  end

  local w_player, b_player = Player['White'], Player['Green']
  local scorecard = getObjectFromGUID(SCORECARD_GUID)
  if scorecard and not scorecard.isDestroyed() then
    if w_player.seated then scorecard.call('increment', {w_player.steam_name, 0}) end
    if b_player.seated then scorecard.call('increment', {b_player.steam_name, 0}) end
  end

  Wait.frames(function()
    self.UI.setAttribute('main', 'active', false)
    RANDOMIZER.UI.setAttribute('buttons', 'active', false)
    self.UI.setAttribute('white_ctrl', 'active', true)
    self.UI.setAttribute('black_ctrl', 'active', true)
    ctrlReset()
  end, 2)
  Turns.turn_color = game.white_to_move and 'White' or 'Green'
end

local active = nil
local first_pickup = false
local forced_drop = nil
function onObjectPickUp(player_color, picked_up_object)
  if not game then return end
  local promo_type = picked_up_object.getVar('promo_selection')
  if not promo_type and not picked_up_object.getVar('chesspiece') then return end

  local cur_color = game.white_to_move and 'White' or 'Green'
  if player_color ~= cur_color then
    broadcastToColor('It is not your turn.', player_color)
    picked_up_object.setVelocity({0,0,0})
    picked_up_object.setAngularVelocity({0,0,0})
    picked_up_object.drop()
    forced_drop = picked_up_object.getGUID()
    return
  end

  local player = Player[player_color]
  if #player.getHoldingObjects() > 1 or #player.getSelectedObjects() > 1 then
    for _,obj in ipairs(Player[player_color].getHoldingObjects()) do
      obj.setVelocity({0,0,0})
      obj.drop()
    end
    broadcastToColor("Please don't do that. Rewind time to fix any issues that may have occurred.", player_color)
    return
  end

  if promo_type then
    for _,obj in ipairs(promo.selections) do
      obj.destruct()
    end

    squareAt(promo.pawn_coord).piece.destruct()
    local pos = coordToPos(promo.pawn_coord, promo_type)
    local bag = getObjectFromGUID(INFO[game.material][promo_type][game.white_to_move and 'wbag_guid' or 'bbag_guid'])
    local promoted_piece = bag.takeObject({position = pos, smooth = false,
      callback_function = function(p)
        p.setVar('chesspiece', true)
        squareAt(promo.pawn_coord).piece = p
        squareAt(promo.pawn_coord).ptype = promo_type
        promo.pawn_coord = nil
        promo.selections = {}
        passTurn()
      end})
    return
  end

  local coord = posToCoord(picked_up_object.getPosition())
  if not coord then return end
  local square = squareAt(coord)

  if square and square.piece and (square.white == game.white_to_move) then
    if coordEquals(coord, active) then return end
    clearPreviews()
    first_pickup = true
    active = coord
    picked_up_object.use_gravity = false
    showMoves(coord)
  end
end

function click(coord, player_color, alt)
  if not alt
      and ((game.white_to_move and 'White' or 'Green') == player_color) -- DEBUG
      then
    local click_specials = squareAt(coord).specials
    clearPreviews()
    moveTo(coord, click_specials)
  end
end

function raisePieceAt(coord)
  local sq = squareAt(coord)
  sq.piece.setVelocity({0,0,0})
  sq.piece.setAngularVelocity({0,0,0})
  sq.piece.setPositionSmooth(coordToPos(coord, sq.ptype, true), false, true)
end

function onObjectDrop(player_color, dropped_object)
  if forced_drop and forced_drop == dropped_object.getGUID() then
    forced_drop = nil
    return
  end
  if not active or not game then return end
  if not dropped_object.getVar('chesspiece') then return end

  if (game.white_to_move and 'White' or 'Green') ~= player_color then return false end
  local active_sq = squareAt(active)

  if active_sq.piece == dropped_object then
    local coord = posToCoord(dropped_object.getPosition())
    local drop_sq = coord and squareAt(coord)

    if not coord then -- Outside the chessboard
      raisePieceAt(active)
    elseif drop_sq.specials and drop_sq.specials.move then
      local drop_specials = drop_sq.specials -- Preserves info cleared by clearPreviews()
      clearPreviews()
      moveTo(coord, drop_specials)
    elseif coordEquals(coord, active) then
      if first_pickup then
        raisePieceAt(active)
      else -- Clicked again to unselect piece
        clearPreviews()
        dropped_object.use_gravity = true
        active = nil
      end
    else -- Attempted to drop at some random invalid square
      raisePieceAt(active)
    end
  end
  first_pickup = false
end

function moveTo(dest, dest_specials)
  local src_square = squareAt(active)
  local dest_square = squareAt(dest)
  if not dest_specials then dest_specials = {} end
  local cur_player = game.white_to_move and game.white or game.black

  if dest_square.piece then
    dest_square.piece.destruct()
  end
  src_square.piece.setAngularVelocity({0,0,0})
  src_square.piece.setVelocity({0,0,0})
  src_square.piece.setPositionSmooth(
    coordToPos(dest, src_square.ptype),
  false, true)
  src_square.piece.use_gravity = true

  -- Handle en passant and remember double moves for en passant
  local pawn_move = game.white_to_move and 1 or -1
  local assigned_ep = false
  if src_square.ptype == 'P' then
    if dest_specials.double_move then
      game.en_passant_coord = {dest[1] - pawn_move, dest[2]}
      assigned_ep = true
    elseif dest_specials.en_passant then
      squareAt({dest[1] - pawn_move, dest[2]}).piece.destruct()
      setSquareAt({dest[1] - pawn_move, dest[2]}, {})
    end
  end
  if not assigned_ep then game.en_passant_coord = nil end

  if src_square.ptype == 'K' then
    cur_player.king = dest

    if dest_specials.castle then
      local rook_file_src, rook_file_dest
      if dest[2] == 7 then
        rook_src, rook_dest = {dest[1], 8}, {dest[1], 6}
      else
        rook_src, rook_dest = {dest[1], 1}, {dest[1], 4}
      end
      squareAt(rook_src).piece.setPositionSmooth(
        coordToPos(rook_dest, 'R'),
      false, true)
      setSquareAt(rook_dest, squareAt(rook_src));
      setSquareAt(rook_src, {})
    end
    cur_player.castle, cur_player.qcastle = false, false
  end

  -- First rook move, invalidate castling on that side
  if src_square.ptype == 'R' then
    local r_rank = game.white_to_move and 1 or 8
    if cur_player.castle and coordEquals(active, {r_rank, 8}) then
      cur_player.castle = false
    elseif cur_player.qcastle and coordEquals(active, {r_rank, 1}) then
      cur_player.qcastle = false
    end
  end
  -- Rook captured, invalidate castling for opponent on that side
  if dest_square.ptype == 'R' then
    local r_rank = game.white_to_move and 8 or 1
    local opp_player = game.white_to_move and game.black or game.white
    if opp_player.castle and coordEquals(dest, {r_rank, 8}) then
      opp_player.castle = false
    elseif opp_player.qcastle and coordEquals(dest, {r_rank, 1}) then
      opp_player.qcastle = false
    end
  end

  setSquareAt(dest, src_square)
  setSquareAt(active, {})

  -- Clear red check highlight
  highlightCoord(cur_player.king, "#00000000")
  -- Clear previous move highlights
  local from, to = game.last_move_from, game.last_move_to
  if from and to then
    highlightCoord(from, "#00000000")
    highlightCoord(to, "#00000000")
  end
  game.last_move_from = active
  game.last_move_to = dest

  -- Pawn promotion
  if src_square.ptype == 'P' and dest[1] == (game.white_to_move and 8 or 1) then
    for i=1,8 do
      for j=1,8 do
        local sq = squareAt({i, j})
        if sq.piece then
          sq.piece.interactable = false
        end
      end
    end

    local bag_guid_field = game.white_to_move and 'wbag_guid' or 'bbag_guid'
    local ptypes = {'Q', 'N', 'R', 'B'}
    promo.selections = {}
    promo.pawn_coord = dest
    local callback = function(obj, ptype)
      obj.setColorTint({1,1,1,0.4})
      obj.use_gravity = false
      obj.setVar('promo_selection', ptype)
      table.insert(promo.selections, obj)
    end
    for i=1,4 do
      local bag = getObjectFromGUID(INFO[game.material][ptypes[i]][bag_guid_field])
      local j = game.white_to_move and i or -i
      local k = game.white_to_move and 1 or -1
      local pos = coordToPos({dest[1] + pawn_move, dest[2] + j - k}, ptypes[i])
      bag.takeObject({position = pos, smooth = false,
          callback_function = function(obj) callback(obj, ptypes[i]) end})
    end
  else
    passTurn()
  end
end

function passTurn()
  active = nil

  local next_player = game.white_to_move and game.black or game.white
  local next_is_white = not game.white_to_move

  local game_over_code, msg
  game.white.in_check, game.black.in_check = false, false
  if isCheck(next_is_white) then
    highlightCoord(next_player.king, "#FF000088")
    next_player.in_check = true
    if not hasMoves(next_is_white) then
      local winner = next_is_white and 'Black' or 'White'
      msg = 'by checkmate'
      game_over_code = not next_is_white
    else
      broadcastToAll('Check!', {1,1,1})
    end
  else
    if not hasMoves(next_is_white) then
      msg = 'by stalemate'
    end
  end

  highlightCoord(game.last_move_from, "#FFFF0055")
  highlightCoord(game.last_move_to, "#FFFF0055")

  if msg then
    gameOver(game_over_code, msg)
  else
    if game.timed and game.increment and game.turn >= 2 then
      local time_getter = game.white_to_move and game.white or game.black
      time_getter.timer = time_getter.timer + game.increment
      updateTimers(game.white_to_move)
    end

    game.white_to_move = next_is_white
    next_player.delta_time = Time.time
    Turns.turn_color = game.white_to_move and "White" or "Green"

    for i=1,8 do
      for j=1,8 do
        local sq = squareAt({i, j})
        if sq.piece then
          sq.piece.interactable = sq.white == game.white_to_move
        end
      end
    end

    if next_is_white then
      game.turn = game.turn + 1
      if game.timed and game.turn == 2 then
        time_live = true
      end
    end
  end
end

local scan = {}
-- Returns whether there is a piece at COORD matching the player indicated
-- by WHITE, with ptype matching any in PTYPES (default: all)
function scan:match(coord, white, ptypes)
  local square
  if self.changes
      and self.changes[coord[1]]
      and self.changes[coord[1]][coord[2]] then
    square = self.changes[coord[1]][coord[2]]
  else
    square = squareAt(coord)
  end
  if white == nil then white = game.white_to_move end
  if not square or not square.piece then return false end
  return square.white == white
    and (not ptypes or ptypes[square.ptype])
end
function scan:empty(coord)
  local square
  if self.changes
      and self.changes[coord[1]]
      and self.changes[coord[1]][coord[2]] then
    square = self.changes[coord[1]][coord[2]]
  else
    square = squareAt(coord)
  end
  return square and square.piece == nil
end

local move_previews = {}
local capture_previews = {}
function showMoves(coord)
  local moves, captures, castles, double_move, en_passant =
    _G['moves_'..squareAt(coord).ptype](coord)
  for _,move in ipairs(moves) do
    previewMove(coord, move)
  end
  for _,capture in ipairs(captures) do
    previewCapture(coord, capture)
  end

  if double_move then
    previewMove(coord, double_move)
    squareAt(double_move).specials.double_move = true
  elseif en_passant then
    previewMove(coord, en_passant)
    squareAt(en_passant).specials.en_passant = true
  end

  if castles then
    for _,castle_move in ipairs(castles) do
      previewMove(coord, castle_move)
      squareAt(castle_move).specials.castle = true
    end
  end
end

function clearPreviews()
  if active then
    squareAt(active).piece.setVelocity({0,0,0})
    squareAt(active).piece.use_gravity = true
    squareAt(active).piece.setPositionSmooth(coordToPos(active, squareAt(active).ptype), false, true)
  end
  for _,coord in ipairs(move_previews) do
    local square = squareAt(coord)
    local id = string.format('i%d%d', coord[1], coord[2])
    self.UI.setAttribute(id, 'image', 'empty')
    setButtonEnabled(coord, false)
    square.specials = {}
  end
  move_previews = {}
  for _,coord in ipairs(capture_previews) do
    local square = squareAt(coord)
    local id = string.format('i%d%d', coord[1], coord[2])
    self.UI.setAttribute(id, 'image', 'empty')
    setButtonEnabled(coord, false)
    square.specials = {}
  end
  capture_previews = {}
end

-- Check that MOVE is valid; if so, put in LIST, or return true if STOP flag on
function enter(from_coord, to_coord, list, stop)
  if validateMove(from_coord, to_coord) then
    if stop then
      return true
    else
      table.insert(list, to_coord)
    end
  end
end

function moves_P(coord, stop)
  local rank, file = coord[1], coord[2]
  local step = squareAt(coord).white and 1 or -1
  local start = squareAt(coord).white and 2 or 7
  local moves, captures = {}, {}
  local double_move, en_passant
  local move

  -- One step up
  move = {rank + step, file}
  if scan:empty(move) then
    if enter(coord, move, moves, stop) then return end
    -- First double move
    move = {rank + 2*step, file}
    if rank == start and scan:empty(move) then
      if validateMove(coord, move) then
        if stop then return end
        double_move = move
      end
    end
  end

  -- Diagonal captures
  move = {rank + step, file + 1}
  if scan:match(move, not squareAt(coord).white) then
    if enter(coord, move, captures, stop) then return end
  elseif coordEquals(move, game.en_passant_coord) and validateMove(coord, move, nil, true) then
    en_passant = move
  end
  move = {rank + step, file - 1}
  if scan:match(move, not squareAt(coord).white) then
    if enter(coord, move, captures, stop) then return end
  elseif coordEquals(move, game.en_passant_coord) and validateMove(coord, move, nil, true) then
    en_passant = move
  end

  return moves, captures, nil, double_move, en_passant
end

function movesAcrossLine(coord, step_i, step_j, moves, captures, stop)
  local rank, file = coord[1], coord[2]
  local i, j = step_i, step_j
  while true do
    local move = {rank + i, file + j}
    if scan:empty(move) then
      if enter(coord, move, moves, stop) then return true end
      i, j = i + step_i, j + step_j
    elseif scan:match(move, not squareAt(coord).white) then
      if enter(coord, move, captures, stop) then return true end
      break
    else
      break
    end
  end
end

function moves_B(coord, stop)
  local moves, captures = {}, {}
  if movesAcrossLine(coord, 1, 1, moves, captures, stop) then return end
  if movesAcrossLine(coord, 1, -1, moves, captures, stop) then return end
  if movesAcrossLine(coord, -1, 1, moves, captures, stop) then return end
  if movesAcrossLine(coord, -1, -1, moves, captures, stop) then return end
  return moves, captures
end

function moves_R(coord, stop)
  local moves, captures = {}, {}
  if movesAcrossLine(coord, 0, 1, moves, captures, stop) then return end
  if movesAcrossLine(coord, 0, -1, moves, captures, stop) then return end
  if movesAcrossLine(coord, 1, 0, moves, captures, stop) then return end
  if movesAcrossLine(coord, -1, 0, moves, captures, stop) then return end
  return moves, captures
end

function moves_Q(coord, stop)
  local moves, captures = {}, {}
  if movesAcrossLine(coord, 1, 1, moves, captures, stop) then return end
  if movesAcrossLine(coord, 1, -1, moves, captures, stop) then return end
  if movesAcrossLine(coord, -1, 1, moves, captures, stop) then return end
  if movesAcrossLine(coord, -1, -1, moves, captures, stop) then return end
  if movesAcrossLine(coord, 0, 1, moves, captures, stop) then return end
  if movesAcrossLine(coord, 0, -1, moves, captures, stop) then return end
  if movesAcrossLine(coord, 1, 0, moves, captures, stop) then return end
  if movesAcrossLine(coord, -1, 0, moves, captures, stop) then return end
  return moves, captures
end

function moves_N(coord, stop)
  local candidates, moves, captures = {}, {}, {}
  local rank, file = coord[1], coord[2]
  table.insert(candidates, {rank + 1, file + 2})
  table.insert(candidates, {rank + 2, file + 1})
  table.insert(candidates, {rank - 1, file + 2})
  table.insert(candidates, {rank - 2, file + 1})
  table.insert(candidates, {rank + 1, file - 2})
  table.insert(candidates, {rank + 2, file - 1})
  table.insert(candidates, {rank - 1, file - 2})
  table.insert(candidates, {rank - 2, file - 1})

  for _,move in ipairs(candidates) do
    if scan:empty(move) then
      if enter(coord, move, moves, stop) then return end
    elseif scan:match(move, not squareAt(coord).white) then
      if enter(coord, move, captures, stop) then return end
    end
  end
  return moves, captures
end

function moves_K(coord, stop)
  local candidates, moves, captures, castles = {}, {}, {}, {}
  local rank, file = coord[1], coord[2]
  table.insert(candidates, {rank + 1, file})
  table.insert(candidates, {rank - 1, file})
  table.insert(candidates, {rank, file + 1})
  table.insert(candidates, {rank, file - 1})

  table.insert(candidates, {rank + 1, file - 1})
  table.insert(candidates, {rank - 1, file + 1})
  table.insert(candidates, {rank - 1, file - 1})
  table.insert(candidates, {rank + 1, file + 1})

  for _,move in ipairs(candidates) do
    if scan:empty(move) then
      if enter(coord, move, moves, stop) then return end
    elseif scan:match(move, not squareAt(coord).white) then
      if enter(coord, move, captures, stop) then return end
    end
  end

  local castles = {}
  local cur_player = squareAt(coord).white and game.white or game.black

  if not cur_player.in_check then
    if cur_player.castle
        and scan:empty({rank, 6})
        and scan:empty({rank, 7}) then
      if validateMove(coord, {rank, 7}, true) then
        table.insert(castles, {rank, 7})
      end
    end
    if cur_player.qcastle
        and scan:empty({rank, 2})
        and scan:empty({rank, 3})
        and scan:empty({rank, 4}) then
      if validateMove(coord, {rank, 3}, true) then
        table.insert(castles, {rank, 3})
      end
    end
  end

  return moves, captures, castles
end

function validateMove(from_coord, to_coord, castle, en_passant)
  -- Check that castle-skipped square is not attacked
  if castle then
    local dir = (from_coord[2] < to_coord[2]) and 1 or -1
    if not validateMove(from_coord, {from_coord[1], from_coord[2] + dir}) then
      return false
    end
  end
  local changes = {}

  local from_square = squareAt(from_coord)
  changes[to_coord[1]] = {}
  changes[to_coord[1]][to_coord[2]] = from_square

  if not changes[from_coord[1]] then
    changes[from_coord[1]] = {}
  end
  changes[from_coord[1]][from_coord[2]] = {}

  if en_passant then -- Rare situation where e.p. causes self-check
    changes[from_coord[1]][to_coord[2]] = {}
  end

  if from_square.ptype == 'K' then
    if from_square.white then
      changes.white_king = {to_coord[1], to_coord[2]}
    else
      changes.black_king = {to_coord[1], to_coord[2]}
    end
  end

  scan.changes = changes
  local is_into_check = isCheck(from_square.white)
  scan.changes = nil

  return not is_into_check
end

function previewMove(from_coord, to_coord)
  local ptype = squareAt(from_coord).ptype
  local pos = coordToPos(to_coord, ptype)
  local white = squareAt(from_coord).white

  local id = string.format('i%d%d', to_coord[1], to_coord[2])
  self.UI.setAttribute(id, 'image', 'circle')
  setButtonEnabled(to_coord, true)
  squareAt(to_coord).specials = {move=true}
  table.insert(move_previews, to_coord)
end

function previewCapture(from_coord, to_coord)
  local target = squareAt(to_coord)
  local id = string.format('i%d%d', to_coord[1], to_coord[2])
  self.UI.setAttribute(id, 'image', 'capture')
  setButtonEnabled(to_coord, true)
  target.specials.move = true
  table.insert(capture_previews, to_coord)
end

local knight_set = {N=true}
local pawn_set = {P=true, Q=true, B=true, K=true}
local diag_set, k_diag_set = {B=true, Q=true}, {B=true, Q=true, K=true}
local ortho_set, k_ortho_set = {R=true, Q=true}, {R=true, Q=true, K=true}

function isCheck(white)
  local king = (white and game.white or game.black).king
  if scan.changes then
    local changed_king = white and scan.changes.white_king or scan.changes.black_king
    if changed_king then king = changed_king end
  end
  local enemy = not white
  local r, f = king[1], king[2]

  -- Look at surrounding 3x3, king included for validateMove()
  local p_rank = (white and 1 or -1)
  if scan:match({r + p_rank, f + 1}, enemy, pawn_set) then return true end
  if scan:match({r + p_rank, f - 1}, enemy, pawn_set) then return true end
  if scan:match({r - p_rank, f + 1}, enemy, k_diag_set) then return true end
  if scan:match({r - p_rank, f - 1}, enemy, k_diag_set) then return true end
  if scan:match({r + 1, f}, enemy, k_ortho_set) then return true end
  if scan:match({r - 1, f}, enemy, k_ortho_set) then return true end
  if scan:match({r, f + 1}, enemy, k_ortho_set) then return true end
  if scan:match({r, f - 1}, enemy, k_ortho_set) then return true end

  -- Look across a line for certain pieces
  local look_line = function(step_i, step_j, ptypes)
    local i, j = step_i, step_j
    while true do
      local coord = {r + i, f + j}
      if scan:empty(coord) then
        i, j = i + step_i, j + step_j
      elseif scan:match(coord, enemy, ptypes) then
        return true
      else
        break
      end
    end
    return false
  end

  if scan:match({r + 1, f + 2}, enemy, knight_set) then return true end
  if scan:match({r + 2, f + 1}, enemy, knight_set) then return true end
  if scan:match({r + 1, f - 2}, enemy, knight_set) then return true end
  if scan:match({r + 2, f - 1}, enemy, knight_set) then return true end
  if scan:match({r - 1, f + 2}, enemy, knight_set) then return true end
  if scan:match({r - 2, f + 1}, enemy, knight_set) then return true end
  if scan:match({r - 1, f - 2}, enemy, knight_set) then return true end
  if scan:match({r - 2, f - 1}, enemy, knight_set) then return true end

  return
    look_line(1, 1, diag_set)
    or look_line(1, -1, diag_set)
    or look_line(-1, 1, diag_set)
    or look_line(-1, -1, diag_set)

    or look_line(1, 0, ortho_set)
    or look_line(0, 1, ortho_set)
    or look_line(-1, 0, ortho_set)
    or look_line(0, -1, ortho_set)
end

function hasMoves(white)
  local start, stop, step
  if white then
    start, stop, step = 1, 8, 1
  else
    start, stop, step = 8, 1, -1
  end
  for i=start,stop,step do
    for j=start,stop,step do
      local coord = {i, j}
      local sq = squareAt(coord)
      if sq.ptype
          and sq.white == white
          and _G['moves_' .. sq.ptype](coord, true) == nil then
        return true
      end
    end
  end
  return false
end

function gameOver(code, msg, no_increment)
  time_live = false
  game.over = true
  game.over_code = code
  game.over_msg = msg
  clearPreviews()
  for i=1,8 do
    for j=1,8 do
      local sq = squareAt({i, j})
      if sq.piece then
        sq.piece.drop()
        sq.piece.interactable = false
        sq.piece.use_gravity = true
      end
    end
  end
  local msg1 = 'Draw'
  local color = {0.5,0.5,0.5}
  local color_hex = '#888888'
  if code ~= nil then
    msg1 = (code and 'White' or 'Black') .. ' wins'
    color = code and {1,1,1} or {0,0,0}
    color_hex = code and '#FFFFFF' or '#000000'
  end
  broadcastToAll(msg1 .. '\n' .. msg, color)
  self.UI.setAttribute('white_ctrl', 'active', false)
  self.UI.setAttribute('black_ctrl', 'active', false)
  self.UI.setAttribute('white_rematch', 'active', true)
  self.UI.setAttribute('black_rematch', 'active', true)

  self.UI.setAttributes('white_msg1', {
    active=true, text=msg1, color=color_hex
  })
  self.UI.setAttributes('white_msg2', {
    active=true, text=msg, color=color_hex
  })
  self.UI.setAttributes('black_msg1', {
    active=true, text=msg1, color=color_hex
  })
  self.UI.setAttributes('black_msg2', {
    active=true, text=msg, color=color_hex
  })
  ctrlReset()

  if not no_increment then
    local scorecard = getObjectFromGUID('82a739')
    if not scorecard or scorecard.isDestroyed() then return end

    local w_player, b_player = Player['White'], Player['Green']
    if code ~= nil then
      if code == true then
        if w_player.seated then scorecard.call('increment', {w_player.steam_name, 1}) end
        if b_player.seated then scorecard.call('increment', {b_player.steam_name, 0}) end
      else
        if w_player.seated then scorecard.call('increment', {w_player.steam_name, 0}) end
        if b_player.seated then scorecard.call('increment', {b_player.steam_name, 1}) end
      end
    else
      if w_player.seated then scorecard.call('increment', {w_player.steam_name, 0.5}) end
      if b_player.seated then scorecard.call('increment', {b_player.steam_name, 0.5}) end
    end
  end
end

--------------------------------
-- Timers
--------------------------------

function setupTimers(time, incr)
  if time then
    game.white.timer = time
    game.black.timer = time
    game.increment = incr
  else
    game.white.timer = 0
    game.black.timer = 0
    game.stopwatched = true
  end

  Wait.frames(function()
    Global.UI.setAttribute('white_timers', 'active', true)
    Global.UI.setAttribute('black_timers', 'active', true)
    updateTimers()
    game.timed = true
  end, 5)
end

ticker = 0
INTERVAL = 4
time_live = false
function onUpdate()
  if time_live then
    ticker = ticker + 1
    if ticker == INTERVAL then
      local player = game.white_to_move and game.white or game.black
      local new_time = Time.time
      if game.stopwatched then
        player.timer = player.timer + (new_time - player.delta_time);
      else
        player.timer = player.timer - (new_time - player.delta_time);
        if player.timer < 0 then
          player.timer = 0
          updateTimers(game.white_to_move)
          gameOver(not game.white_to_move, 'by timeout')
        end
      end
      player.delta_time = new_time
      updateTimers(game.white_to_move)
      ticker = 0
    end
  end
end

function updateTimers(white)
  if white == nil then
    updateTimers(true)
    updateTimers(false)
    return
  end
  local str = white and 'white' or 'black'
  local player = white and game.white or game.black
  if player.timer > 20 then
    local minute = math.floor(player.timer / 60)
    local second = player.timer % 60
    Global.UI.setAttribute(str .. '_as_self', 'text', string.format('%02d:%02d', minute, second))
    Global.UI.setAttribute(str .. '_as_opp', 'text', string.format('%02d:%02d', minute, second))
  else
    local num = string.format('%.1f', player.timer)
    if num == '0.0' and player.timer ~= 0 then
      num = '0.1'
    end
    Global.UI.setAttribute(str .. '_as_self', 'text', num)
    Global.UI.setAttribute(str .. '_as_opp', 'text', num)
  end
end

--------------------------------
-- Stuff
--------------------------------

local min_x = -6.8
local max_x = 6.8
local min_z = -6.8
local max_z = 6.8
local chars = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'}
function posToCoord(position)
  local pos = self.positionToLocal(position)
  local file, rank
  if pos.x >= min_x and pos.x <= max_x then
    local step = (max_x - min_x) / 8
    file = math.ceil((pos.x - min_x) / step)
  else
    return nil
  end

  if pos.z >= min_z and pos.z <= max_z then
    local step = (max_z - min_z) / 8
    rank = math.ceil((pos.z - min_z) / step)
  else
    return nil
  end

  return {rank, file}
end

local pos_start = 5.95
local pos_step = pos_start * 2 / 7.0
function coordToPos(coord, ptype, raise)
  local x = -pos_start + pos_step * (coord[2] - 1)
  local z = -pos_start + pos_step * (coord[1] - 1)
  return {x, INFO[game.material][ptype].height + (raise and 1 or 0), z}
end
function coordEquals(a, b)
  if not a then return not b end
  if not b then return false end
  return a[1] == b[1] and a[2] == b[2]
end

function squareAt(coord)
  if not game.board[coord[1]] then return end
  return game.board[coord[1]][coord[2]]
end
function setSquareAt(coord, val)
  game.board[coord[1]][coord[2]] = val
end

function highlightCoord(coord, color)
  self.UI.setAttribute(
    string.format("%d%d", coord[1], coord[2]),
    "color", color
  )
end

function setButtonEnabled(coord, enable)
  local index = (coord[1] - 1) * 8 + coord[2] - 1
  local size = enable and BUTTON_SIZE or 0
  self.editButton({
    index = index,
    width = size, height = size
  })
end

function debug_printBoard()
  if not game or not game.board then
    log('None')
    return
  end
  local str = ''
  for i=8,1,-1 do
    for _,square in ipairs(game.board[i]) do
      if square.piece == nil then
        str = str .. '.'
      elseif square.ptype then
        if square.white then
          str = str .. square.ptype
        else
          str = str .. square.ptype:lower()
        end
      end
    end
    str = str .. '\n'
  end
  log(str)
end

function onScriptingButtonUp(index, player_color)
  debug_printBoard()
end