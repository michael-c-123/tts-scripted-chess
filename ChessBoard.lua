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

    printToAll(toPGN())

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

  -- Create a copy with no piece references
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
        copy_sq.moves = {}
      end
    end
  end

  copy.white, copy.black = {}, {}
  for orig_key, orig_value in pairs(game.white) do
    copy.white[orig_key] = orig_value
  end
  for orig_key, orig_value in pairs(game.black) do
    copy.black[orig_key] = orig_value
  end

  copy.white.graveyard, copy.black.graveyard = {}, {}
  for _,item in ipairs(game.white.graveyard) do
    local to_insert = {ptype = item.ptype}
    table.insert(copy.white.graveyard, to_insert)
  end
  for _,item in ipairs(game.black.graveyard) do
    local to_insert = {ptype = item.ptype}
    table.insert(copy.black.graveyard, to_insert)
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
  game.white.graveyard, game.black.graveyard = {}, {}
  game.en_passant_coord = nil
  game.last_move_from, game.last_move_to = nil, nil
  game.turn = 1
  game.history = {}
  game.material = material

  local set_coord = function(coord, ptype, white)
    setSquareAt(coord, {
      ptype = ptype, -- which piece is on this square
      white = white,  -- whether or not the piece at this square is white
      moves = {}, -- a list of Moves available to this square's piece
      -- trigger_move indicates what Move is triggered when clicking this square
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
      position = coordToPos(coord),
      rotation = {0, white and 180 or 0, 0},
      smooth = false,
      callback_function = function(p)
        p.interactable = (game.white_to_move == white) and not freeze_all
        squareAt(coord).piece = p
        p.setVar('chesspiece', true)
        p.setPosition(coordToPos(coord, p))
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
  generateMoves(game.white_to_move)
  Turns.turn_color = game.white_to_move and 'White' or 'Green'
end

function onPlayerAction(player, action, targets)
  if action == Player.Action.PickUp then
    if #targets > 1 then return false end
    local cur_color = game.white_to_move and 'White' or 'Green'
    if player.color ~= cur_color then
      broadcastToColor('It is not your turn.', player.color)
      return false
    end
  end
  if action == Player.Action.Group then
    return false
  end
  return true
end

local active = nil
local first_pickup = false
local forced_drop = nil
function onObjectPickUp(player_color, picked_up_object)
  if not game then return end
  local promo_type = picked_up_object.getVar('promo_selection')
  if not promo_type and not picked_up_object.getVar('chesspiece') then return end

  if promo_type then
    for _,obj in ipairs(promo.selections) do
      obj.destruct()
    end

    local pawn_coord = promo.move.dest
    squareAt(pawn_coord).piece.destruct()
    local pos = coordToPos(pawn_coord)
    local bag = getObjectFromGUID(INFO[game.material][promo_type][game.white_to_move and 'wbag_guid' or 'bbag_guid'])
    local promoted_piece = bag.takeObject({position = pos, smooth = false,
      callback_function = function(p)
        p.setVar('chesspiece', true)
        p.setPosition(coordToPos(pawn_coord, p))
        squareAt(pawn_coord).piece = p
        squareAt(pawn_coord).ptype = promo_type
        local move_to_send = promo.move
        move_to_send.special = promo_type
        promo.move = nil
        promo.selections = {}
        passTurn(move_to_send)
      end})
    return
  end

  local coord = posToCoord(picked_up_object.getPosition())
  if not coord then return end
  local square = squareAt(coord)

  if square and square.piece and (square.white == game.white_to_move) then
    if coordEquals(coord, active) then return end
    first_pickup = true
    picked_up_object.use_gravity = false
    displayMoves(coord)
  end
end

function click(coord, player_color, alt)
  if not alt
      and ((game.white_to_move and 'White' or 'Green') == player_color) -- DEBUG comment out if testing
      then
    makeMove(squareAt(coord).trigger_move)
  end
end

function onObjectDrop(player_color, dropped_object)
  if not active or not game then return end
  if not dropped_object.getVar('chesspiece') then return end

  if (game.white_to_move and 'White' or 'Green') ~= player_color then return false end
  local active_sq = squareAt(active)

  if active_sq.piece == dropped_object then
    local coord = posToCoord(dropped_object.getPosition())
    local drop_sq = coord and squareAt(coord)

    if not coord then -- Outside the chessboard
      raisePieceAt(active)
    elseif drop_sq.trigger_move then
      makeMove(drop_sq.trigger_move)
    elseif coordEquals(coord, active) then
      if first_pickup then
        raisePieceAt(active)
      else -- Clicked again to unselect piece
        undisplayMoves()
      end
    else -- Attempted to drop at some invalid square
      raisePieceAt(active)
    end
  end
  first_pickup = false
end

local FILES = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'}
-- `special` can have the following values: nil, castle, qcastle, ep, double, Q, N, R, B)
function Move(src, dest, ptype, captured_ptype, special)
  return {
    ptype=ptype, src=src, dest=dest,
    captured_ptype=captured_ptype, special=special
  }
end

function getSAN(move)
  if move.special == 'castle' then return 'O-O'
  elseif move.special == 'qcastle' then return 'O-O-O' end

  local dest_san = FILES[move.dest[2]] .. tostring(move.dest[1])
  local capture_san = (move.captured_ptype or move.special == 'ep') and 'x' or ''
  local disambig_san = ''
  local ptype_san = ''
  local promotion_san = ''
  local append_san = move.append or ''

  if move.ptype == 'P' then
    if move.captured_ptype then
      disambig_san = FILES[move.src[2]]
    end
    if move.special and string.len(move.special) == 1 then
      promotion_san = '=' .. move.special
    end
  else
    ptype_san = move.ptype
    if move.disambig_file then
      disambig_san = FILES[move.src[2]]
    end
    if move.disambig_rank then
      disambig_san = disambig_san .. tostring(move.src[1])
    end
  end
  return ptype_san .. disambig_san .. capture_san 
      .. dest_san .. promotion_san .. append_san
end

function makeMove(move)
  undisplayMoves()

  local src, dest = move.src, move.dest
  local src_sq = squareAt(src)
  local dest_sq = squareAt(dest)
  local cur_player = game.white_to_move and game.white or game.black

  if dest_sq.piece then
    sendToGraveyard(dest, dest_sq.white)
  end
  src_sq.piece.setAngularVelocity({0,0,0})
  src_sq.piece.setVelocity({0,0,0})
  src_sq.piece.setPositionSmooth(
    coordToPos(dest, src_sq.piece),
  false, true)
  src_sq.piece.use_gravity = true

  -- Handle en passant and remember double moves for en passant
  local pawn_move = game.white_to_move and 1 or -1
  local assigned_ep = false
  if src_sq.ptype == 'P' then
    if move.special == 'double' then
      game.en_passant_coord = {dest[1] - pawn_move, dest[2]}
      assigned_ep = true
    elseif move.special == 'ep' then
      sendToGraveyard({dest[1] - pawn_move, dest[2]}, not game.white_to_move)
      setSquareAt({dest[1] - pawn_move, dest[2]}, {})
    end
  end
  if not assigned_ep then game.en_passant_coord = nil end

  -- Handle king moves
  if src_sq.ptype == 'K' then
    cur_player.king = {dest[1], dest[2]}
    -- Castling
    if move.special == 'castle' or move.special == 'qcastle' then
      local rook_file_src, rook_file_dest
      if dest[2] == 7 then
        rook_src, rook_dest = {dest[1], 8}, {dest[1], 6}
      else
        rook_src, rook_dest = {dest[1], 1}, {dest[1], 4}
      end
      squareAt(rook_src).piece.setPositionSmooth(
        coordToPos(rook_dest, squareAt(rook_src).piece),
      false, true)
      setSquareAt(rook_dest, squareAt(rook_src))
      setSquareAt(rook_src, {})
    end
    cur_player.castle, cur_player.qcastle = false, false
  end

  -- First rook move, invalidate castling on that side
  if src_sq.ptype == 'R' then
    local r_rank = game.white_to_move and 1 or 8
    if cur_player.castle and coordEquals(src, {r_rank, 8}) then
      cur_player.castle = false
    elseif cur_player.qcastle and coordEquals(src, {r_rank, 1}) then
      cur_player.qcastle = false
    end
  end
  -- Rook captured, invalidate castling for opponent on that side
  if dest_sq.ptype == 'R' then
    local r_rank = game.white_to_move and 8 or 1
    local opp_player = game.white_to_move and game.black or game.white
    if opp_player.castle and coordEquals(dest, {r_rank, 8}) then
      opp_player.castle = false
    elseif opp_player.qcastle and coordEquals(dest, {r_rank, 1}) then
      opp_player.qcastle = false
    end
  end

  setSquareAt(dest, src_sq)
  setSquareAt(src, {})

  -- Clear red check highlight
  highlightCoord(cur_player.king, "#00000000")
  -- Clear previous move highlights
  local from, to = game.last_move_from, game.last_move_to
  if from and to then
    highlightCoord(from, "#00000000")
    highlightCoord(to, "#00000000")
  end
  game.last_move_from = src
  game.last_move_to = dest

  -- Pawn promotion
  if src_sq.ptype == 'P' and dest[1] == (game.white_to_move and 8 or 1) then
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
    promo.move = move
    local callback = function(obj, ptype)
      obj.setColorTint({1,1,1,0.4})
      obj.use_gravity = false
      obj.setVar('promo_selection', ptype)
      local pos = obj.getPosition()
      pos.y = coordToPos({0,0}, obj)[2]
      obj.setPosition(pos)
      table.insert(promo.selections, obj)
    end
    for i=1,4 do
      local bag = getObjectFromGUID(INFO[game.material][ptypes[i]][bag_guid_field])
      local j = game.white_to_move and i or -i
      local k = game.white_to_move and 1 or -1
      local pos = coordToPos({dest[1] + pawn_move, dest[2] + j - k})
      bag.takeObject({position = pos, smooth = false,
          callback_function = function(obj) callback(obj, ptypes[i]) end})
    end
  else
    passTurn(move)
  end
end

function undoMove(move)
  -- TODO
  -- must handle checks (game.b/w.in_check), last move highlights, time control,
  -- graveyard, ep square, castling
end

local GRAVE_ORDER = {Q=1, R=2, B=3, N=4, P=5}
function sendToGraveyard(coord, white)
  local sq = squareAt(coord)
  local item = {piece = sq.piece, ptype = sq.ptype}
  local graveyard = white and game.white.graveyard or game.black.graveyard
  local order_val = GRAVE_ORDER[item.ptype]

  local function getGraveyardPosition(index, white, piece)
    local file = 10.5 + math.floor((index - 1) / 5)
    local rank = (index - 1) % 5
    if white then
      rank = 9 - rank
    end
    return coordToPos({rank, file}, piece, false, true)
  end

  local insert_pos = 1
  for i=#graveyard,1,-1 do
    if GRAVE_ORDER[graveyard[i].ptype] <= order_val then
      insert_pos = i + 1
      break
    end
    graveyard[i + 1] = graveyard[i]
    graveyard[i + 1].piece.setPositionSmooth(
      getGraveyardPosition(i + 1, sq.white, sq.piece),
      false, true
    )
  end
  graveyard[insert_pos] = item
  graveyard[insert_pos].piece.setPositionSmooth(
    getGraveyardPosition(insert_pos, sq.white, sq.piece),
    false, true
  )
end

function reanimateFromGraveyard(ptype, coord)

end

function passTurn(last_move)
  local next_player = game.white_to_move and game.black or game.white
  local next_is_white = not game.white_to_move

  local hasMoves = generateMoves(next_is_white)

  local game_over_code, msg
  local append
  game.white.in_check, game.black.in_check = false, false
  if isCheck(next_is_white) then
    highlightCoord(next_player.king, "#FF000088")
    next_player.in_check = true
    if not hasMoves then
      local winner = next_is_white and 'Black' or 'White'
      msg = 'by checkmate'
      game_over_code = not next_is_white
      append = '#'
    else
      broadcastToAll('Check!', {1,1,1})
      append = '+'
    end
  else
    if not hasMoves then
      msg = 'by stalemate'
    end
  end

  highlightCoord(game.last_move_from, "#FFFF0055")
  highlightCoord(game.last_move_to, "#FFFF0055")

  if append then last_move.append = append end
  table.insert(game.history, last_move)
  printToAll(toPGN())

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

function toPGN()
  local result = {}
  for i=1,#game.history,2 do
    local turn_string = tostring((i + 1) / 2) .. '. ' .. getSAN(game.history[i])
    if game.history[i + 1] then
      turn_string = turn_string .. ' ' .. getSAN(game.history[i + 1])
    end

    table.insert(result, turn_string)
  end
  return table.concat(result, '\n')
end

function generateMoves(white)
  local disambig_map, flag_map = {}, {}
  local has_moves = false
  for rank,row in ipairs(game.board) do
    for file,sq in ipairs(row) do
      if sq.white == white and sq.ptype then
        local coord = {rank, file}
        local moves = _G['moves_' .. sq.ptype](coord)
        if #moves > 0 then has_moves = true end
        sq.moves = moves

        if sq.ptype ~= 'K' and sq.ptype ~= 'P' then
          for _,move in ipairs(moves) do
            local str = move.ptype .. tostring(move.dest[1]) .. tostring(move.dest[2])
            local conflicts = disambig_map[str]
            if conflicts then
              table.insert(conflicts, move)
              flag_map[str] = true
            else
              disambig_map[str] = {move}
            end
          end
        end
      else
        sq.moves = nil
      end
    end
  end

  -- Go through moves with the same SAN string and disambiguate
  for str,_ in pairs(flag_map) do
    local conflicts = disambig_map[str]
    for i=1,#conflicts do
      local x = conflicts[i]
      local conflicting_rank = false
      for j=1,#conflicts do
        if i ~= j then
          local y = conflicts[j]
          if x.src[2] == y.src[2] then -- Same files
            x.disambig_rank = true
          elseif x.src[1] == y.src[1] then
            conflicting_rank = true
          end
        end
      end
      x.disambig_file = (not x.disambig_rank) or conflicting_rank
    end
  end
  return has_moves
end

function displayMoves(coord)
  if active then undisplayMoves() end
  active = coord
  local sq = squareAt(coord)
  for _,move in ipairs(sq.moves) do
    local id = string.format('i%d%d', move.dest[1], move.dest[2])
    local image_type = squareAt(move.dest).ptype and 'capture' or 'circle'
    self.UI.setAttribute(id, 'image', image_type)
    setButtonEnabled(move.dest, true)
    squareAt(move.dest).trigger_move = move
  end
end

function undisplayMoves()
  if active then
    local sq = squareAt(active)
    for _,move in ipairs(sq.moves) do
      local id = string.format('i%d%d', move.dest[1], move.dest[2])
      self.UI.setAttribute(id, 'image', 'empty')
      setButtonEnabled(move.dest, false)
      squareAt(move.dest).trigger_move = nil
    end
    sq.piece.drop()
    sq.piece.setVelocity({0,0,0})
    sq.piece.setAngularVelocity({0,0,0})
    sq.piece.setRotation({0,0,0})
    sq.piece.setPositionSmooth(coordToPos(active, sq.piece), false, true)
    sq.piece.use_gravity = true
    active = nil
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
  if not square or not square.ptype then return false end
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
  return square and square.ptype == nil
end

-- Check that the move is valid; if so, put in LIST
function enter(list, from_coord, to_coord, special)
  local castle = (special == 'castle') or (special == 'qcastle')
  local en_passant = special == 'ep'

  if validateMove(from_coord, to_coord, castle, en_passant) then
    local move = Move(
      from_coord, to_coord,
      squareAt(from_coord).ptype,
      en_passant and 'P' or squareAt(to_coord).ptype,
      special
    )
    table.insert(list, move)
    return true
  end
  return false
end

function moves_P(coord)
  local rank, file = coord[1], coord[2]
  local step = squareAt(coord).white and 1 or -1
  local start = squareAt(coord).white and 2 or 7
  local moves = {}
  local move

  -- One step up
  move = {rank + step, file}
  if scan:empty(move) then
    enter(moves, coord, move)
    -- First double move
    move = {rank + 2*step, file}
    if rank == start and scan:empty(move) then
      enter(moves, coord, move, 'double')
    end
  end

  -- Diagonal captures
  move = {rank + step, file + 1}
  if scan:match(move, not squareAt(coord).white) then
    enter(moves, coord, move)
  elseif coordEquals(move, game.en_passant_coord) then
    enter(moves, coord, move, 'ep')
  end
  move = {rank + step, file - 1}
  if scan:match(move, not squareAt(coord).white) then
    enter(moves, coord, move)
  elseif coordEquals(move, game.en_passant_coord) then
    enter(moves, coord, move, 'ep')
  end

  return moves
end

function movesAcrossLine(moves, coord, step_i, step_j)
  local rank, file = coord[1], coord[2]
  local i, j = step_i, step_j
  while true do
    local move = {rank + i, file + j}
    if scan:empty(move) then
      enter(moves, coord, move)
      i, j = i + step_i, j + step_j
    elseif scan:match(move, not squareAt(coord).white) then
      enter(moves, coord, move)
      break
    else
      break
    end
  end
end

function moves_B(coord)
  local moves = {}
  movesAcrossLine(moves, coord, 1, 1)
  movesAcrossLine(moves, coord, 1, -1)
  movesAcrossLine(moves, coord, -1, 1)
  movesAcrossLine(moves, coord, -1, -1)
  return moves
end

function moves_R(coord)
  local moves = {}
  movesAcrossLine(moves, coord, 0, 1)
  movesAcrossLine(moves, coord, 0, -1)
  movesAcrossLine(moves, coord, 1, 0)
  movesAcrossLine(moves, coord, -1, 0)
  return moves
end

function moves_Q(coord)
  local moves = {}
  movesAcrossLine(moves, coord, 1, 1)
  movesAcrossLine(moves, coord, 1, -1)
  movesAcrossLine(moves, coord, -1, 1)
  movesAcrossLine(moves, coord, -1, -1)
  movesAcrossLine(moves, coord, 0, 1)
  movesAcrossLine(moves, coord, 0, -1)
  movesAcrossLine(moves, coord, 1, 0)
  movesAcrossLine(moves, coord, -1, 0)

  return moves
end

function moves_N(coord)
  local candidates, moves = {}, {}
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
    if scan:empty(move) or scan:match(move, not squareAt(coord).white) then
      enter(moves, coord, move)
    end
  end
  return moves
end

function moves_K(coord)
  local candidates, moves = {}, {}
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
    if scan:empty(move) or scan:match(move, not squareAt(coord).white) then
      enter(moves, coord, move)
    end
  end

  local cur_player = squareAt(coord).white and game.white or game.black

  if not cur_player.in_check then
    if cur_player.castle
        and scan:empty({rank, 6})
        and scan:empty({rank, 7}) then
      enter(moves, coord, {rank, 7}, 'castle')
    end
    if cur_player.qcastle
        and scan:empty({rank, 2})
        and scan:empty({rank, 3})
        and scan:empty({rank, 4}) then
      enter(moves, coord, {rank, 3}, 'qcastle')
    end
  end

  return moves
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

function gameOver(code, msg, no_increment)
  time_live = false
  game.over = true
  game.over_code = code
  game.over_msg = msg
  if active then
    undisplayMoves()
  end
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
local RAISE_HEIGHT = 1
function coordToPos(coord, piece, raise, off_board)
  local x = -pos_start + pos_step * (coord[2] - 1)
  local z = -pos_start + pos_step * (coord[1] - 1)

  local table_obj = Tables.getTableObject()
  local y = table_obj.getBounds().center.y + table_obj.getBounds().size.y / 2
  if not off_board then y = y + self.getBounds().size.y end
  if piece then
    y = y + piece.getBounds().size.y / 2
  else
    y = y + 5
  end
  if raise then y = y + RAISE_HEIGHT end

  return {x, y, z}
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

function raisePieceAt(coord)
  local sq = squareAt(coord)
  sq.piece.setVelocity({0,0,0})
  sq.piece.setAngularVelocity({0,0,0})
  sq.piece.setPositionSmooth(coordToPos(coord, sq.piece, true), false, true)
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