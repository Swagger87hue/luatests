-- ============================================================
-- ATM10 STAGGERED ORE MINER
-- quarry4.lua
-- ============================================================
--
-- GRID PATTERN
--
-- H . H . H . H . H
-- . H . H . H . H .
-- H . H . H . H . H
-- . H . H . H . H .
-- H . H . H . H . H
--
-- User enters the grid size when starting.
--
-- 2  = 2 x 2  = 4 holes
-- 3  = 3 x 3  = 9 holes
-- 10 = 10 x 10 = 100 holes
--
--
-- HOLE BEHAVIOUR
--
-- Each H is a vertical shaft to bedrock.
--
-- At every depth:
--
--   FRONT
--   RIGHT
--   BACK
--   LEFT
--
-- are inspected.
--
-- If the block is in BAD_BLOCKS:
--     leave it alone.
--
-- Otherwise:
--     mine it.
--
--
-- INVENTORY
--
-- SLOT 1:
--     RESERVED FOR CHARCOAL ONLY.
--
-- SLOTS 2-16:
--     Mining output.
--
--
-- FUEL SYSTEM
--
-- The chest is directly behind the turtle at HOME.
--
-- When the turtle is home:
--
--     If slot 1 contains 55 charcoal:
--         take exactly 9 charcoal from chest.
--
--     If slot 1 is empty:
--         take exactly 64 charcoal.
--
--     If slot 1 already contains 64:
--         take nothing.
--
-- The turtle NEVER takes more charcoal than required.
--
-- When fuel is actually needed:
--
--     charcoal is consumed from slot 1.
--
-- When the turtle returns home:
--
--     slot 1 is topped back up to 64.
--
--
-- IMPORTANT:
--
-- The program uses turtle.refuel(quantity), NOT turtle.refuel()
-- without a quantity.
--
-- This prevents an entire stack from being consumed at once.
--
--
-- CHEST
--
-- The chest must be directly behind the turtle at home.
--
-- The turtle will:
--
--     unload slots 2-16
--     NEVER unload slot 1
--     find charcoal in the chest
--     move exactly the required charcoal into slot 1
--
--
-- ============================================================


-- ============================================================
-- CONFIGURATION
-- ============================================================

-- Extra safety fuel.
--
-- The turtle wants enough fuel to return home plus this amount.
local FUEL_RESERVE = 20

-- How many depth levels between status refreshes.
local STATUS_DEPTH_INTERVAL = 10

-- Reserved fuel slot.
local FUEL_SLOT = 1

-- Maximum charcoal that should be kept in the fuel slot.
local FUEL_STACK_SIZE = 64

-- Exact item ID for charcoal.
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
-- POSITION
-- ============================================================

-- Home:
--
-- x = 0
-- y = 0
-- z = 0

local x = 0
local y = 0
local z = 0

-- Direction:
--
-- 0 = original direction
-- 1 = right
-- 2 = backwards
-- 3 = left

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
-- BAD BLOCK CHECK
-- ============================================================

local function isBadBlock(name)

    if not name then
        return true
    end

    return badBlocks[name] == true
end


-- ============================================================
-- SLOT 1 CHECK
-- ============================================================

local function slot1IsCharcoal()

    local item = turtle.getItemDetail(FUEL_SLOT)

    if not item then
        return false
    end

    return item.name == CHARCOAL_NAME
end


-- ============================================================
-- VERIFY FUEL SLOT
--
-- Slot 1 is reserved exclusively for charcoal.
--
-- If the player accidentally puts something else there,
-- the program stops instead of risking that item.
-- ============================================================

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
-- FORWARD MOVEMENT WITHOUT DIGGING
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
-- DISTANCE TO HOME
-- ============================================================

local function distanceHome()

    return math.abs(x)
        + math.abs(y)
        + math.abs(z)
        + FUEL_RESERVE
end


-- ============================================================
-- FUEL AVAILABLE?
-- ============================================================

local function enoughFuelToReturn()

    local fuel = turtle.getFuelLevel()

    if fuel == "unlimited" then
        return true
    end

    return fuel >= distanceHome()
end


-- ============================================================
-- CALCULATE FUEL ITEMS NEEDED
--
-- Charcoal gives approximately 80 fuel units in CC:Tweaked.
--
-- However, we don't need to hardcode the value for the actual
-- refill decision. We can measure how much fuel one charcoal
-- gives on this turtle.
-- ============================================================

