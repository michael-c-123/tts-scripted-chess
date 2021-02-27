-- TODO uninteractable enemy pieces except to capture
-- TODO marker squares: more opaque on white tiles
-- TODO previous turn: mark squares yellow
-- TODO check: mark square red
-- TODO logging moves

INFO = {
  ['P'] = {height=2.77, wbag_guid='b795f6', bbag_guid='c70db4'},
  ['R'] = {height=2.88, wbag_guid='0a44d3', bbag_guid='b7adf5'},
  ['N'] = {height=3.2, wbag_guid='5d7621', bbag_guid='0dfee7'},
  ['B'] = {height=3.06, wbag_guid='325444', bbag_guid='66240d'},
  ['Q'] = {height=3.4, wbag_guid='b87cbe', bbag_guid='7d6441'},
  ['K'] = {height=3.51, wbag_guid='68baf5', bbag_guid='66aa94'}
}

game = {}
promo = {}

-- Buttons 170 width/height, 593 xyoffset

function onLoad(save_state)
  self.setSnapPoints({})
  -- self.interactable = false
  Turns.enable = true
  Turns.pass_turns = false
  if save_state and save_state ~= '' then
    game = JSON.decode(save_state)
  else
    startBoardStatus()
  end
  local del_objs = getObjectFromGUID('1ab955').getObjects()
  for _,del_obj in ipairs(del_objs) do
    if del_obj ~= self then
      del_obj.destruct()
    end
  end
  setup()
end

function onSave()
  local copy = {['board']={}}
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
  copy.white_to_move = game.white_to_move
  copy.white, copy.black = game.white, game.black
  copy.en_passant_coord = game.en_passant_coord
  return JSON.encode(copy)
end

function startBoardStatus()
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

function setup()
  local setup_square = function(coord, ptype, white)
    local bag_guid = white and 'wbag_guid' or 'bbag_guid'
    getObjectFromGUID(INFO[ptype][bag_guid]).takeObject({
      position = coordToPos(coord, ptype),
      rotation = {0, white and 180 or 0, 0},
      smooth = false,
      callback_function = function(p)
        squareAt(coord).piece = p
      end
    })
  end

  local xml_table = {}
  local START, STOP = -592, 592
  local step = (STOP - START) / 7.0

  for i=1,8 do
    for j=1,8 do
      local coord = {i, j}
      local sq = squareAt(coord)
      if sq.ptype then
        setup_square(coord, sq.ptype, sq.white)
      end
      table.insert(xml_table, {
        tag = 'Image',
        attributes = {
          id = string.format("i%d%d", i, j),
          width = step, height = step,
          offsetXY = string.format("%f %f",
            START + (j - 1) * step,
            START + (i - 1) * step
          ),
          color = "#00000000",
        }
      })
      table.insert(xml_table, {
        tag = 'Button',
        attributes = {
          id = string.format("%d%d", i, j),
          active = false,
          width = step, height = step,
          offsetXY = string.format("%f %f",
            START + (j - 1) * step,
            START + (i - 1) * step
          ),
          icon = 'circle',
          color = '#00000000',
          onClick = 'buttonClicked',
          onMouseEnter = 'buttonEntered',
          onMouseExit = 'buttonExited'
          -- Alpha 0x97
        }
      })
    end
  end

  self.UI.setXmlTable(xml_table)
  Turns.turn_color = game.white_to_move and 'White' or 'Green'
end

local active = nil
local first_pickup = false
function onObjectPickUp(player_color, picked_up_object)
  local cur_color = game.white_to_move and 'White' or 'Green'
  if player_color ~= cur_color then
    broadcastToColor('It is not your turn.', player_color)
    picked_up_object.setVelocity({0,0,0})
    picked_up_object.setAngularVelocity({0,0,0})
    picked_up_object.drop()
    return
  end

  local promo_type = picked_up_object.getVar('promo_selection')
  if promo_type then
    for _,obj in ipairs(promo.selections) do
      obj.destruct()
    end

    squareAt(promo.pawn_coord).piece.destruct()
    local pos = coordToPos(promo.pawn_coord, promo_type)
    local bag = getObjectFromGUID(INFO[promo_type][game.white_to_move and 'wbag_guid' or 'bbag_guid'])
    local promoted_piece = bag.takeObject({position = pos, smooth = false})
    squareAt(promo.pawn_coord).piece = promoted_piece
    squareAt(promo.pawn_coord).ptype = promo_type
    promo.selections = {}
    promo.pawn_coord = nil
    passTurn()
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

function buttonClicked(player, button, id)
  if (button == '-1')
      -- and ((game.white_to_move and 'White' or 'Green') == player.color)
      then

    local num = tonumber(id)
    local coord = {math.floor(num / 10), num % 10}
    local click_specials = squareAt(coord).specials
    clearPreviews()
    moveTo(coord, click_specials)
  end
