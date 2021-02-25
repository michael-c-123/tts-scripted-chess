-- TODO stalemate, checkmate
-- TODO game saving
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
for i=1,8 do
  game[i] = {{},{},{},{},{},{},{},{}}
end
game.white_castle = true
game.white_qcastle = true
game.black_castle = true
game.black_qcastle = true
game.white_king = {1, 5}
game.black_king = {8, 5}
game.is_white_turn = true
game.en_passant_coord = nil
promo = {}

-- Buttons 170 width/height, 593 xyoffset

function onLoad(save_state)
  self.setSnapPoints({})
  -- self.interactable = false
  Turns.enable = true
  Turns.pass_turns = false
  setup()
end

function setup()
  local setupPiece = function(coord, ptype, white)
    local bag_guid = white and 'wbag_guid' or 'bbag_guid'
    local piece = getObjectFromGUID(INFO[ptype][bag_guid]).takeObject({
      position=coordToPos(coord, ptype),
      rotation={0, white and 180 or 0, 0},
      smooth = false,
      callback_function = function(p)
        setSquareAt(coord, {
          piece = p,
          ptype = ptype,
          white = white,
          specials = {}
        })
        -- Special fields: move, castle, en passant, promote
      end
    })
  end

  local setupSide = function(white)
    local backRank = white and 1 or 8
    local frontRank = white and 2 or 7

    local file = 1
    setupPiece({backRank, file}, 'R', white)
    file = file + 1
    setupPiece({backRank, file}, 'N', white)
    file = file + 1
    setupPiece({backRank, file}, 'B', white)
    file = file + 1
    setupPiece({backRank, file}, 'Q', white)
    file = file + 1
    setupPiece({backRank, file}, 'K', white)
    file = file + 1
    setupPiece({backRank, file}, 'B', white)
    file = file + 1
    setupPiece({backRank, file}, 'N', white)
    file = file + 1
    setupPiece({backRank, file}, 'R', white)

    for file=1,8 do
      setupPiece({frontRank, file}, 'P', white)
    end
  end

  setupSide(true)
  setupSide(false)
  Turns.turn_color = 'White'
end

local active = nil
local first_pickup = false
function onObjectPickUp(player_color, picked_up_object)
  local cur_color = game.is_white_turn and 'White' or 'Green'
  if player_color ~= cur_color then
    broadcastToColor('It is not your turn.', player_color)
    picked_up_object.setVelocity({0,0,0})
    picked_up_object.setAngularVelocity({0,0,0})
    picked_up_object.drop()
    return
  end

  local promo_type = picked_up_object.getVar('promo_selection')
  if promo_type then
    log(promo_type)
    for _,obj in ipairs(promo.selections) do
      obj.destruct()
    end

    squareAt(promo.pawn_coord).piece.destruct()
    local pos = coordToPos(promo.pawn_coord, promo_type)
    local bag = getObjectFromGUID(INFO[promo_type][game.is_white_turn and 'wbag_guid' or 'bbag_guid'])
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

  if square and square.piece then
    if square.white == game.is_white_turn then
      if coordEquals(coord, active) then return end
      clearPreviews()
      first_pickup = true
      active = coord
      picked_up_object.use_gravity = false
      showMoves(coord)
    elseif square.specials.move then
      clearPreviews()
      moveTo(coord, square)
    else
      broadcastToColor('This is not your piece.', game.is_white_turn and 'White' or 'Green')
      picked_up_object.drop()
      picked_up_object.setVelocity({0,-10,0})
      picked_up_object.setAngularVelocity({0,0,0})
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
      clearPreviews()
      moveTo(coord, drop_sq) -- drop_sq preserves info cleared by clearPreviews()
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

