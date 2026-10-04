-- ============================================================
-- ATM10 STAGGERED ORE MINER
-- quarry3.lua
-- ============================================================
--
-- GRID PATTERN:
--
-- H . H . H . H
-- . H . H . H .
-- H . H . H . H
-- . H . H . H .
--
-- Each H is a vertical shaft to bedrock.
--
-- The turtle checks the four sides of every shaft.
--
-- BAD BLOCKS are left in the walls.
--
-- ALLTHEMODIUM is also treated as a bad block.
-- When detected, the hole number is recorded and displayed.
--
-- Example:
--
-- Allthemodium: 1, 5, 13, 25
--
-- means Allthemodium was found while checking holes
-- 1, 5, 13 and 25.
--
-- SLOT 1:
--     CHARCOAL ONLY
--
-- SLOTS 2-16:
--     MINED MATERIALS
--
-- HOME:
--
--     Turtle faces mining area.
--     Chest is directly behind turtle.
--
-- When servicing:
--
--     return home
--     turn once toward chest
--     unload
--     refill charcoal
--     refuel
--     turn once toward mining area
--     return to exact position
--
-- ============================================================


-- ============================================================
-- CONFIGURATION
-- ============================================================

local FUEL_RESERVE = 20
local STATUS_DEPTH_INTERVAL = 10

local FUEL_SLOT = 1
local FUEL_STACK_SIZE = 64

local CHARCOAL_NAME = "minecraft:charcoal"


-- ============================================================
-- BAD BLOCKS
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
    ["chisel:marble"] = true,

    -- ========================================================
    -- ALLTHEMODIUM
    --
    -- These must NEVER be mined by the turtle.
    -- ========================================================

    ["allthemodium:allthemodium_ore"] = true,
    ["allthemodium:allthemodium_slate_ore"] = true
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
print("STAGGERED MINING GRID")
print("")
print("2  = 2 x 2  = 4 holes")
print("3  = 3 x 3  = 9 holes")
print("5  = 5 x 5  = 25 holes")
print("10 = 10 x 10 = 100 holes")
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

-- Home:
--
-- x = 0
-- y = 0
-- z = 0
--
-- Direction:
--
-- 0 = original / mining direction
-- 1 = right
-- 2 = backwards / chest direction
-- 3 = left

local x = 0
local y = 0
local z = 0

local direction = 0

local currentRow = 1
local currentHole = 1
local currentDepth = 0


-- ============================================================
-- ALLTHEMODIUM TRACKING
-- ============================================================

-- We store hole numbers here.
--
-- Example:
--
-- allthemodiumFound[1] = true
-- allthemodiumFound[5] = true
--
-- This prevents the same hole from appearing multiple times.

local allthemodiumFound = {}


local function getCurrentHoleNumber()

    return
        ((currentRow - 1) * HOLES_PER_ROW)
        + currentHole
end


local function recordAllthemodium()

    local holeNumber =
        getCurrentHoleNumber()

    if not allthemodiumFound[holeNumber] then

        allthemodiumFound[holeNumber] = true
    end
end


local function getAllthemodiumList()

    local result = {}

    for hole = 1, TOTAL_HOLES do

        if allthemodiumFound[hole] then

            table.insert(
                result,
                tostring(hole)
            )
        end
    end

    if #result == 0 then
        return "NONE"
    end

    return table.concat(result, ", ")
end


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

    if turtle.getFuelLevel() ~= "unlimited" then
        print("Fuel max:   " .. tostring(turtle.getFuelLimit()))
    end

    print("")
    print("Charcoal:   " .. turtle.getItemCount(FUEL_SLOT))
    print("")

    -- ========================================================
    -- ALLTHEMODIUM RESULT
    -- ========================================================

    print("Allthemodium:")
    print(getAllthemodiumList())

    print("")
    print("================================")
end


-- ============================================================
-- BAD BLOCK
-- ============================================================

local function isBadBlock(name)

    if not name then
        return true
    end

    return badBlocks[name] == true
end


-- ============================================================
-- ALLTHEMODIUM BLOCK
-- ============================================================

local function isAllthemodium(name)

    if not name then
        return false
    end

    return
        name == "allthemodium:allthemodium_ore"
        or
        name == "allthemodium:allthemodium_slate_ore"
