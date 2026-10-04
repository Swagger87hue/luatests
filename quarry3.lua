-- ============================================================
-- ATM10 STAGGERED ORE MINER
-- quarry3.lua
-- ============================================================
--
-- Creates a staggered grid:
--
--   H . H . H . H . H
--   . H . H . H . H .
--   H . H . H . H . H
--   . H . H . H . H .
--   ...
--
-- User chooses grid size when starting.
--
-- 2 = 2x2 = 4 holes
-- 3 = 3x3 = 9 holes
-- 10 = 10x10 = 100 holes
--
--
-- EACH HOLE:
--
--   1. Descend one block.
--   2. Check FRONT.
--   3. Check RIGHT.
--   4. Check BACK.
--   5. Check LEFT.
--   6. Mine anything that is NOT a bad block.
--   7. Continue downward.
--   8. Stop at bedrock.
--   9. Return to the original height.
--
--
-- BAD BLOCKS:
--
--   Are NOT mined when found in the four walls.
--
--
-- EVERYTHING ELSE:
--
--   Is mined and collected.
--
--
-- INVENTORY:
--
--   If inventory becomes full:
--     return home
--     unload non-fuel items
--     return to exact position
--     continue
--
--
-- FUEL:
--
--   Fuel items are NEVER unloaded.
--
--   If fuel is insufficient:
--     return home
--     unload
--     refuel from inventory
--     if still insufficient, wait for fuel
--     automatically detect newly added fuel
--     return to exact position
--     continue
--
--
-- START POSITION:
--
--             MINING AREA
--                  ^
--                  |
--                TURTLE
--                  |
--                 CHEST
--
--   The turtle must start at the first H.
--   The turtle must face toward the mining area.
--   The chest must be directly behind the turtle.
--
-- ============================================================


-- ============================================================
-- CONFIGURATION
-- ============================================================

-- Safety fuel reserve.
--
-- The turtle tries to keep this amount available in addition
-- to the estimated fuel required to return home.
local FUEL_RESERVE = 10

-- Status display interval.
local STATUS_DEPTH_INTERVAL = 10


-- ============================================================
-- BAD BLOCKS
--
-- Based on the list from your original repository.
--
-- Important corrections:
--
--   minecraft:endstone
--       ->
--   minecraft:end_stone
--
-- Added:
--
--   minecraft:deepslate
-- ============================================================