local function getCharcoalFuelValue()

    if turtle.getFuelLevel() == "unlimited" then
        return 0
    end

    local oldSlot = turtle.getSelectedSlot()
    local oldFuel = turtle.getFuelLevel()

    -- We need one charcoal available somewhere to measure it.
    local testSlot = nil

    for slot = 1, 16 do

        if slot ~= FUEL_SLOT then

            local item = turtle.getItemDetail(slot)

            if item and item.name == CHARCOAL_NAME then
                testSlot = slot
                break
            end
        end
    end

    -- Normally slot 1 contains charcoal.
    if not testSlot and slot1IsCharcoal() then
        testSlot = FUEL_SLOT
    end

    if not testSlot then
        return 80
    end

    turtle.select(testSlot)

    local beforeCount = turtle.getItemCount(testSlot)

    if beforeCount <= 0 then
        turtle.select(oldSlot)
        return 80
    end

    -- Consume exactly one charcoal.
    turtle.refuel(1)

    local newFuel = turtle.getFuelLevel()

    local fuelGained = newFuel - oldFuel

    -- If it failed for some reason, use standard charcoal value.
    if fuelGained <= 0 then
        fuelGained = 80
    end

    turtle.select(oldSlot)

    return fuelGained
end


-- ============================================================
-- REFUEL EXACTLY AS NEEDED
--
-- Uses charcoal from SLOT 1.
--
-- Does NOT empty the entire stack.
--
-- Stops when:
--
--   1. required fuel has been reached
--   2. fuel tank is full
--   3. charcoal is empty
-- ============================================================

local function refuelToTarget(targetFuel)

    if turtle.getFuelLevel() == "unlimited" then
        return true
    end

    verifyFuelSlot()

    local fuel = turtle.getFuelLevel()

    if fuel >= targetFuel then
        return true
    end


    local fuelLimit = turtle.getFuelLimit()

    if targetFuel > fuelLimit then
        targetFuel = fuelLimit
    end


    local charcoalCount =
        turtle.getItemCount(FUEL_SLOT)


    if charcoalCount <= 0 then
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


        -- Consume exactly ONE charcoal.
        turtle.refuel(1)


        local afterFuel =
            turtle.getFuelLevel()

        local afterCount =
            turtle.getItemCount(FUEL_SLOT)


        -- Safety check.
        --
        -- If nothing changed, stop to avoid an infinite loop.
        if afterFuel <= beforeFuel
           and afterCount >= beforeCount then
            break
        end
    end


    turtle.select(1)

    return turtle.getFuelLevel() >= targetFuel
end