end


-- ============================================================
-- FUEL SLOT
-- ============================================================

local function verifyFuelSlot()

    local item =
        turtle.getItemDetail(FUEL_SLOT)

    if not item then
        return true
    end

    if item.name ~= CHARCOAL_NAME then

        print("")
        print("================================")
        print("       FUEL SLOT ERROR")
        print("================================")
        print("")
        print("Slot 1 must contain CHARCOAL only.")
        print("")
        print("Current item:")
        print(item.name)
        print("")
        print("Remove it from slot 1.")
        print("Put charcoal in slot 1.")
        print("")
        print("Press ENTER when fixed.")
        print("")

        read()

        return verifyFuelSlot()
    end

    return true
end


-- ============================================================
-- TURNING
-- ============================================================

local function turnRight()

    turtle.turnRight()

    direction =
        (direction + 1) % 4
end


local function turnLeft()

    turtle.turnLeft()

    direction =
        (direction + 3) % 4
end


local function turnAround()

    turtle.turnRight()
    turtle.turnRight()

    direction =
        (direction + 2) % 4
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
-- HORIZONTAL MOVEMENT
--
-- NEVER DIGS.
-- ============================================================

local function forwardNoDig()

    while true do

        local success, reason =
            turtle.forward()

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
        print("The turtle will NOT dig.")
        print("")
        print("Reason: " .. tostring(reason))
        print("")
        print("Clear the path.")
        print("")
        print("Continuing automatically...")
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

        if turtle.detectDown() then
            turtle.digDown()
        end

        turtle.attackDown()

        sleep(0.25)
    end
end


-- ============================================================
-- HOME DISTANCE
-- ============================================================

local function distanceHome()

    return
        math.abs(x)
        + math.abs(y)
        + math.abs(z)
        + FUEL_RESERVE
end


local function enoughFuelToReturn()

    local fuel =
        turtle.getFuelLevel()

    if fuel == "unlimited" then
        return true
    end

    return fuel >= distanceHome()
end


-- ============================================================
-- REFUEL
-- ============================================================

local function refuelToTarget(targetFuel)

    if turtle.getFuelLevel() == "unlimited" then
        return true
    end

    verifyFuelSlot()

    local fuel =
        turtle.getFuelLevel()

    if fuel >= targetFuel then
        return true
    end

    local fuelLimit =
        turtle.getFuelLimit()

    if targetFuel > fuelLimit then
        targetFuel = fuelLimit
    end

    if turtle.getItemCount(FUEL_SLOT) <= 0 then
        return false
    end

    turtle.select(FUEL_SLOT)

    while turtle.getFuelLevel() < targetFuel do

        if turtle.getItemCount(FUEL_SLOT) <= 0 then
            break
        end

        local beforeFuel =
            turtle.getFuelLevel()

        local beforeCount =
            turtle.getItemCount(FUEL_SLOT)

        turtle.refuel(1)

        local afterFuel =
            turtle.getFuelLevel()

        local afterCount =
            turtle.getItemCount(FUEL_SLOT)

        if afterFuel <= beforeFuel
           and afterCount >= beforeCount then

            break
        end
    end

    turtle.select(FUEL_SLOT)

    return turtle.getFuelLevel() >= targetFuel
end


-- ============================================================
-- TOP UP CHARCOAL
--
-- PRECONDITION:
-- Turtle is facing chest.
--
-- DOES NOT TURN.
--
-- The current repository version expects charcoal to be
-- accessible from the front chest.
-- ============================================================