function moveTo(dest, dest_square)
  local src_square = squareAt(active)
  if dest_square.piece then
    dest_square.piece.destruct()
  end
  src_square.piece.setAngularVelocity({0,0,0})
  src_square.piece.setVelocity({0,0,0})
  src_square.piece.setPositionSmooth(
    coordToPos(dest, src_square.ptype),
  false, true)
  src_square.piece.use_gravity = true

  if src_square.ptype == 'K' then
    if game.is_white_turn then
      game.white_king = dest
    else
      game.black_king = dest
    end
  end

  -- Handle en passant and remember double moves for en passant
  local pawn_move = game.is_white_turn and 1 or -1
  if dest_square.specials and src_square.ptype == 'P' then
    if dest_square.specials.double_move then
      game.en_passant_coord = {dest[1] - pawn_move, dest[2]}
    else
      game.en_passant_coord = nil
      if dest_square.specials.en_passant then
        squareAt({dest[1] - pawn_move, dest[2]}).piece.destruct()
        setSquareAt({dest[1] - pawn_move, dest[2]}, {})
      end
    end
  end

  if src_square.ptype == 'K' then
    if dest_square.specials and dest_square.specials.castle then
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
    if game.is_white_turn then
      game.white_castle, game.white_qcastle = false, false
    else
      game.black_castle, game.black_qcastle = false, false
    end
  end

  -- First rook move (invalidate castling on that side)
  if src_square.ptype == 'R' then
    if game.is_white_turn then
      if game.white_castle and coordEquals(active, {1, 8}) then
        game.white_castle = false
      elseif game.white_qcastle and coordEquals(active, {1, 1}) then
        game.white_qcastle = false
      end
    else
      if game.black_castle and coordEquals(active, {8, 8}) then
        game.black_castle = false
      elseif game.black_qcastle and coordEquals(active, {8, 1}) then
        game.black_qcastle = false
      end
    end
  end

  setSquareAt(dest, src_square)
  setSquareAt(active, {})

  if src_square.ptype == 'P' and dest[1] == (game.is_white_turn and 8 or 1) then
    local bag_guid_field = game.is_white_turn and 'wbag_guid' or 'bbag_guid'
    local ptypes = {'Q', 'N', 'R', 'B'}
    promo.selections = {}
    promo.pawn_coord = dest
    log(promo.pawn_coord)
    local callback = function(obj, ptype)
      obj.setColorTint({1,1,1,0.4})
      obj.use_gravity = false
      obj.setVar('promo_selection', ptype)
      table.insert(promo.selections, obj)
    end
    for i=1,4 do
      local bag = getObjectFromGUID(INFO[ptypes[i]][bag_guid_field])
      local j = game.is_white_turn and i or -i
      local k = game.is_white_turn and 1 or -1
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
  game.is_white_turn = not game.is_white_turn
  if isCheck(game.is_white_turn) then
    broadcastToAll('CHECK', {1,1,1})
    -- TODO check checkmate
  else
    -- TODO check stalemate
  end
  Turns.turn_color = game.is_white_turn and "White" or "Green"
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
  local white = game.is_white_turn
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
  if white == nil then white = game.is_white_turn end
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
    square.piece.destruct()
    setSquareAt(coord, {})
  end
  move_previews = {}
  for _,coord in ipairs(capture_previews) do
    local square = squareAt(coord)
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
  local step = game.is_white_turn and 1 or -1
  local start = game.is_white_turn and 2 or 7
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
    log("assinged ep")
    en_passant = move
  end
  move = {rank + step, file - 1}
  if scan:oppose(move) then
    if enter(coord, move, captures, stop) then return end
  elseif coordEquals(move, game.en_passant_coord) and validateMove(coord, move, nil, true) then
    log("assinged ep")
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
  local home_rank, can_castle, can_qcastle
  if game.is_white_turn then
    home_rank = 1
    can_castle = game.white_castle
    can_qcastle = game.white_qcastle
  else
    home_rank = 8
    can_castle = game.black_castle
    can_qcastle = game.black_qcastle
  end

  -- log({game.white_castle, game.white_qcastle, game.black_castle, game.black_qcastle})
  if rank == home_rank then
    if can_castle and scan:empty({rank, 6}) and scan:empty({rank, 7}) then
      if validateMove(coord, {rank, 7}, true) then
        table.insert(castles, {rank, 7})
      end
    elseif can_qcastle and scan:empty({rank, 2}) and scan:empty({rank, 3}) and scan:empty({rank, 4}) then
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
  local is_into_check = isCheck(game.is_white_turn)
  scan.changes = nil

  return not is_into_check
