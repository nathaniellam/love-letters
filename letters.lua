local letters = {}
letters.__index = letters

setmetatable(letters, {
  __call = function(self)
    return self.new()
  end
})

function letters.new()
  local inst = setmetatable({}, letters)
  inst:init()
  return inst
end

function letters:init()
  self.lines = {{}}
  self.cursor = 1
  self.length = 0
end

-- Move cursor forward.
function letters:forward()
  self.cursor = math.min(self.cursor + 1, self.length + 1)
end

-- Move cursor backward.
function letters:backward()
  self.cursor = math.max(self.cursor - 1, 1)
end

-- Return current cursor position.
function letters:getCursor()
  return self.cursor
end

-- Set cursor position clamped to 1 to line buffer length + 1.
function letters:setCursor(cursor)
  self.cursor = math.max(1, math.min(cursor, self.length + 1))
end

-- Add character to buffer at cursor position.
function letters:insert(ch)
  local col, line = self:cursorToColRow(self.cursor)
  table.insert(self.lines[line], col, ch)
  self.length = self.length + 1
  return col, line
end

-- Remove character from buffer at cursor position.
function letters:remove()
  if self.length > 0 then
    local col, line = self:cursorToColRow(self.cursor)
    self.length = self.length - 1
    return table.remove(self.lines[line], col)
  end
  return nil
end

-- Gets the position (col, line) of a given buffer index.
function letters:cursorToColRow(idx)
  if idx < 0 then
    error("index cannot be less than 0.")
  end

  -- Iterate through lines and find line index occurs on.
  local col = idx
  for ln, line in ipairs(self.lines) do
    local ncol = col - #line
    if ncol < 1 then
      return col, ln
    else
      col = ncol
    end
  end

  -- Index must be larger than lines so return last position plus 1
  return #self.lines[#self.lines] + 1, #self.lines
end

-- Convert column and row into cursor position.
function letters:colRowToCursor(col, line)
  if col < 0 or line < 0 then
    error("column and line must be non-negative.")
  end

  local idx = 0
  for i=1, line-1 do
    idx = idx + #self.lines[i]
  end
  return idx + col
end

function letters:clear()
  -- Clear the line buffer.
  self.lines = {{}}
  self.length = 0
end

-- Returns line buffer contents as string.
function letters:contents(sep)
  sep = sep or "\n"
  local contents = {}
  for _, line in ipairs(self.lines) do
    for _, ch in ipairs(line) do
      table.insert(contents, ch)
    end
    if sep ~= '' then
      table.insert(contents, sep)
    end
  end
  return table.concat(contents)
end

-- Get selected lines of line buffer.
function letters:select(startCursor, endCursor)
  -- Make sure startCursor is the smaller index.
  if startCursor > endCursor then
    startCursor, endCursor = endCursor, startCursor
  end
  local startCol, startRow = self:cursorToColRow(startCursor)
  local endCol, endRow = self:cursorToColRow(endCursor)
  local selected = {}

  -- Just get single line fragment.
  if startRow == endRow then
    local tmp = {}
    local line = self.lines[startRow]
    for i=startCol, endCol do
      table.insert(tmp, line[i])
    end
    table.insert(selected, tmp)
  else
    -- Insert middle selected lines.
    for i=startRow+1, endRow-1 do
      local line = self.lines[i]
      table.insert(selected, {unpack(line)})
    end

    -- Insert first selected line.
    local firstLine = self.lines[startRow]
    local tmp = {}
    for i=startCol, #firstLine do
      table.insert(tmp, firstLine[i])
    end
    table.insert(selected, 1, tmp)

    -- Insert last selected line.
    local lastLine = self.lines[endRow]
    tmp = {}
    for i=1, endCol do
      table.insert(tmp, lastLine[i])
    end
    table.insert(selected, tmp)
  end

  return selected
end

-- Format lines to fit max width.
function letters:format(font, maxWidth, init)
  init = init or 1
  for i = init, #self.lines do
    local line = self.lines[i]
    local nextLine = self.lines[i + 1]

    local initialWidth = font:getWidth(table.concat(line))
    -- Overflow: give characters to next line.
    if initialWidth > maxWidth then
      -- Insert new line
      if not nextLine then
        nextLine = {}
        table.insert(self.lines, nextLine)
      end

      repeat
        table.insert(nextLine, 1, table.remove(line))
      until font:getWidth(table.concat(line)) < maxWidth
    -- Underflow: take characters from next line.
    elseif initialWidth < maxWidth and nextLine then
      repeat
        table.insert(line, table.remove(nextLine, 1))
      until font:getWidth(table.concat(line)) > maxWidth or #nextLine == 0

      -- Remove overflowing character.
      if font:getWidth(table.concat(line)) > maxWidth then
        table.insert(nextLine, 1, table.remove(line))
      end
    end
  end

  if #self.lines > 1 then
    -- Remove empty last line.
    if #self.lines[#self.lines] == 0 then
      table.remove(self.lines)
    end
  end
end

return letters
