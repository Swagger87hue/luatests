-- ============================================================
-- ATM10 STAGGERED ORE MINER
-- ============================================================
--
-- Creates a staggered grid of vertical mining holes.
--
-- Example with grid size 5:
--
-- Row 1: H . H . H . H . H
-- Row 2: . H . H . H . H .
-- Row 3: H . H . H . H . H
-- Row 4: . H . H . H . H .
-- Row 5: H . H . H . H . H
--
-- Each H is mined vertically down to BEDROCK.
--
-- At every depth the turtle checks all four horizontal
-- directions.
--
-- BAD BLOCKS:
--     left in place
--
-- EVERYTHING ELSE:
--     mined and collected
--
-- If inventory becomes full:
--     return home
--     unload
--     return to exact position
--     continue
--
-- If fuel becomes too low to safely return:
--     return home
--     unload
--     wait for fuel
--     return to exact position
--     continue
--
-- STARTING POSITION:
--
--       MINING AREA
--           ^
--           |
--        TURTLE
--           |
--          CHEST
--
-- The turtle starts at the first H of row 1.
-- It must face the mining direction.
-- The chest must be directly BEHIND the turtle.
--
-- ============================================================


-- ============================================================
-- USER CONFIGURATION
-- ============================================================

-- Fuel safety margin.
--
-- The turtle will return before it gets dangerously low.
local FUEL_RESERVE = 10

-- How often depth information is displayed.
local STATUS_DEPTH_INTERVAL = 10


-- ============================================================
-- BAD BLOCKS
--
-- Based on the badBlocks list from your original repository.
--
-- These blocks are NOT mined when encountered in the walls.
-- ============================================================

local badBlocks = {

    -- Minecraft
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

    -- Chisel
    ["chisel:limestone"] = true,
    ["chisel:diorite"] = true,
    ["chisel:marble"] = true
}


-- ============================================================
-- ASK USER FOR GRID SIZE
-- ============================================================

term.clear()
term.setCursorPos(1, 1)

print("================================")
print("      ATM10 ORE MINER")
print("================================")
print("")
print("Staggered mining grid")
print("")
print("Example:")
print("  2 = 2 x 2 = 4 holes")
print("  5 = 5 x 5 = 25 holes")
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
print("Grid size: " .. gridSize .. " x " .. gridSize)
print("Total holes: " .. TOTAL_HOLES)
print("")

print("Starting in 3 seconds...")
sleep(3)


-- ============================================================
-- POSITION TRACKING
-- ============================================================
--
-- Home position:
--
-- x = 0
-- y = 0
-- z = 0
--
-- Direction:
--
-- 0 = original direction
-- 1 = right
-- 2 = backwards
-- 3 = left
--
-- z:
--
-- 0 = starting height
-- negative = underground
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
-- STATUS DISPLAY
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
-- BAD BLOCK TEST
-- ============================================================

local function isBadBlock(name)

    if not name then
        return true
    end

    return badBlocks[name] == true
end


-- ============================================================
-- INVENTORY
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
-- This function does NOT dig.
--
-- This prevents the turtle from destroying protected blocks
-- while travelling between holes.
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
        print("Movement blocked.")
        print("Reason: " .. tostring(reason))
        print("")
        print("The turtle will NOT dig this block.")
        print("Waiting for the path to be cleared.")
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

        -- Vertical movement is part of the mining shaft.
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
-- DISTANCE HOME
-- ============================================================

local function distanceHome()

    return math.abs(x)
        + math.abs(y)
        + math.abs(z)
        + FUEL_RESERVE
end


-- ============================================================
-- FUEL CHECK
-- ============================================================

local function enoughFuelToReturn()

    local fuel = turtle.getFuelLevel()

    -- Some worlds/turtles can report unlimited.
    if fuel == "unlimited" then
        return true
    end

    return fuel >= distanceHome()
end


-- ============================================================
-- WAIT FOR FUEL
-- ============================================================

local function waitForFuel()

    while true do

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
        print("Add fuel to the turtle.")
        print("Press ENTER when finished.")
        print("")

        read()
    end
end


-- ============================================================
-- UNLOAD INVENTORY
--
-- Chest must be directly behind the turtle at home.
-- ============================================================

local function unload()

    status("UNLOADING")

    -- Turn toward chest.
    turnAround()

    for slot = 1, 16 do

        if turtle.getItemCount(slot) > 0 then

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
                print("Add more storage.")
                print("Press ENTER to retry.")
                print("")

                read()
            end
        end
    end

    turtle.select(1)

    -- Face mining direction again.
    turnAround()
end


-- ============================================================
-- RETURN HOME
-- ============================================================
--
-- IMPORTANT:
--
-- Horizontal travel NEVER digs.
--
-- The turtle assumes the path back to the starting point
-- is clear.
--
-- ============================================================

local function goHome()

    status("RETURNING HOME")

    -- --------------------------------------------------------
    -- First return to starting Y level.
    -- --------------------------------------------------------

    while z < 0 do
        moveUp()
    end

    while z > 0 do
        moveDown()
    end


    -- --------------------------------------------------------
    -- Return X coordinate to zero.
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
    -- Return Y coordinate to zero.
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
-- Returns to exact position.
-- ============================================================