end

function previewMove(from_coord, to_coord)
  local ptype = squareAt(from_coord).ptype
  local pos = coordToPos(to_coord, ptype)

  local bag = getObjectFromGUID(INFO[ptype][squareAt(from_coord).white and 'wbag_guid' or 'bbag_guid'])
  local preview_piece = bag.takeObject({position = pos, smooth = false})
  preview_piece.setColorTint({1,1,1,0.1})

  setSquareAt(to_coord, {piece=preview_piece, specials={move=true}})
  table.insert(move_previews, to_coord)
end

function previewCapture(from_coord, to_coord)
  local target = squareAt(to_coord)
  target.specials.move = true
  target.piece.highlightOn({1,0,0})
  table.insert(capture_previews, to_coord)
end

local knight_set = {N=true}
local pawn_set = {P=true, Q=true, B=true}
local diagonal_set = {B=true, Q=true}
local orthogonal_set = {R=true, Q=true}

function isCheck(white)
  local king = white and game.white_king or game.black_king
  if scan.changes then
    local changed_king = white and scan.changes.white_king or scan.changes.black_king
    if changed_king then king = changed_king end
  end
  local enemy = not white
  local r, f = king[1], king[2]

  local p_rank = (white and 1 or -1)
  if scan:match({r + p_rank, f + 1}, pawn_set, enemy) then return {r + p_rank, f + 1} end
  if scan:match({r + p_rank, f - 1}, pawn_set, enemy) then return {r + p_rank, f - 1} end

  local look_line = function(step_i, step_j, ptypes)
    local i, j = step_i, step_j
    while true do
      local coord = {r + i, f + j}
      if scan:empty(coord) then
        i, j = i + step_i, j + step_j
      elseif scan:match(coord, ptypes, enemy) then
        return coord
      else
        break
      end
    end
    return nil
  end

  if scan:match({r + 1, f + 2}, knight_set, enemy) then return {r + 1, f + 2} end
  if scan:match({r + 2, f + 1}, knight_set, enemy) then return {r + 2, f + 1} end
  if scan:match({r + 1, f - 2}, knight_set, enemy) then return {r + 1, f - 2} end
  if scan:match({r + 2, f - 1}, knight_set, enemy) then return {r + 2, f - 1} end
  if scan:match({r - 1, f + 2}, knight_set, enemy) then return {r - 1, f + 2} end
  if scan:match({r - 2, f + 1}, knight_set, enemy) then return {r - 2, f + 1} end
  if scan:match({r - 1, f - 2}, knight_set, enemy) then return {r - 1, f - 2} end
  if scan:match({r - 2, f - 1}, knight_set, enemy) then return {r - 2, f - 1} end

  return
    look_line(1, 1, diagonal_set)
    or look_line(1, -1, diagonal_set)
    or look_line(-1, 1, diagonal_set)
    or look_line(-1, -1, diagonal_set)

    or look_line(1, 0, orthogonal_set)
    or look_line(0, 1, orthogonal_set)
    or look_line(-1, 0, orthogonal_set)
    or look_line(0, -1, orthogonal_set)
end

function hasMoves(white)
  -- TODO
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
  if not game[coord[1]] then return end
  return game[coord[1]][coord[2]]
end
function setSquareAt(coord, val)
  game[coord[1]][coord[2]] = val
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