-- ============================================================
-- FUEL DETECTION
-- ============================================================

local function isFuelItem(slot)

    local item = turtle.getItemDetail(slot)

    if not item then
        return false
    end

    return turtle.getFuelLevel() ~= "unlimited"
       and turtle.getFuelLevel() >= 0
       and turtle.refuel(0, false)
end


-- ============================================================
-- REFUEL FROM INVENTORY
--
-- Tries every inventory slot.
-- Fuel items are consumed automatically.
-- ============================================================

local function refuelFromInventory()

    if turtle.getFuelLevel() == "unlimited" then
        return true
    end

    for slot = 1, 16 do

        if turtle.getItemCount(slot) > 0 then

            turtle.select(slot)

            -- Refuel as much as possible from this slot.
            while turtle.getItemCount(slot) > 0 do

                local before = turtle.getFuelLevel()

                local success = turtle.refuel(1)

                if not success then
                    break
                end

                local after = turtle.getFuelLevel()

                -- Safety: if fuel didn't increase, this isn't fuel.
                if after <= before then
                    break
                end
            end
        end
    end

    turtle.select(1)

    return turtle.getFuelLevel() > FUEL_RESERVE
end


-- ============================================================
-- UNLOAD INVENTORY
--
-- IMPORTANT:
-- Fuel is NEVER dropped.
-- ============================================================

local function unload()

    status("UNLOADING")

    -- Turn toward chest.
    turnAround()

    for slot = 1, 16 do

        local item = turtle.getItemDetail(slot)

        if item then

            -- Temporarily select the slot.
            turtle.select(slot)

            -- Try to refuel it.
            --
            -- If it is fuel, turtle.refuel() consumes it
            -- instead of putting it into the chest.
            local fuelBefore = turtle.getFuelLevel()

            turtle.refuel(0)

            local fuelAfter = turtle.getFuelLevel()

            local isFuel = false

            if fuelAfter > fuelBefore then
                isFuel = true
            end

            -- If it wasn't fuel, unload it.
            if not isFuel then

                while turtle.getItemCount(slot) > 0 do

                    if turtle.drop() then
                        break
                    end

                    print("")
                    print("================================")
                    print("          CHEST FULL")
                    print("================================")
                    print("")
                    print("Add more storage.")
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