end

function buttonEntered(player, _, id)
  if true
      -- and ((game.white_to_move and 'White' or 'Green') == player.color)
      then

    local num = tonumber(id)
    local sq = squareAt({math.floor(num / 10), num % 10})
    if sq and sq.piece then
      if sq.ptype ~= nil or sq.specials.en_passant then
        sq.piece.highlightOn({1,0,0})
      else
        sq.piece.highlightOn({1,1,1})
      end
    end
  end
end

function buttonExited(player, _, id)
  if true
      -- and ((game.white_to_move and 'White' or 'Green') == player.color)
      then

    local num = tonumber(id)
    local sq = squareAt({math.floor(num / 10), num % 10})
    if sq and sq.piece then
      sq.piece.highlightOff()
    end
  end
end

function raisePieceAt(coord)
  local sq = squareAt(coord)
  sq.piece.setVelocity({0,0,0})
  sq.piece.setAngularVelocity({0,0,0})
  sq.piece.setPositionSmooth(coordToPos(coord, sq.ptype, true), false, true)
end

function onObjectDrop(player_color, dropped_object)
  if not active then return false end
  local coord = posToCoord(dropped_object.getPosition())
  local active_sq = squareAt(active)
  local drop_sq = coord and squareAt(coord)

  if active_sq.piece == dropped_object then
    if not coord then
      raisePieceAt(active)
    elseif drop_sq.piece and drop_sq.specials.move then
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
    else
      raisePieceAt(active)
    end
  end
  first_pickup = false
  -- log('rank '..rank)
  -- log('file '..file)
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

  -- First rook move (invalidate castling on that side)
  if src_square.ptype == 'R' then
    local r_rank = game.white_to_move and 1 or 8
    if cur_player.castle and coordEquals(active, {r_rank, 8}) then
      cur_player.castle = false
    elseif cur_player.qcastle and coordEquals(active, {r_rank, 1}) then
      cur_player.qcastle = false
    end
  end

  setSquareAt(dest, src_square)
  setSquareAt(active, {})

  -- Clear red check highlight
  highlightCoord(cur_player.king, "#00000000")
  -- Clear previous move highlights
  local from, to = game.last_move_from, game.last_move_to
  if from and to then
    highlightCoord(from, "00000000")
    highlightCoord(to, "00000000")
  end
  game.last_move_from = active
  game.last_move_to = dest

  -- Pawn promotion
  if src_square.ptype == 'P' and dest[1] == (game.white_to_move and 8 or 1) then
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
      local bag = getObjectFromGUID(INFO[ptypes[i]][bag_guid_field])
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
  game.white_to_move = not game.white_to_move
  local game_over = false

  for i=1,8 do
    for j=1,8 do
      local sq = squareAt({i, j})
      if sq.piece then
        sq.piece.interactable = sq.white == game.white_to_move
      end
    end
  end

  local next_player = game.white_to_move and game.white or game.black
  game.white.in_check, game.black.in_check = false, false
  if isCheck(game.white_to_move) then
    next_player.in_check = true
    if not hasMoves(game.white_to_move) then
      local winner = game.white_to_move and 'Black' or 'White'
      broadcastToAll('CHECKMATE! ' .. winner .. ' wins!', {1,1,1})
      game_over = true
    else
      broadcastToAll('CHECK', {1,1,1})
      highlightCoord(next_player.king, "#FF000088")
    end
  else
    if not hasMoves(game.white_to_move) then
      broadcastToAll('STALEMATE!', {1,1,1})
      game_over = true
    end
  end

  highlightCoord(game.last_move_from, "#FFFF0055")
  highlightCoord(game.last_move_to, "#FFFF0055")

  if game_over then
    -- TODO
  else
    Turns.turn_color = game.white_to_move and "White" or "Green"
  end
end

local scan = {}
-- Returns whether there is a piece at COORD opposing the current player,
-- with ptype matching any in PTYPES (default: all)
function scan:oppose(coord, ptypes)
  local square
  if self.changes
      and self.changes[coord[1]]
      and self.changes[coord[1]][coord[2]] then
    square = self.changes[coord[1]][coord[2]]
  else
    square = squareAt(coord)
  end
  local white = game.white_to_move
  if not square or not square.piece then return false end
  return square.white ~= white
    and (not ptypes or ptypes[square.ptype])