-- ============================================================
-- TOP UP SLOT 1 TO EXACTLY 64 CHARCOAL
--
-- IMPORTANT:
--
-- Turtle must be facing the HOME CHEST.
--
-- The chest may contain many different items.
--
-- We therefore inspect the chest and locate CHARCOAL.
--
-- Because turtle.suck() cannot specify a chest slot, we move
-- the charcoal stack to chest slot 1 before sucking it.
--
-- If chest slot 1 is occupied by another item, we move that
-- item to an empty chest slot first.
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


    -- --------------------------------------------------------
    -- Check for chest.
    -- --------------------------------------------------------

    local chest = peripheral.wrap("front")

    if not chest then

        print("")
        print("================================")
        print("       CHEST NOT FOUND")
        print("================================")
        print("")
        print("The turtle is supposed to face")
        print("the fuel/storage chest.")
        print("")
        print("Place the chest directly behind")
        print("the turtle at home.")
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- Find charcoal in chest.
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
        print("Slot 1 currently contains:")
        print(current .. " charcoal")
        print("")
        print("Needed:")
        print(needed)
        print("")
        print("Put charcoal into the chest.")
        print("")
        print("The turtle will check again.")
        print("")

        sleep(2)

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- If charcoal isn't in chest slot 1, move it there.
    -- --------------------------------------------------------

    if charcoalSlot ~= 1 then

        local slot1Item =
            chest.getItemDetail(1)


        -- ----------------------------------------------------
        -- If chest slot 1 is occupied, find empty slot.
        -- ----------------------------------------------------

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
                print("The turtle needs to rearrange")
                print("the chest to obtain charcoal.")
                print("")
                print("There is no empty chest slot.")
                print("")
                print("Remove something from the chest.")
                print("")
                print("Press ENTER to retry.")
                print("")

                read()

                return topUpCharcoalFromChest()
            end


            -- Move chest slot 1 into the empty slot.
            local moved =
                chest.pushItems(
                    peripheral.getName(chest),
                    1,
                    nil,
                    emptySlot
                )


            if moved <= 0 then

                print("")
                print("Could not rearrange chest.")
                print("Press ENTER to retry.")
                print("")

                read()

                return topUpCharcoalFromChest()
            end
        end


        -- ----------------------------------------------------
        -- Re-read chest.
        -- ----------------------------------------------------

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


        -- ----------------------------------------------------
        -- Move charcoal into chest slot 1.
        -- ----------------------------------------------------

        local moved =
            chest.pushItems(
                peripheral.getName(chest),
                charcoalSlot,
                nil,
                1
            )


        if moved <= 0 then

            print("")
            print("Could not move charcoal to")
            print("chest slot 1.")
            print("")
            print("Press ENTER to retry.")
            print("")

            read()

            return topUpCharcoalFromChest()
        end
    end


    -- --------------------------------------------------------
    -- Re-check how much charcoal is actually available.
    -- --------------------------------------------------------

    chestItems = chest.list()

    local charcoalAvailable = 0

    if chestItems[1]
       and chestItems[1].name == CHARCOAL_NAME then

        charcoalAvailable = chestItems[1].count
    end


    if charcoalAvailable <= 0 then

        print("")
        print("Charcoal disappeared from chest.")
        print("Retrying...")
        print("")

        sleep(1)

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- IMPORTANT:
    --
    -- Only take EXACTLY the missing amount.
    -- --------------------------------------------------------

    local takeAmount =
        math.min(needed, charcoalAvailable)


    turtle.select(FUEL_SLOT)

    local sucked =
        turtle.suck(takeAmount)


    if not sucked then

        print("")
        print("================================")
        print("       CHARCOAL TRANSFER FAILED")
        print("================================")
        print("")
        print("Could not take charcoal.")
        print("")
        print("Check that the chest is directly")
        print("in front of the turtle.")
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    -- --------------------------------------------------------
    -- Verify result.
    -- --------------------------------------------------------

    local finalCount =
        turtle.getItemCount(FUEL_SLOT)


    if finalCount < current then

        print("")
        print("Unexpected charcoal transfer.")
        print("")
        print("Expected at least:")
        print(current)
        print("")
        print("Got:")
        print(finalCount)
        print("")
        print("Press ENTER to retry.")
        print("")

        read()

        return topUpCharcoalFromChest()
    end


    turtle.select(1)

    return finalCount >= FUEL_STACK_SIZE
end


-- ============================================================
-- UNLOAD MINING INVENTORY
--
-- SLOT 1 IS NEVER UNLOADED.
--
-- Slots 2-16 are unloaded.
-- ============================================================

local function unloadMiningInventory()

    status("UNLOADING")

    -- Chest is behind turtle.
    turnAround()


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

    -- We are still facing chest here.
end


-- ============================================================
-- HOME FUEL SERVICE
--
-- We are assumed to be HOME.
--
-- Facing the chest.
--
-- Steps:
--
--   1. Unload slots 2-16.
--   2. Make slot 1 exactly 64 charcoal.
--   3. Refuel only as much as necessary.
--   4. Top slot 1 back to 64 again.
--
-- This guarantees:
--
--   slot 1 = 64 charcoal
--
-- whenever enough charcoal exists in the chest.
-- ============================================================

local function serviceHomeFuel()

    -- We should currently face chest.
    -- Unload first.
    unloadMiningInventory()


    -- --------------------------------------------------------
    -- Top slot 1 to 64.
    -- --------------------------------------------------------

    topUpCharcoalFromChest()


    -- --------------------------------------------------------
    -- Determine minimum useful fuel target.
    --
    -- We want enough fuel for the next trip.
    --
    -- At home, distanceHome() is just the reserve.
    -- So we can safely start with reserve + some working fuel.
    -- --------------------------------------------------------

    local fuel =
        turtle.getFuelLevel()


    if fuel ~= "unlimited" then

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


        -- ----------------------------------------------------
        -- Refuel from slot 1 only if necessary.
        -- ----------------------------------------------------

        if fuel < desiredFuel then
            refuelToTarget(desiredFuel)
        end
    end


    -- --------------------------------------------------------
    -- IMPORTANT:
    --
    -- Refuelling consumed some charcoal.
    --
    -- Restore slot 1 to exactly 64.
    -- --------------------------------------------------------

    topUpCharcoalFromChest()


    turtle.select(FUEL_SLOT)
end


