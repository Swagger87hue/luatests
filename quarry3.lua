-- ============================================================
-- ATM10 STAGGERED ORE MINER
-- quarry3.lua
-- ============================================================
--
-- IMPORTANT HOME ORIENTATION
--
-- The turtle starts like this:
--
--                  MINING AREA
--                       ^
--                       |
--                    TURTLE
--                       |
--                     CHEST
--
-- At HOME:
--
--     direction 0 = toward mining area
--     chest      = directly behind turtle
--
--
-- GRID:
--
-- H . H . H . H
-- . H . H . H .
-- H . H . H . H
-- . H . H . H .
--
-- Each H is a vertical shaft to bedrock.
--
--
-- INVENTORY:
--
-- SLOT 1:
--     charcoal only
--
-- SLOTS 2-16:
--     mined materials
--
--
-- BAD BLOCKS:
--
-- These are left in place when checking the four walls.
--
-- The vertical shaft itself is always cleared downward,
-- because the purpose of each hole is to reach bedrock.
--
--
-- IMPORTANT:
--
-- HOME SERVICE ORIENTATION IS NOW CONSISTENT.
--
-- serviceHome() MUST be called while facing the chest.
--
-- unloadMiningInventory() DOES NOT TURN.
--
-- This prevents the old double-turn bug which caused the
-- turtle to unload everything onto the ground.
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
-- 2 = backwards / chest direction at home
-- 3 = left

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

    if turtle.getFuelLevel() ~= "unlimited" then
        print("Fuel max:   " .. tostring(turtle.getFuelLimit()))
    end

    print("")
    print("Charcoal:   " .. turtle.getItemCount(FUEL_SLOT))
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
-- FUEL SLOT
-- ============================================================

local function slot1IsCharcoal()

    local item = turtle.getItemDetail(FUEL_SLOT)

    if not item then
        return false
    end

    return item.name == CHARCOAL_NAME
end


local function verifyFuelSlot()

    local item = turtle.getItemDetail(FUEL_SLOT)

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

    return math.abs(x)
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
--
-- Uses only one charcoal at a time.
-- Never empties the entire stack.
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
--
-- Turtle MUST be facing the chest.
--
-- This function does NOT turn the turtle.
--
-- This is important for the home-service orientation.
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


    -- The chest must be directly in front.
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
        print("Current direction: " .. direction)
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- Find charcoal in the chest.
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
        print("Slot 1:")
        print(current .. " charcoal")
        print("")
        print("Needed:")
        print(needed)
        print("")
        print("Put charcoal into the chest.")
        print("")
        print("Checking again automatically...")
        print("")

        sleep(2)

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- We need charcoal to be accessible through turtle.suck.
    --
    -- If it isn't chest slot 1, move it there.
    -- --------------------------------------------------------

    if charcoalSlot ~= 1 then

        local slot1Item =
            chest.getItemDetail(1)

        if slot1Item then

            local emptySlot = nil
            local size = chest.size()

            for slot = 1, size do

                if not chest.getItemDetail(slot) then

                    emptySlot = slot
                    break
                end
            end


            if not emptySlot then

                print("")
                print("================================")
                print("        CHEST HAS NO SPACE")
                print("================================")
                print("")
                print("The chest has no empty slot")
                print("for rearranging charcoal.")
                print("")
                print("Remove something from the chest.")
                print("")
                print("Press ENTER to retry.")
                print("")

                read()

                return topUpCharcoalFromChest()
            end


            chest.pushItems(
                peripheral.getName(chest),
                1,
                nil,
                emptySlot
            )
        end


        -- Re-read chest.
        chestItems = chest.list()
        charcoalSlot = nil

        for slot, item in pairs(chestItems) do

            if item.name == CHARCOAL_NAME then

                charcoalSlot = slot
                break
            end
        end


        if not charcoalSlot then
            return topUpCharcoalFromChest()
        end


        chest.pushItems(
            peripheral.getName(chest),
            charcoalSlot,
            nil,
            1
        )
    end


    -- --------------------------------------------------------
    -- Determine how much charcoal is actually available.
    -- --------------------------------------------------------

    chestItems = chest.list()

    local charcoalAvailable = 0

    if chestItems[1]
       and chestItems[1].name == CHARCOAL_NAME then

        charcoalAvailable =
            chestItems[1].count
    end


    if charcoalAvailable <= 0 then

        sleep(1)

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- TAKE ONLY WHAT IS NEEDED.
    -- --------------------------------------------------------

    local takeAmount =
        math.min(
            needed,
            charcoalAvailable
        )


    turtle.select(FUEL_SLOT)

    local sucked =
        turtle.suck(takeAmount)


    if not sucked then

        print("")
        print("================================")
        print("      CHARCOAL TAKE FAILED")
        print("================================")
        print("")
        print("The turtle could not take")
        print("charcoal from the chest.")
        print("")
        print("Check the chest.")
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    local finalCount =
        turtle.getItemCount(FUEL_SLOT)


    if finalCount < current then

        print("")
        print("Unexpected charcoal transfer.")
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    turtle.select(FUEL_SLOT)

    return finalCount >= FUEL_STACK_SIZE
