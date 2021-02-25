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
  game[i] = {0,0,0,0,0,0,0,0}
end
game.black_castled = false
game.white_castled = false


-- Buttons 170 width/height, 593 xyoffset

function onLoad(save_state)
  self.setSnapPoints({})
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
        -- Special fields: capture, move, castle, en passant, promote
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
  local coord = posToCoord(picked_up_object.getPosition())
  if not coord then return end
  local square = squareAt(coord)
  if square and square ~= 0 then

    if square.white == (Turns.turn_color == 'White') then
      if coordEquals(coord, active) then return end
      clearPreviews()
      first_pickup = true
      active = coord
      picked_up_object.use_gravity = false
      showPreviews(coord)
    elseif square.specials.move then
      clearPreviews()
      moveTo(coord)
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
  local coord = posToCoord(dropped_object.getPosition())
  local active_sq = squareAt(active)
  local drop_sq = coord and squareAt(coord)

  if active_sq.piece == dropped_object then
    if not coord then
      raisePieceAt(active)
    elseif drop_sq ~= 0 and drop_sq.specials.move then
      clearPreviews()
      moveTo(coord)
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

function moveTo(dest)
  local src_square = squareAt(active)
  local dest_square = squareAt(dest)
  if dest_square ~= 0 then
    dest_square.piece.destruct()
  end
  src_square.piece.setAngularVelocity({0,0,0})
  src_square.piece.setVelocity({0,0,0})
  src_square.piece.setPositionSmooth(
    coordToPos(dest, src_square.ptype),
  false, true)

  setSquareAt(dest, src_square)
  setSquareAt(active, 0)
  src_square.piece.use_gravity = true

  active = nil
  Turns.turn_color = Turns.getNextTurnColor()
end

local scan = {
  oppose = function(coord)
    local square = squareAt(coord)
    if not square or square == 0 then return false end
    return square.white ~= (Turns.turn_color == 'White')
  end,
  empty = function(coord)
    return squareAt(coord) == 0
  end,
}

local move_previews = {}
local capture_previews = {}
function showPreviews(coord)
  _G['preview'..squareAt(coord).ptype](coord)
end

function clearPreviews()
  if active then
    squareAt(active).piece.setVelocity({0,0,0})
    squareAt(active).piece.setPositionSmooth(coordToPos(active, squareAt(active).ptype), false, true)
  end
  for _,coord in ipairs(move_previews) do
    local square = squareAt(coord)
    square.piece.destruct()
    setSquareAt(coord, 0)
  end
  move_previews = {}
  for _,coord in ipairs(capture_previews) do
    local square = squareAt(coord)
    square.piece.highlightOff({1,0,0})
    square.specials = {}
  end
  capture_previews = {}
end

function previewP(coord)
  local rank, file = coord[1], coord[2]
  local step = (Turns.turn_color == 'White') and 1 or -1
  local start = (Turns.turn_color == 'White') and 2 or 7
  local move
  -- One step up
  move = {rank + step, file}
  if scan.empty(move) then
    previewMove(move)
    -- First double move
    move = {rank + 2*step, file}
    if rank == start and scan.empty(move) then
      previewMove(move)
    end
  end

  -- Diagonal captures
  move = {rank + step, file + 1}
  if scan.oppose(move) then
    previewCapture(move)
  end
  move = {rank + step, file - 1}
  if scan.oppose(move) then
    previewCapture(move)
  end
end

function previewLine(coord, step_i, step_j)
  local rank, file = coord[1], coord[2]
  local i, j = step_i, step_j
  while true do
    local move = {rank + i, file + j}
    if scan.empty(move) then
      previewMove(move)
      i, j = i + step_i, j + step_j
    elseif scan.oppose(move) then
      previewCapture(move)
      break
    else
      break
    end
  end
end

function previewB(coord)
  previewLine(coord, 1, 1)
  previewLine(coord, 1, -1)
  previewLine(coord, -1, 1)
  previewLine(coord, -1, -1)
end

function previewR(coord)
  previewLine(coord, 0, 1)
  previewLine(coord, 0, -1)
  previewLine(coord, 1, 0)
  previewLine(coord, -1, 0)
end

function previewQ(coord)
  previewB(coord)
  previewR(coord)
end

function previewN(coord)
  local rank, file = coord[1], coord[2]
  local moves = {}
  table.insert(moves, {rank + 1, file + 2})
  table.insert(moves, {rank + 2, file + 1})
  table.insert(moves, {rank - 1, file + 2})
  table.insert(moves, {rank - 2, file + 1})
  table.insert(moves, {rank + 1, file - 2})
  table.insert(moves, {rank + 2, file - 1})
  table.insert(moves, {rank - 1, file - 2})
  table.insert(moves, {rank - 2, file - 1})

  for _,move in ipairs(moves) do
    if scan.empty(move) then
      previewMove(move)
    elseif scan.oppose(move) then
      previewCapture(move)
    end
  end
end

function previewK(coord)
  local rank, file = coord[1], coord[2]
  local moves = {}
  table.insert(moves, {rank + 1, file})
  table.insert(moves, {rank - 1, file})
  table.insert(moves, {rank, file + 1})
  table.insert(moves, {rank, file - 1})

  table.insert(moves, {rank + 1, file + 1})
  table.insert(moves, {rank + 1, file - 1})
  table.insert(moves, {rank - 1, file + 1})
  table.insert(moves, {rank - 1, file - 1})

  for _,move in ipairs(moves) do
    if scan.empty(move) then
      previewMove(move)
    elseif scan.oppose(move) then
      previewCapture(move)
    end
  end
end

function previewMove(coord)
  local ptype = squareAt(active).ptype
  local pos = coordToPos(coord, ptype)

  local bag = getObjectFromGUID(INFO[ptype][squareAt(active).white and 'wbag_guid' or 'bbag_guid'])
  local preview_piece = bag.takeObject({position = pos, smooth = false})
  preview_piece.setColorTint({1,1,1,0.1})

  setSquareAt(coord, {piece=preview_piece, specials={move=true}})
  table.insert(move_previews, coord)
end

function previewCapture(coord)
  local target = squareAt(coord).piece
  squareAt(coord).specials.move = true
  target.highlightOn({1,0,0})
  table.insert(capture_previews, coord)
end

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
  if not game[coord[1]] then return nil end
  return game[coord[1]][coord[2]]
end
function setSquareAt(coord, val)
  game[coord[1]][coord[2]] = val
end

function debug_printBoard()
  local str = ''
  for _,row in ipairs(game) do
    for _,square in ipairs(row) do
      if square == 0 then
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