-- ============================================================
-- RETURN HOME
--
-- Horizontal travel NEVER digs.
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
    -- Restore original direction.
    -- --------------------------------------------------------

    face(0)
end


-- ============================================================
-- FULL SERVICE TRIP
--
-- Saves exact position.
-- Returns home.
-- Services inventory/fuel.
-- Returns to exact position.
-- ============================================================

local function service()

    -- --------------------------------------------------------
    -- SAVE EXACT POSITION.
    -- --------------------------------------------------------

    local savedX = x
    local savedY = y
    local savedZ = z

    local savedDirection = direction

    local savedRow = currentRow
    local savedHole = currentHole
    local savedDepth = currentDepth


    -- --------------------------------------------------------
    -- RETURN HOME.
    -- --------------------------------------------------------

    goHome()


    -- --------------------------------------------------------
    -- Service inventory and fuel.
    --
    -- At this point direction = 0,
    -- so the chest is behind us.
    -- serviceHomeFuel() turns around first.
    -- --------------------------------------------------------

    turnAround()

    serviceHomeFuel()

    -- serviceHomeFuel leaves us facing the chest.
    -- Turn back toward mining direction.
    turnAround()


    -- --------------------------------------------------------
    -- RESTORE X.
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
    -- RESTORE Y.
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
    -- RESTORE DEPTH.
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
    -- RESTORE DIRECTION.
    -- --------------------------------------------------------

    face(savedDirection)


    currentRow = savedRow
    currentHole = savedHole
    currentDepth = savedDepth


    status("RESUMING")
end


-- ============================================================
-- CHECK INVENTORY
-- ============================================================

local function miningInventoryFull()

    -- Slot 1 is reserved for fuel.
    --
    -- Therefore only slots 2-16 matter.

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
    -- Inventory full.
    -- --------------------------------------------------------

    if miningInventoryFull() then

        service()

        return
    end


    -- --------------------------------------------------------
    -- Fuel.
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


    -- Protected block.
    if isBadBlock(blockName) then
        return
    end


    -- Everything else gets mined.
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
        -- Look below.
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
        -- The vertical shaft must reach bedrock.
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
        -- Inspect four walls.
        -- ----------------------------------------------------

        checkFourWalls()


        -- ----------------------------------------------------
        -- Status update.
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
--
-- ============================================================

local function moveToNextHole()

    forwardNoDig()
    forwardNoDig()
end


-- ============================================================
-- MOVE TO NEXT ROW
--
-- Creates:
--
-- H . H . H
-- . H . H .
-- H . H . H
--
-- One-block stagger.
-- ============================================================

local function moveToNextRow(row)

    -- Move one block beyond last hole.
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
-- STARTUP FUEL SETUP
--
-- The turtle begins at HOME.
--
-- The chest is behind it.
--
-- We:
--
--   1. Turn around.
--   2. Fill slot 1 to 64 charcoal.
--   3. Refuel only enough for a safe start.
--   4. Fill slot 1 back to 64.
--   5. Face mining direction.
-- ============================================================

local function startupFuel()

    verifyFuelSlot()


    -- Face chest.
    turnAround()


    -- Make slot 1 exactly 64 charcoal.
    topUpCharcoalFromChest()


    -- --------------------------------------------------------
    -- Make sure there is enough actual fuel to start.
    -- --------------------------------------------------------

    if turtle.getFuelLevel() ~= "unlimited" then

        local fuel =
            turtle.getFuelLevel()

        local fuelLimit =
            turtle.getFuelLimit()


        -- We don't need to fill the tank.
        --
        -- We need enough to safely begin and eventually return.
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


    -- --------------------------------------------------------
    -- Refuelling may have consumed charcoal.
    --
    -- Restore slot 1 to exactly 64.
    -- --------------------------------------------------------

    topUpCharcoalFromChest()


    -- Face mining direction.
    turnAround()

    turtle.select(FUEL_SLOT)
end


-- ============================================================
-- MAIN
-- ============================================================

local function main()

    -- ========================================================
    -- STARTUP
    -- ========================================================

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
            -- Mine complete vertical shaft.
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
    -- COMPLETE
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

    serviceHomeFuel()

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
    print("Fuel slot contains:")
    print(turtle.getItemCount(FUEL_SLOT) .. " charcoal")
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
    print("Row: " .. currentRow)
    print("Hole: " .. currentHole)
    print("Depth: " .. currentDepth)
    print("")
    print("Fuel: " .. tostring(turtle.getFuelLevel()))
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