local function topUpCharcoalFromChest()

    verifyFuelSlot()

    local current =
        turtle.getItemCount(FUEL_SLOT)

    if current >= FUEL_STACK_SIZE then
        return true
    end

    local needed =
        FUEL_STACK_SIZE - current


    status(
        "REFILLING CHARCOAL (" ..
        needed ..
        " NEEDED)"
    )


    local chest =
        peripheral.wrap("front")


    if not chest then

        print("")
        print("================================")
        print("       CHEST NOT FOUND")
        print("================================")
        print("")
        print("The turtle should be facing")
        print("the home chest.")
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- Find charcoal.
    -- --------------------------------------------------------

    local charcoalSlot = nil
    local chestItems = chest.list()

    for slot, item in pairs(chestItems) do

        if item.name == CHARCOAL_NAME then

            charcoalSlot = slot
            break
        end
    end


    if not charcoalSlot then

        print("")
        print("================================")
        print("      NO CHARCOAL IN CHEST")
        print("================================")
        print("")
        print("Current charcoal:")
        print(current)
        print("")
        print("Needed:")
        print(needed)
        print("")
        print("Put charcoal into the chest.")
        print("")
        print("Checking again...")
        print("")

        sleep(2)

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- IMPORTANT:
    --
    -- turtle.suck() pulls from the front chest.
    --
    -- To make the transfer deterministic, the charcoal stack
    -- must be in the front chest's first available position
    -- used by the turtle.
    --
    -- If charcoal is already in slot 1, take only what is
    -- required.
    -- --------------------------------------------------------

    if charcoalSlot ~= 1 then

        print("")
        print("================================")
        print("       CHARCOAL LOCATION")
        print("================================")
        print("")
        print("Charcoal was found in chest slot:")
        print(charcoalSlot)
        print("")
        print("Move the charcoal stack to")
        print("chest slot 1.")
        print("")
        print("This prevents the turtle from")
        print("accidentally taking another item.")
        print("")
        print("Press ENTER when done.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    local available =
        chestItems[1].count

    local takeAmount =
        math.min(
            needed,
            available
        )


    if takeAmount <= 0 then
        return false
    end


    turtle.select(FUEL_SLOT)

    local before =
        turtle.getItemCount(FUEL_SLOT)


    local success =
        turtle.suck(takeAmount)


    if not success then

        print("")
        print("================================")
        print("      CHARCOAL TAKE FAILED")
        print("================================")
        print("")
        print("Check that charcoal is in")
        print("chest slot 1.")
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    local after =
        turtle.getItemCount(FUEL_SLOT)


    if after <= before then

        print("")
        print("================================")
        print("     CHARCOAL NOT TRANSFERRED")
        print("================================")
        print("")
        print("Check the chest.")
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    turtle.select(FUEL_SLOT)

    return after >= FUEL_STACK_SIZE
end


-- ============================================================
-- UNLOAD MINING INVENTORY
--
-- PRECONDITION:
-- Turtle is facing chest.
--
-- DOES NOT TURN.
-- ============================================================

local function unloadMiningInventory()

    status("UNLOADING")


    for slot = 2, 16 do

        if turtle.getItemCount(slot) > 0 then

            turtle.select(slot)

            while turtle.getItemCount(slot) > 0 do

                local success =
                    turtle.drop()

                if success then
                    break
                end


                print("")
                print("================================")
                print("          CHEST FULL")
                print("================================")
                print("")
                print("The storage chest is full.")
                print("")
                print("Add another chest/barrel/etc.")
                print("")
                print("Press ENTER to retry.")
                print("")

                read()
            end
        end
    end


    turtle.select(FUEL_SLOT)
end


-- ============================================================
-- HOME SERVICE
--
-- PRECONDITION:
-- Home and facing chest.
--
-- POSTCONDITION:
-- Home and still facing chest.
--
-- DOES NOT TURN.
-- ============================================================

local function serviceHome()

    -- --------------------------------------------------------
    -- UNLOAD
    -- --------------------------------------------------------

    unloadMiningInventory()


    -- --------------------------------------------------------
    -- REFILL CHARCOAL
    -- --------------------------------------------------------

    topUpCharcoalFromChest()


    -- --------------------------------------------------------
    -- REFUEL
    -- --------------------------------------------------------

    if turtle.getFuelLevel() ~= "unlimited" then

        local fuel =
            turtle.getFuelLevel()

        local fuelLimit =
            turtle.getFuelLimit()

        local desiredFuel =
            math.min(
                fuelLimit,
                math.max(
                    fuel,
                    FUEL_RESERVE * 4
                )
            )


        if fuel < desiredFuel then

            refuelToTarget(desiredFuel)
        end
    end


    -- Refueling consumed charcoal.
    topUpCharcoalFromChest()


    turtle.select(FUEL_SLOT)

    -- Still facing chest.
end


-- ============================================================
-- RETURN HOME
-- ============================================================

local function goHome()

    status("RETURNING HOME")


    -- --------------------------------------------------------
    -- RETURN TO STARTING HEIGHT
    -- --------------------------------------------------------

    while z < 0 do
        moveUp()
    end

    while z > 0 do
        moveDown()
    end


    -- --------------------------------------------------------
    -- RETURN X
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
    -- RETURN Y
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
    -- HOME DIRECTION
    -- --------------------------------------------------------

    face(0)
end


-- ============================================================
-- SERVICE TRIP
-- ============================================================

local function service()

    -- Save exact position/state.

    local savedX = x
    local savedY = y
    local savedZ = z

    local savedDirection =
        direction

    local savedRow =
        currentRow

    local savedHole =
        currentHole

    local savedDepth =
        currentDepth


    -- --------------------------------------------------------
    -- GO HOME
    -- --------------------------------------------------------

    goHome()


    -- --------------------------------------------------------
    -- FACE CHEST
    --
    -- Exactly one turn.
    -- --------------------------------------------------------

    turnAround()


    -- --------------------------------------------------------
    -- SERVICE
    --
    -- No turning occurs here.
    -- --------------------------------------------------------

    serviceHome()


    -- --------------------------------------------------------
    -- FACE MINING AREA
    --
    -- Exactly one turn.
    -- --------------------------------------------------------

    turnAround()


    -- --------------------------------------------------------
    -- RESTORE X
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
    -- RESTORE Y
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
    -- RESTORE DEPTH
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
    -- RESTORE DIRECTION
    -- --------------------------------------------------------

    face(savedDirection)


    currentRow =
        savedRow

    currentHole =
        savedHole

    currentDepth =
        savedDepth


    status("RESUMING")
end


-- ============================================================
-- INVENTORY FULL
-- ============================================================

local function miningInventoryFull()

    for slot = 2, 16 do

        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end


-- ============================================================
-- RESOURCE CHECK
-- ============================================================

local function checkResources()

    verifyFuelSlot()


    -- --------------------------------------------------------
    -- INVENTORY
    -- --------------------------------------------------------

    if miningInventoryFull() then

        service()

        return
    end


    -- --------------------------------------------------------
    -- FUEL
    -- --------------------------------------------------------

    if turtle.getFuelLevel() ~= "unlimited" then

        if not enoughFuelToReturn() then

            service()

            return
        end
    end
end


-- ============================================================
-- MINE ONE WALL
--
-- This is where Allthemodium is detected.
--
-- If Allthemodium is found:
--
--     record hole number
--     DO NOT MINE
--
-- Otherwise:
--
--     bad block -> leave it
--     normal block -> mine it
-- ============================================================

local function mineWall()

    local found, data =
        turtle.inspect()

    if not found then
        return
    end


    local blockName =
        data.name


    -- ========================================================
    -- ALLTHEMODIUM
    -- ========================================================

    if isAllthemodium(blockName) then

        recordAllthemodium()

        return
    end


    -- ========================================================
    -- OTHER BAD BLOCK
    -- ========================================================

    if isBadBlock(blockName) then
        return
    end


    -- ========================================================
    -- NORMAL BLOCK
    -- ========================================================

    turtle.dig()
end


-- ============================================================
-- CHECK FOUR WALLS
-- ============================================================

local function checkFourWalls()

    local originalDirection =
        direction


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
-- MINE ONE HOLE
-- ============================================================

local function mineHole()

    currentDepth = 0


    status(
        "MINING HOLE " ..
        getCurrentHoleNumber() ..
        "/" ..
        TOTAL_HOLES
    )


    while true do

        checkResources()


        -- ----------------------------------------------------
        -- Inspect below.
        -- ----------------------------------------------------

        local found, data =
            turtle.inspectDown()


        -- ----------------------------------------------------
        -- BEDROCK
        -- ----------------------------------------------------

        if found
           and data.name == "minecraft:bedrock" then

            break
        end


        -- ----------------------------------------------------
        -- Dig down.
        --
        -- The shaft itself is always cleared.
        -- ----------------------------------------------------

        if turtle.detectDown() then
            turtle.digDown()
        end


        -- ----------------------------------------------------
        -- Move down.
        -- ----------------------------------------------------

        moveDown()

        currentDepth =
            math.abs(z)


        -- ----------------------------------------------------
        -- Check four sides.
        -- ----------------------------------------------------

        checkFourWalls()


        -- ----------------------------------------------------
        -- Periodic status.
        -- ----------------------------------------------------

        if currentDepth %
           STATUS_DEPTH_INTERVAL == 0 then

            status(
                "MINING HOLE " ..
                getCurrentHoleNumber() ..
                " - DEPTH " ..
                currentDepth
            )
        end
    end


    -- ========================================================
    -- BEDROCK REACHED
    -- ========================================================

    status(
        "BEDROCK - HOLE " ..
        getCurrentHoleNumber()
    )


    -- --------------------------------------------------------
    -- Return to surface.
    -- --------------------------------------------------------

    while z < 0 do
        moveUp()
    end


    currentDepth = 0
end


-- ============================================================
-- MOVE TO NEXT HOLE
--
-- H . H
--
-- Two blocks between hole centers.
-- ============================================================

local function moveToNextHole()

    forwardNoDig()
    forwardNoDig()
end


-- ============================================================
-- MOVE TO NEXT ROW
--
-- H . H . H
-- . H . H .
-- H . H . H
--
-- One-block stagger.
-- ============================================================

local function moveToNextRow(row)

    -- Move beyond the last hole.

    forwardNoDig()


    if row % 2 == 1 then

        -- Odd -> Even

        turnRight()
        forwardNoDig()
        turnRight()

    else

        -- Even -> Odd

        turnLeft()
        forwardNoDig()
        turnLeft()
    end
end


-- ============================================================
-- STARTUP FUEL
-- ============================================================

local function startupFuel()

    verifyFuelSlot()


    -- --------------------------------------------------------
    -- Face chest.
    -- --------------------------------------------------------

    turnAround()


    -- --------------------------------------------------------
    -- Fill slot 1.
    -- --------------------------------------------------------

    topUpCharcoalFromChest()


    -- --------------------------------------------------------
    -- Get starting fuel.
    -- --------------------------------------------------------

    if turtle.getFuelLevel() ~= "unlimited" then

        local fuel =
            turtle.getFuelLevel()

        local fuelLimit =
            turtle.getFuelLimit()

        local desired =
            math.min(
                fuelLimit,
                math.max(
                    fuel,
                    FUEL_RESERVE * 4
                )
            )


        if fuel < desired then

            refuelToTarget(desired)
        end
    end


    -- Refueling consumed charcoal.

    topUpCharcoalFromChest()


    -- --------------------------------------------------------
    -- Face mining area.
    -- --------------------------------------------------------

    turnAround()


    turtle.select(FUEL_SLOT)
end


-- ============================================================
-- MAIN
-- ============================================================

local function main()

    -- --------------------------------------------------------
    -- STARTUP
    -- --------------------------------------------------------

    startupFuel()

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
            -- Mine complete hole.
            -- ------------------------------------------------

            mineHole()


            -- ------------------------------------------------
            -- Next hole.
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
    -- FINAL SERVICE
    -- ========================================================

    turnAround()

    serviceHome()

    turnAround()


    -- ========================================================
    -- FINAL SCREEN
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
    print("Charcoal in slot 1:")
    print(turtle.getItemCount(FUEL_SLOT))
    print("")
    print("--------------------------------")
    print("Allthemodium:")
    print(getAllthemodiumList())
    print("--------------------------------")
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
    print("Position:")
    print("X: " .. x)
    print("Y: " .. y)
    print("Z: " .. z)
    print("")
    print("Direction: " .. direction)
    print("")
    print("Row: " .. currentRow)
    print("Hole: " .. currentHole)
    print("Depth: " .. currentDepth)
    print("")
    print("Fuel:")
    print(tostring(turtle.getFuelLevel()))
    print("")
    print("Charcoal slot 1:")
    print(turtle.getItemCount(FUEL_SLOT))
    print("")
    print("--------------------------------")
    print("Allthemodium:")
    print(getAllthemodiumList())
    print("--------------------------------")
    print("")
end


-- ============================================================
-- RUN
-- ============================================================

local success, errorMessage =
    xpcall(
        main,
        debug.traceback
    )


if not success then

    print("")
    print(errorMessage)

    emergencyStop()
end