local badBlocks = {

    ["minecraft:cobblestone"] = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:deepslate"] = true,

    ["minecraft:netherrack"] = true,
    ["minecraft:end_stone"] = true,

    ["minecraft:stone"] = true,
    ["minecraft:dirt"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:sand"] = true,

    ["minecraft:bedrock"] = true,

    ["minecraft:flint"] = true,
    ["minecraft:rotten_flesh"] = true,

    ["minecraft:sandstone"] = true,
    ["minecraft:diorite"] = true,
    ["minecraft:andesite"] = true,

    ["chisel:limestone"] = true,
    ["chisel:diorite"] = true,
    ["chisel:marble"] = true
}


-- ============================================================
-- USER INPUT
-- ============================================================

term.clear()
term.setCursorPos(1, 1)

print("================================")
print("       ATM10 ORE MINER")
print("================================")
print("")
print("STAGGERED GRID")
print("")
print("Examples:")
print("")
print("  2  = 2 x 2  = 4 holes")
print("  3  = 3 x 3  = 9 holes")
print("  5  = 5 x 5  = 25 holes")
print("  10 = 10 x 10 = 100 holes")
print("")

write("Grid size: ")

local gridSize = tonumber(read())

if not gridSize then
    error("Invalid grid size.")
end

gridSize = math.floor(gridSize)

if gridSize < 1 then
    error("Grid size must be at least 1.")
end


local ROWS = gridSize
local HOLES_PER_ROW = gridSize
local TOTAL_HOLES = ROWS * HOLES_PER_ROW


print("")
print("--------------------------------")
print("Grid:        " .. ROWS .. " x " .. HOLES_PER_ROW)
print("Total holes: " .. TOTAL_HOLES)
print("--------------------------------")
print("")
print("Starting in 3 seconds...")
print("")

sleep(3)


-- ============================================================
-- POSITION TRACKING
-- ============================================================
--
-- Home:
--
--   x = 0
--   y = 0
--   z = 0
--
-- Direction:
--
--   0 = original direction
--   1 = right
--   2 = backwards
--   3 = left
--
-- z:
--
--   0     = starting height
--   negative = underground
--
-- ============================================================

local x = 0
local y = 0
local z = 0

local direction = 0

local currentRow = 1
local currentHole = 1
local currentDepth = 0


-- ============================================================
-- STATUS
-- ============================================================

local function status(message)

    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("       ATM10 ORE MINER")
    print("================================")
    print("")
    print(message)
    print("")
    print("Grid:       " .. ROWS .. " x " .. HOLES_PER_ROW)
    print("Total:      " .. TOTAL_HOLES)
    print("")
    print("Row:        " .. currentRow .. "/" .. ROWS)
    print("Hole:       " .. currentHole .. "/" .. HOLES_PER_ROW)
    print("Depth:      " .. currentDepth)
    print("")
    print("X:          " .. x)
    print("Y:          " .. y)
    print("Z:          " .. z)
    print("Direction:  " .. direction)
    print("")
    print("Fuel:       " .. tostring(turtle.getFuelLevel()))
    print("================================")
end


-- ============================================================
-- BAD BLOCK CHECK
-- ============================================================

local function isBadBlock(name)

    if not name then
        return true
    end

    return badBlocks[name] == true
end


-- ============================================================
-- FUEL TEST
--
-- turtle.refuel(0) tests whether the currently selected
-- item is valid fuel without consuming it.
-- ============================================================

local function isFuel(slot)

    if turtle.getItemCount(slot) == 0 then
        return false
    end

    local oldSlot = turtle.getSelectedSlot()

    turtle.select(slot)

    local result = turtle.refuel(0)

    turtle.select(oldSlot)

    return result
end


-- ============================================================
-- REFUEL FROM INVENTORY
--
-- Searches every slot.
--
-- Fuel is consumed automatically.
--
-- Non-fuel items are untouched.
-- ============================================================

local function refuelFromInventory()

    if turtle.getFuelLevel() == "unlimited" then
        return
    end

    for slot = 1, 16 do

        if turtle.getItemCount(slot) > 0 then

            if isFuel(slot) then

                turtle.select(slot)

                -- Consume this fuel stack.
                turtle.refuel()
            end
        end
    end

    turtle.select(1)
end


-- ============================================================
-- INVENTORY FULL
-- ============================================================

local function inventoryFull()

    for slot = 1, 16 do

        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end


-- ============================================================
-- TURNING
-- ============================================================

local function turnRight()

    turtle.turnRight()

    direction = (direction + 1) % 4
end


local function turnLeft()

    turtle.turnLeft()

    direction = (direction + 3) % 4
end


local function turnAround()

    turtle.turnRight()
    turtle.turnRight()

    direction = (direction + 2) % 4
end


local function face(target)

    target = target % 4

    while direction ~= target do

        local difference =
            (target - direction) % 4

        if difference == 1 then
            turnRight()
        else
            turnLeft()
        end
    end
end


-- ============================================================
-- FORWARD MOVEMENT
--
-- IMPORTANT:
--
-- This function NEVER digs.
--
-- This protects blocks while travelling horizontally.
-- ============================================================

local function forwardNoDig()

    while true do

        local success, reason = turtle.forward()

        if success then

            if direction == 0 then
                y = y + 1

            elseif direction == 1 then
                x = x + 1

            elseif direction == 2 then
                y = y - 1

            elseif direction == 3 then
                x = x - 1
            end

            return true
        end


        print("")
        print("================================")
        print("       MOVEMENT BLOCKED")
        print("================================")
        print("")
        print("The turtle will NOT dig this block.")
        print("")
        print("Reason: " .. tostring(reason))
        print("")
        print("Clear the path and the turtle")
        print("will continue automatically.")
        print("")

        sleep(2)
    end
end


-- ============================================================
-- MOVE UP
-- ============================================================

local function moveUp()

    while true do

        if turtle.up() then

            z = z + 1

            return true
        end


        -- Vertical shaft movement may clear blocks above.
        if turtle.detectUp() then
            turtle.digUp()
        end

        turtle.attackUp()

        sleep(0.25)
    end
end


-- ============================================================
-- MOVE DOWN
-- ============================================================

local function moveDown()

    while true do

        if turtle.down() then

            z = z - 1

            return true
        end


        -- Vertical shaft must be cleared.
        if turtle.detectDown() then
            turtle.digDown()
        end

        turtle.attackDown()

        sleep(0.25)
    end
end


-- ============================================================
-- DISTANCE TO HOME
-- ============================================================

local function distanceHome()

    return math.abs(x)
        + math.abs(y)
        + math.abs(z)
        + FUEL_RESERVE
end


-- ============================================================
-- ENOUGH FUEL TO RETURN?
-- ============================================================

local function enoughFuelToReturn()

    local fuel = turtle.getFuelLevel()

    if fuel == "unlimited" then
        return true
    end

    return fuel >= distanceHome()
end


-- ============================================================
-- WAIT FOR FUEL
--
-- No Enter required.
--
-- The program checks automatically every 2 seconds.
-- ============================================================

local function waitForFuel()

    while true do

        refuelFromInventory()

        local fuel = turtle.getFuelLevel()

        if fuel == "unlimited" then
            return
        end


        if fuel > FUEL_RESERVE then
            return
        end


        status("WAITING FOR FUEL")

        print("")
        print("Fuel is too low.")
        print("")
        print("Current fuel: " .. tostring(fuel))
        print("")
        print("Put fuel into the turtle.")
        print("")
        print("The turtle checks automatically.")
        print("No key press is required.")
        print("")

        sleep(2)
    end
end


-- ============================================================
-- UNLOAD
--
-- IMPORTANT:
--
-- Fuel is NEVER dropped into the chest.
--
-- Non-fuel items are dropped.
-- ============================================================

local function unload()

    status("UNLOADING")

    -- Chest is behind turtle.
    turnAround()


    for slot = 1, 16 do

        if turtle.getItemCount(slot) > 0 then

            -- Fuel stays in turtle.
            if not isFuel(slot) then

                turtle.select(slot)

                while turtle.getItemCount(slot) > 0 do

                    if turtle.drop() then
                        break
                    end


                    print("")
                    print("================================")
                    print("          CHEST FULL")
                    print("================================")
                    print("")
                    print("The turtle cannot unload.")
                    print("")
                    print("Add another chest/barrel/storage.")
                    print("")
                    print("Press ENTER to retry.")
                    print("")

                    read()
                end
            end
        end
    end


    turtle.select(1)

    -- Face mining direction again.
    turnAround()
end


-- ============================================================
-- RETURN HOME
--
-- Horizontal travel does NOT dig.
-- ============================================================

local function goHome()

    status("RETURNING HOME")


    -- --------------------------------------------------------
    -- Return to starting height.
    -- --------------------------------------------------------

    while z < 0 do
        moveUp()
    end

    while z > 0 do
        moveDown()
    end


    -- --------------------------------------------------------
    -- Return X.
    -- --------------------------------------------------------

    if x > 0 then

        face(3)

        while x > 0 do
            forwardNoDig()
        end

    elseif x < 0 then

        face(1)

        while x < 0 do
            forwardNoDig()
        end
    end


    -- --------------------------------------------------------
    -- Return Y.
    -- --------------------------------------------------------

    if y > 0 then

        face(2)

        while y > 0 do
            forwardNoDig()
        end

    elseif y < 0 then

        face(0)

        while y < 0 do
            forwardNoDig()
        end
    end


    -- --------------------------------------------------------
    -- Restore starting direction.
    -- --------------------------------------------------------

    face(0)
end


-- ============================================================
-- SERVICE TRIP
--
-- Saves exact position.
-- Goes home.
-- Unloads.
-- Refuels.
-- Waits if necessary.
-- Returns to exact position.
-- ============================================================

local function service()

    -- --------------------------------------------------------
    -- SAVE EXACT STATE
    -- --------------------------------------------------------

    local savedX = x
    local savedY = y
    local savedZ = z

    local savedDirection = direction

    local savedRow = currentRow
    local savedHole = currentHole
    local savedDepth = currentDepth


    -- --------------------------------------------------------
    -- RETURN HOME
    -- --------------------------------------------------------

    goHome()


    -- --------------------------------------------------------
    -- UNLOAD NON-FUEL ITEMS
    -- --------------------------------------------------------

    unload()


    -- --------------------------------------------------------
    -- REFUEL
    -- --------------------------------------------------------

    refuelFromInventory()


    -- --------------------------------------------------------
    -- WAIT FOR MORE FUEL IF REQUIRED
    -- --------------------------------------------------------

    if turtle.getFuelLevel() ~= "unlimited" then

        if turtle.getFuelLevel() <= FUEL_RESERVE then

            waitForFuel()
        end
    end


    -- --------------------------------------------------------
    -- RETURN TO SAVED X
    -- --------------------------------------------------------

    if savedX > 0 then

        face(1)

        for i = 1, savedX do
            forwardNoDig()
        end

    elseif savedX < 0 then

        face(3)

        for i = 1, math.abs(savedX) do
            forwardNoDig()
        end
    end


    -- --------------------------------------------------------
    -- RETURN TO SAVED Y
    -- --------------------------------------------------------

    if savedY > 0 then

        face(0)

        for i = 1, savedY do
            forwardNoDig()
        end

    elseif savedY < 0 then

        face(2)

        for i = 1, math.abs(savedY) do
            forwardNoDig()
        end
    end


    -- --------------------------------------------------------
    -- RETURN TO SAVED DEPTH
    -- --------------------------------------------------------

    if savedZ < 0 then

        for i = 1, math.abs(savedZ) do
            moveDown()
        end

    elseif savedZ > 0 then

        for i = 1, savedZ do
            moveUp()
        end
    end


    -- --------------------------------------------------------
    -- RESTORE STATE
    -- --------------------------------------------------------

    face(savedDirection)

    currentRow = savedRow
    currentHole = savedHole
    currentDepth = savedDepth


    status("RESUMING")
end


-- ============================================================
-- RESOURCE CHECK
-- ============================================================

local function checkResources()

    -- --------------------------------------------------------
    -- Try to refuel from inventory first.
    -- --------------------------------------------------------

    refuelFromInventory()


    -- --------------------------------------------------------
    -- Inventory full.
    -- --------------------------------------------------------

    if inventoryFull() then

        service()

        return
    end


    -- --------------------------------------------------------
    -- Fuel too low to safely return.
    -- --------------------------------------------------------

    if not enoughFuelToReturn() then

        service()

        return
    end
end


-- ============================================================
-- MINE ONE WALL BLOCK
-- ============================================================
--
-- Turtle is facing the wall.
--
-- BAD BLOCK:
--     leave untouched.
--
-- ANYTHING ELSE:
--     mine.
--
-- ============================================================

local function mineWall()

    local found, data = turtle.inspect()

    if not found then
        return
    end


    local blockName = data.name


    -- Protected block.
    if isBadBlock(blockName) then
        return
    end


    -- Everything else is considered valuable.
    turtle.dig()
end


-- ============================================================
-- CHECK ALL FOUR WALLS
-- ============================================================

local function checkFourWalls()

    local originalDirection = direction


    -- FRONT
    mineWall()


    -- RIGHT
    turnRight()
    mineWall()


    -- BACK
    turnRight()
    mineWall()


    -- LEFT
    turnRight()
    mineWall()


    -- Restore original direction.
    face(originalDirection)
end


-- ============================================================
-- MINE ONE VERTICAL HOLE
-- ============================================================

local function mineHole()

    currentDepth = 0


    status(
        "MINING HOLE " ..
        currentHole ..
        "/" ..
        HOLES_PER_ROW
    )


    while true do

        -- ----------------------------------------------------
        -- Check fuel/inventory before continuing.
        -- ----------------------------------------------------

        checkResources()


        -- ----------------------------------------------------
        -- Inspect block below.
        -- ----------------------------------------------------

        local found, data =
            turtle.inspectDown()


        -- ----------------------------------------------------
        -- Bedrock reached.
        -- ----------------------------------------------------

        if found and data.name == "minecraft:bedrock" then

            break
        end


        -- ----------------------------------------------------
        -- Clear the shaft below.
        --
        -- The shaft MUST reach bedrock.
        -- ----------------------------------------------------

        if turtle.detectDown() then

            turtle.digDown()
        end


        -- ----------------------------------------------------
        -- Move down.
        -- ----------------------------------------------------

        moveDown()

        currentDepth = math.abs(z)


        -- ----------------------------------------------------
        -- Check four walls.
        -- ----------------------------------------------------

        checkFourWalls()


        -- ----------------------------------------------------
        -- Progress display.
        -- ----------------------------------------------------

        if currentDepth % STATUS_DEPTH_INTERVAL == 0 then

            status(
                "MINING HOLE " ..
                currentHole ..
                " - DEPTH " ..
                currentDepth
            )
        end
    end


    -- ========================================================
    -- BEDROCK
    -- ========================================================

    status("BEDROCK REACHED")


    -- Return to starting height.
    while z < 0 do
        moveUp()
    end


    currentDepth = 0
end


-- ============================================================
-- MOVE TO NEXT HOLE
--
-- Holes are two blocks apart.
--
-- H . H
-- ^   ^
-- |   |
-- 2 blocks
-- ============================================================

local function moveToNextHole()

    forwardNoDig()
    forwardNoDig()
end


-- ============================================================
-- MOVE TO NEXT ROW
--
-- This creates the required stagger.
--
-- Row 1:
--
-- H . H . H
--
-- Row 2:
--
-- . H . H .
--
-- Row 3:
--
-- H . H . H
--
--
-- The row offset is ONE block.
--
-- ============================================================

local function moveToNextRow(row)

    -- Move one block beyond the last hole.
    forwardNoDig()


    if row % 2 == 1 then

        -- ----------------------------------------------------
        -- Odd -> Even
        -- ----------------------------------------------------

        turnRight()

        forwardNoDig()

        turnRight()

    else

        -- ----------------------------------------------------
        -- Even -> Odd
        -- ----------------------------------------------------

        turnLeft()

        forwardNoDig()

        turnLeft()
    end
end


-- ============================================================
-- MAIN
-- ============================================================

local function main()

    -- ========================================================
    -- STARTUP REFUEL
    -- ========================================================

    refuelFromInventory()


    -- If starting fuel is very low, wait BEFORE moving.
    if turtle.getFuelLevel() ~= "unlimited" then

        if turtle.getFuelLevel() <= FUEL_RESERVE then

            status("STARTUP - WAITING FOR FUEL")

            print("")
            print("Put fuel into the turtle.")
            print("")
            print("The turtle will detect it automatically.")
            print("")

            waitForFuel()
        end
    end


    -- ========================================================
    -- START
    -- ========================================================

    status("STARTING")

    sleep(2)


    -- ========================================================
    -- ROWS
    -- ========================================================

    for row = 1, ROWS do

        currentRow = row


        -- ====================================================
        -- HOLES
        -- ====================================================

        for hole = 1, HOLES_PER_ROW do

            currentHole = hole


            -- ------------------------------------------------
            -- Mine complete vertical hole.
            -- ------------------------------------------------

            mineHole()


            -- ------------------------------------------------
            -- Move to next hole.
            -- ------------------------------------------------

            if hole < HOLES_PER_ROW then

                checkResources()

                moveToNextHole()
            end
        end


        -- ====================================================
        -- NEXT ROW
        -- ====================================================

        if row < ROWS then

            checkResources()

            moveToNextRow(row)
        end
    end


    -- ========================================================
    -- ALL HOLES COMPLETE
    -- ========================================================

    status(
        "COMPLETE - " ..
        TOTAL_HOLES ..
        " HOLES"
    )

    sleep(2)


    -- ========================================================
    -- RETURN HOME
    -- ========================================================

    goHome()


    -- ========================================================
    -- FINAL UNLOAD
    -- ========================================================

    unload()


    -- ========================================================
    -- FINAL REFUEL
    -- ========================================================

    refuelFromInventory()


    -- ========================================================
    -- DONE
    -- ========================================================

    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("       MINING COMPLETE")
    print("================================")
    print("")
    print("Grid:  " .. ROWS .. " x " .. HOLES_PER_ROW)
    print("Holes: " .. TOTAL_HOLES)
    print("")
    print("Turtle is home.")
    print("Inventory unloaded.")
    print("")
end


-- ============================================================
-- ERROR HANDLER
-- ============================================================

local function emergencyStop()

    print("")
    print("================================")
    print("        PROGRAM ERROR")
    print("================================")
    print("")
    print("The program stopped unexpectedly.")
    print("")
    print("Current position:")
    print("X: " .. x)
    print("Y: " .. y)
    print("Z: " .. z)
    print("")
    print("Row: " .. currentRow)
    print("Hole: " .. currentHole)
    print("Depth: " .. currentDepth)
    print("")
    print("Fuel: " .. tostring(turtle.getFuelLevel()))
    print("")
end


-- ============================================================
-- RUN
-- ============================================================

local success, errorMessage =
    xpcall(main, debug.traceback)


if not success then

    print("")
    print(errorMessage)

    emergencyStop()
end
