do

  -- Helpers -----

  local _ENV         = _ENV or _G
  local getmetatable = _ENV.getmetatable
  local setmetatable = _ENV.setmetatable
  local tonumber     = _ENV.tonumber
  local error        = _ENV.error
  local ipairs       = _ENV.ipairs
  local next         = _ENV.next
  local type         = _ENV.type

  local insert = table.insert
  local _remove = table.remove

  local addImage    = tfm.exec.addImage
  local removeImage = tfm.exec.removeImage

  local addTextArea    = ui.addTextArea
  local removeTextArea = ui.removeTextArea
  local updateTextArea = ui.updateTextArea

  local function extend(target, ...)
    for i, copy in ipairs { ... } do
      if type(copy) == 'table' then
        for k, v in next, copy do
          target[k] = v
        end
      end
    end
    return target
  end

  local function find(value, t)
    for i, another in ipairs(t) do
      if value == another then
        return i
      end
    end
  end

  -- ### Simple classing

  local function createClass()
    return { meta = {} }
  end

  local function dropInstanceOf(class)
    return setmetatable({}, class.meta)
  end

  local function setConstructorOf(class, func)
    local mt = getmetatable(class) or {}
    mt.__call = func
    setmetatable(class, mt)
  end

  local function setPrototypeOf(class, p)
    class.meta.__index = p
  end

  local function isInstanceOf(class, value)
    return getmetatable(value) == class.meta
  end

  -- Display: helpers and objects -----

  local Image, TextArea

  local build
  local clone
  local top
  local update

  local curImgLayer
  local curParent
  local curTarget

  local parentAlpha
  local parentFixed
  local parentRemoved

  local txaCounter = 0

  function build(obj, target)
    obj = clone(obj)
    obj.target = target
    return obj
  end

  function clone(obj)
    local objClone = extend({}, obj)
    local children = obj.children

    if type(children) == 'table' then
      local childrenClone = {}

      for i, child in ipairs(children) do

        local childClone = clone(child)
        childrenClone[i] = childClone
        childClone.parent = objClone
      end

      objClone.children = childrenClone
    end

    objClone.origin = obj

    return setmetatable(objClone, getmetatable(obj))
  end

  function top(obj)
    while true do
      local p = obj.parent
      if not p then
        return obj
      end
      obj = p
    end
  end

  local function borderTextArea(x, y, w, h, background, color, alpha, fixed, config)
    addTextArea(id, obj.html or '', target, x, y, w, h, background, border, alpha, fixed)
  end

  function update(obj)
    if obj.display == false and not obj._removed then
      return obj
    end

    local target = curTarget or top(obj).target

    -- Images do have a layer counter.

    if isInstanceOf(Image, obj) then
      local imgLayerInit = not curImgLayer
      curImgLayer = curImgLayer or 1

      if obj._removed then
        removeImage(obj._id)
        return obj
      end
      obj._id = addImage(obj.id, '&'..curImgLayer, obj.x, obj.y, target)

      if imgLayerInit then
        curImgLayer = nil

      elseif curImgLayer < 9 then
        curImgLayer = curImgLayer + 1
      end

    elseif isInstanceOf(TextArea, obj) then

      local curParentInit = not curParent

      local removed = obj._removed or parentRemoved

      if removed then

        removeTextArea(obj._id, target)

        -- Remove display of the borders
        local border = obj._border
        if border then
          for id in next, border do
            removeTextArea(id, target)
          end
          obj._border = nil
        end

      else

        local x = tonumber(obj.x) or 0
        local y = tonumber(obj.y) or 0

        local w = tonumber(obj.width) or 0
        local h = tonumber(obj.height) or 0

        w = (w < 10) and 10 or w
        h = (h < 10) and 10 or h

        local alpha = obj.alpha
        local fixed = obj.fixed

        -- Children text areas can inherit parent's alpha and fixed
        -- properties.

        if (curParent) and obj.inherit ~= false then
          alpha = alpha or parentAlpha
          fixed = fixed or parentFixed
        end

        -- (default) fixed = true

        fixed = fixed == nil or fixed

        local background = tonumber(obj.background) or 0x324650
        local border = obj.border

        x = x - (w / 2)
        y = y - (h / 2)

        -- Configured-border

        if type(border) == 'table' then

          x = x + 2
          y = y + 2
          w = w - 4
          h = h - 4

          local ids = {}
          local length = border[1] or 0

          if length > 0 then

            local isAffectedLength = length <3
            local j, mj

            if isAffectedLength then
              j = (length == 2) and 1 or 2
              mj = j * 2
              length = 3
              x = x + j
              y = y + j
              w = w - mj
              h = h - mj
            end

            local leftColor, topColor, rightColor, bottomColor

            if (#border) == 3 then
              leftColor = tonumber(border[2]) or 1
              leftColor = (leftColor < 1) and 1 or leftColor
              rightColor = tonumber(border[3]) or leftColor
              rightColor = (rightColor < 1) and 1 or rightColor
              topColor = leftColor
              bottomColor = rightColor
            else
              leftColor = tonumber(border[2]) or 1
              leftColor = (leftColor < 1) and 1 or leftColor
              topColor = tonumber(border[3]) or leftColor
              topColor = (topColor < 1) and 1 or topColor
              rightColor = tonumber(border[4]) or topColor
              rightColor = (rightColor < 1) and 1 or rightColor
              bottomColor = tonumber(border[5]) or topColor
              bottomColor = (bottomColor < 1) and 1 or bottomColor
            end

            local defs = { leftColor, topColor, rightColor, bottomColor }

            for i = 1, 4 do
              local color = defs[i]
              local bx, by, bw, bh

              -- Vertical (left or right)
              if (i % 2) == 1 then
                bw = length
                bh = h + (length * 2)
                bx = (i == 1) and (x - bw) or (x + w)
                by = y - length

              -- Horizontal (top or bottom)
              else
                bw = w + (length * 2)
                bh = length
                bx = x - length
                by = (i == 2) and (y - bh) or (y + h)
              end

              addTextArea(txaCounter, '', target, bx, by, bw, bh,
                color, color, alpha, fixed)

              ids[txaCounter] = true
              txaCounter = txaCounter + 1
            end

            if isAffectedLength then
              x = x - j
              y = y - j
              w = w + mj
              h = h + mj
            end
          end

          border = background
          obj._border = ids
        else
          border = tonumber(border) or 1
        end

        local id = obj._id

        if not id then
          id = txaCounter
          obj._id = id
          txaCounter = txaCounter + 1
        end

        addTextArea(id, obj.html or '', target, x, y, w, h, background, border, alpha, fixed)
      end

      curParent = obj

      parentAlpha = alpha
      parentFixed = fixed
      parentRemoved = removed

      local children = obj.children

      if type(children) == 'table' then
        local targetInit = not curTarget
        curTarget = target

        local order = {}
        local len = 0

        for i, child in ipairs(children) do
          len = len + 1
          local z = tonumber(child.z) or len
          z = ((z > len) and len) or ((z < 1) and 1) or z
          insert(order, z, child)
        end

        for i, child in ipairs(order) do
          update(child, fixed, alpha, removed)
        end

        if targetInit then
          curTarget = nil
        end
      end

      if curParentInit then
        curParent = nil
        parentAlpha = nil
        parentFixed = nil
        parentRemoved = nil
      end
    end
    return obj
  end

  local function updateHTML(textArea)
    if not isInstanceOf(TextArea, textArea) then
      return textArea
    end

    local curTargetInit = not curTarget

    curTarget = curTarget or top(textArea).target
    updateTextArea(textArea._id, textArea.html or '', curTarget)

    local children = textArea.children

    if children then
      for i, child in ipairs(children) do
        updateHTML(child)
      end
    end

    return textArea
  end

  local function remove(obj)
    obj._removed = true
    return obj
  end

  -- ### `Image`

  local propSequence =
    { 'id', 'x', 'y' }

  Image = createClass()

  setConstructorOf(Image, function(Image, ...)
    local self = dropInstanceOf(Image)

    for i, arg in ipairs { ... } do
      local prop = propSequence[i]

      if not prop or type(arg) == 'table' then
        extend(self, arg)
      else
        self[prop] = arg
      end
    end

    return self
  end)

  setPrototypeOf(Image, {
      build = build
    , clone = clone
    , remove = remove
    , top = top
    , update = update
  })

  -- ### `TextArea`

  local propSequence =
    { 'x', 'y', 'width', 'height' }

  TextArea = createClass()

  setConstructorOf(TextArea, function(TextArea, ...)
    local self = dropInstanceOf(TextArea)

    for i, arg in ipairs { ... } do
      local prop = propSequence[i]

      if not prop or type(arg) == 'table' then
        extend(self, arg)
      else
        self[prop] = arg
      end
    end

    return self
  end)

  local function findCloneOf(obj, orig)
    local children = obj.children
    if children then
      for i, child in ipairs(obj.children) do
        if child.origin == orig then
          return child
        end
        local inner = findCloneOf(child, orig)
        if inner then
          return inner
        end
      end
    end
  end

  local function removeChild(obj, ...)
    local children = obj.children

    if children then

      for _, target in ipairs { ... } do
        for i, child in ipairs(children) do
          if child == target then
            _remove(target, i)
            break
          else
            removeChild(child, target)
          end
        end
      end

      if #children == 0 then
        obj.children = nil
      end
    end

    return obj
  end
  
  setPrototypeOf(TextArea, {

      addChild = function(self, ...)
        local children = self.children or {}
        self.children = children

        for i, newChild in ipairs { ... } do
          children[#children + 1] = newChild
        end

        return self
      end

    , build = build
    , clone = clone
    , findCloneOf = findCloneOf
    , remove = remove
    , removeChild = removeChild
    , top = top
    , update = update
    , updateHTML = updateHTML
  })

  txshop = {
      Image    = Image
    , TextArea = TextArea
  }
end