end


-- ============================================================
-- UNLOAD MINING INVENTORY
--
-- VERY IMPORTANT:
--
-- THIS FUNCTION ASSUMES THE TURTLE IS ALREADY FACING
-- THE CHEST.
--
-- IT DOES NOT TURN.
--
-- This is the fix for the original bug.
-- ============================================================

local function unloadMiningInventory()

    status("UNLOADING")

    -- DO NOT TURN HERE.
    --
    -- The caller is responsible for making sure the turtle
    -- faces the chest before calling this function.


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
--
-- Turtle is HOME.
-- Turtle is FACING THE CHEST.
--
-- POSTCONDITION:
--
-- Turtle is HOME.
-- Turtle is STILL FACING THE CHEST.
--
-- The caller then turns around exactly once.
-- ============================================================

local function serviceHome()

    -- --------------------------------------------------------
    -- 1. Unload mined items.
    --
    -- We are already facing the chest.
    -- --------------------------------------------------------

    unloadMiningInventory()


    -- --------------------------------------------------------
    -- 2. Refill charcoal to 64.
    -- --------------------------------------------------------

    topUpCharcoalFromChest()


    -- --------------------------------------------------------
    -- 3. Add fuel if necessary.
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


    -- --------------------------------------------------------
    -- 4. Refuelling consumed charcoal.
    --
    -- Restore slot 1 to 64.
    -- --------------------------------------------------------

    topUpCharcoalFromChest()


    turtle.select(FUEL_SLOT)

    -- IMPORTANT:
    --
    -- Still facing chest here.
end


-- ============================================================
-- RETURN HOME
--
-- PRECONDITION:
--
-- Position tracking is correct.
--
-- POSTCONDITION:
--
-- x = 0
-- y = 0
-- z = 0
-- direction = 0
--
-- So after this function the turtle faces the mining area,
-- and the chest is behind it.
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
    -- ALWAYS RESTORE HOME DIRECTION.
    -- --------------------------------------------------------

    face(0)
end


-- ============================================================
-- SERVICE TRIP
--
-- Saves exact position.
--
-- Goes HOME.
--
-- Turns ONCE to face chest.
--
-- Services inventory/fuel.
--
-- Turns ONCE back toward mining area.
--
-- Restores exact position.
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
    -- HOME IS NOW:
    --
    -- direction = 0
    -- chest is behind us
    --
    -- Turn exactly once.
    -- Now:
    --
    -- direction = 2
    -- chest is in front.
    -- --------------------------------------------------------

    turnAround()


    -- --------------------------------------------------------
    -- SERVICE HOME
    --
    -- serviceHome() DOES NOT TURN.
    -- --------------------------------------------------------

    serviceHome()


    -- --------------------------------------------------------
    -- SERVICE COMPLETE.
    --
    -- Still facing chest.
    --
    -- Turn exactly once to face mining direction.
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
    -- RESTORE ORIGINAL DIRECTION
    -- --------------------------------------------------------

    face(savedDirection)


    currentRow = savedRow
    currentHole = savedHole
    currentDepth = savedDepth


    status("RESUMING")
end


-- ============================================================
-- INVENTORY FULL
--
-- Slot 1 is fuel.
-- Slots 2-16 are mining inventory.
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
-- ============================================================

local function mineWall()

    local found, data =
        turtle.inspect()

    if not found then
        return
    end


    local blockName =
        data.name


    if isBadBlock(blockName) then
        return
    end


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
        currentHole ..
        "/" ..
        HOLES_PER_ROW
    )


    while true do

        checkResources()


        -- ----------------------------------------------------
        -- Check block below.
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
        -- Clear block below.
        --
        -- Bad blocks are deliberately ignored for the four
        -- walls, but the shaft itself must reach bedrock.
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
        -- Check all four sides.
        -- ----------------------------------------------------

        checkFourWalls()


        -- ----------------------------------------------------
        -- Status.
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


    -- Return to surface.
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
--
-- START CONDITION:
--
-- Turtle faces mining direction.
-- Chest is behind.
--
-- END CONDITION:
--
-- Turtle faces mining direction.
-- Slot 1 is topped up.
-- ============================================================

local function startupFuel()

    verifyFuelSlot()


    -- Face chest.
    turnAround()


    -- Fill slot 1 to 64.
    topUpCharcoalFromChest()


    -- --------------------------------------------------------
    -- Make sure we have useful starting fuel.
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


    -- Refuelling may have consumed charcoal.
    topUpCharcoalFromChest()


    -- Face mining direction.
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
    --
    -- goHome() leaves us facing mining direction.
    --
    -- Turn ONCE to chest.
    -- serviceHome() does NOT turn.
    -- Turn ONCE back.
    -- ========================================================

    turnAround()

    serviceHome()

    turnAround()


    -- ========================================================
    -- FINISHED
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