local function service()

    -- Save everything needed to resume.

    local savedX = x
    local savedY = y
    local savedZ = z
    local savedDirection = direction

    local savedRow = currentRow
    local savedHole = currentHole
    local savedDepth = currentDepth


    -- --------------------------------------------------------
    -- Return home.
    -- --------------------------------------------------------

    goHome()


    -- --------------------------------------------------------
    -- Unload.
    -- --------------------------------------------------------

    unload()


    -- --------------------------------------------------------
    -- Wait for fuel if required.
    -- --------------------------------------------------------

    waitForFuel()


    -- --------------------------------------------------------
    -- Return to saved X.
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
    -- Return to saved Y.
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
    -- Return to saved depth.
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
    -- Restore exact direction/state.
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
    -- Inventory.
    -- --------------------------------------------------------

    if inventoryFull() then

        service()

        return
    end


    -- --------------------------------------------------------
    -- Fuel.
    -- --------------------------------------------------------

    if not enoughFuelToReturn() then

        service()

        return
    end
end


-- ============================================================
-- MINE ONE WALL
--
-- Turtle is facing the wall.
--
-- If the block is bad:
--     leave it
--
-- If the block is anything else:
--     mine it
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


    -- Valuable/unknown block.
    turtle.dig()
end


-- ============================================================
-- CHECK ALL FOUR DIRECTIONS
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

        checkResources()


        -- ----------------------------------------------------
        -- Look below.
        -- ----------------------------------------------------

        local found, data =
            turtle.inspectDown()


        -- ----------------------------------------------------
        -- Bedrock means this hole is complete.
        -- ----------------------------------------------------

        if found and data.name == "minecraft:bedrock" then

            break
        end


        -- ----------------------------------------------------
        -- Mine the block below.
        --
        -- The vertical shaft itself MUST be cleared.
        -- ----------------------------------------------------

        if turtle.detectDown() then

            turtle.digDown()
        end


        -- ----------------------------------------------------
        -- Move down one block.
        -- ----------------------------------------------------

        moveDown()

        currentDepth = math.abs(z)


        -- ----------------------------------------------------
        -- Check the four surrounding walls.
        -- ----------------------------------------------------

        checkFourWalls()


        -- ----------------------------------------------------
        -- Display progress periodically.
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
    -- BEDROCK REACHED
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
-- THIS CREATES THE STAGGERED PATTERN.
--
-- Example:
--
-- Row 1:
-- H . H . H
--
-- Row 2:
-- . H . H .
--
-- Row 3:
-- H . H . H
--
--
-- At the end of a row:
--
-- 1. Move one block forward.
-- 2. Turn toward the new row.
-- 3. Move ONE block sideways.
-- 4. Turn again.
--
-- The sideways distance MUST be 1.
--
-- This is what creates the offset of exactly one block.
-- ============================================================

local function moveToNextRow(row)

    -- Move one block beyond the last hole.
    forwardNoDig()


    if row % 2 == 1 then

        -- ----------------------------------------------------
        -- Odd row -> next row.
        --
        -- Turn right.
        -- Move one block sideways.
        -- Turn right.
        -- ----------------------------------------------------

        turnRight()

        forwardNoDig()

        turnRight()

    else

        -- ----------------------------------------------------
        -- Even row -> next row.
        --
        -- Turn left.
        -- Move one block sideways.
        -- Turn left.
        -- ----------------------------------------------------

        turnLeft()

        forwardNoDig()

        turnLeft()
    end
end


-- ============================================================
-- MAIN PROGRAM
-- ============================================================

local function main()

    status("STARTING")

    sleep(2)


    -- ========================================================
    -- PROCESS EVERY ROW
    -- ========================================================

    for row = 1, ROWS do

        currentRow = row


        -- ====================================================
        -- PROCESS EVERY HOLE IN THIS ROW
        -- ====================================================

        for hole = 1, HOLES_PER_ROW do

            currentHole = hole


            -- ------------------------------------------------
            -- Mine entire vertical hole.
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
        -- MOVE TO NEXT ROW
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
    -- UNLOAD FINAL INVENTORY
    -- ========================================================

    unload()


    -- ========================================================
    -- FINISHED
    -- ========================================================

    term.clear()
    term.setCursorPos(1, 1)

    print("================================")
    print("       MINING COMPLETE")
    print("================================")
    print("")
    print("Grid: " .. ROWS .. " x " .. HOLES_PER_ROW)
    print("Holes: " .. TOTAL_HOLES)
    print("")
    print("Turtle is back at home.")
    print("Inventory unloaded.")
    print("")
end


-- ============================================================
-- ERROR HANDLING
-- ============================================================

local function emergencyStop()

    print("")
    print("================================")
    print("        PROGRAM ERROR")
    print("================================")
    print("")
    print("The program stopped because of")
    print("an unexpected error.")
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
end


-- ============================================================
-- START
-- ============================================================

local success, errorMessage =
    xpcall(main, debug.traceback)


if not success then

    print(errorMessage)

    emergencyStop()
end