end
-- Returns whether there is a piece at COORD matching the player indicated
-- by WHITE (default: current player), with ptype matching any in PTYPES
-- (default: all)
function scan:match(coord, ptypes, white)
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
    squareAt(active).piece.setPositionSmooth(coordToPos(active, squareAt(active).ptype), false, true)
  end
  for _,coord in ipairs(move_previews) do
    local square = squareAt(coord)
    local id = string.format('%d%d', coord[1], coord[2])
    self.UI.setAttribute(id, 'active', false)
    square.piece.destruct()
    setSquareAt(coord, {})
  end
  move_previews = {}
  for _,coord in ipairs(capture_previews) do
    local square = squareAt(coord)
    local id = string.format('%d%d', coord[1], coord[2])
    self.UI.setAttribute(id, 'color', '#00000000')
    self.UI.setAttribute(id, 'active', false)
    square.piece.highlightOff()
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
  local step = game.white_to_move and 1 or -1
  local start = game.white_to_move and 2 or 7
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
  if scan:oppose(move) then
    if enter(coord, move, captures, stop) then return end
  elseif coordEquals(move, game.en_passant_coord) and validateMove(coord, move, nil, true) then
    en_passant = move
  end
  move = {rank + step, file - 1}
  if scan:oppose(move) then
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
    elseif scan:oppose(move) then
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
    elseif scan:oppose(move) then
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
    elseif scan:oppose(move) then
      if enter(coord, move, captures, stop) then return end
    end
  end

  local castles = {}
  local cur_player = game.white_to_move and game.white or game.black

  -- log({game.white.castle, game.white.qcastle, game.black.castle, game.black.qcastle})
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
  local is_into_check = isCheck(game.white_to_move)
  scan.changes = nil

  return not is_into_check
end

function previewMove(from_coord, to_coord)
  local ptype = squareAt(from_coord).ptype
  local pos = coordToPos(to_coord, ptype)

  local bag = getObjectFromGUID(INFO[ptype][squareAt(from_coord).white and 'wbag_guid' or 'bbag_guid'])
  local preview_piece = bag.takeObject({position = pos, smooth = false,
      callback_function = function(p)
        p.setColorTint({1,1,1,0})
        p.interactable = false
      end})

  self.UI.setAttribute(string.format('%d%d', to_coord[1], to_coord[2]), 'active', true)
  setSquareAt(to_coord, {piece=preview_piece, specials={move=true}})
  table.insert(move_previews, to_coord)
end

function previewCapture(from_coord, to_coord)
  local target = squareAt(to_coord)
  local id = string.format('%d%d', to_coord[1], to_coord[2])
  self.UI.setAttributes(id, {
    active = true,
    color = '#00000097'
  })
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
  if scan:match({r + p_rank, f + 1}, pawn_set, enemy) then return true end
  if scan:match({r + p_rank, f - 1}, pawn_set, enemy) then return true end
  if scan:match({r - p_rank, f + 1}, k_diag_set, enemy) then return true end
  if scan:match({r - p_rank, f - 1}, k_diag_set, enemy) then return true end
  if scan:match({r + 1, f}, k_ortho_set, enemy) then return true end
  if scan:match({r - 1, f}, k_ortho_set, enemy) then return true end
  if scan:match({r, f + 1}, k_ortho_set, enemy) then return true end
  if scan:match({r, f - 1}, k_ortho_set, enemy) then return true end

  -- Look across a line for certain pieces
  local look_line = function(step_i, step_j, ptypes)
    local i, j = step_i, step_j
    while true do
      local coord = {r + i, f + j}
      if scan:empty(coord) then
        i, j = i + step_i, j + step_j
      elseif scan:match(coord, ptypes, enemy) then
        return true
      else
        break
      end
    end
    return false
  end

  if scan:match({r + 1, f + 2}, knight_set, enemy) then return true end
  if scan:match({r + 2, f + 1}, knight_set, enemy) then return true end
  if scan:match({r + 1, f - 2}, knight_set, enemy) then return true end
  if scan:match({r + 2, f - 1}, knight_set, enemy) then return true end
  if scan:match({r - 1, f + 2}, knight_set, enemy) then return true end
  if scan:match({r - 2, f + 1}, knight_set, enemy) then return true end
  if scan:match({r - 1, f - 2}, knight_set, enemy) then return true end
  if scan:match({r - 2, f - 1}, knight_set, enemy) then return true end

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
  return {x, INFO[ptype].height + (raise and 1 or 0), z}
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
    string.format("i%d%d", coord[1], coord[2]),
    "color", color
  )
end

function debug_printBoard()
  local str = ''
  for _,row in ipairs(game) do
    for _,square in ipairs(row) do
      if square.piece == nil then
        str = str .. '.'
      elseif square.ptype then
        if square.white then
          str = str .. square.ptype
        else
          str = str .. square.ptype:lower()
        end
      else
        str = str .. 'X'
      end
    end
    str = str .. '\n'
  end
  log(str)
end

function onScriptingButtonUp(index, player_color)
  -- debug_printBoard()
  log(Player['White'].getHoverObject())
  log(Player['White'].getHoldingObjects())

end