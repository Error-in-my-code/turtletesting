--[[
  Chunk Excavator (16x16 down to bedrock)

  This program executes a full 16x16 excavation pattern down to bedrock,
  using a serpentine (S-pattern) movement for efficiency.

  SETUP REQUIREMENTS:
  1. The turtle MUST have a working tool (like a Diamond Pickaxe) equipped.
  2. A storage container (like a Hopper or Chest) MUST be placed
     DIRECTLY BENEATH the turtle for item drops (at start position).
  3. A CHEST containing fuel (coal or charcoal) MUST be placed
     DIRECTLY ABOVE the starting position (for refueling).
  4. The turtle should be placed at the starting corner (0,0,0), facing the
     direction you want the first row of excavation to proceed.
--]]

local CHUNK_SIZE = 16

-- --- GLOBAL STATE FOR POSITION TRACKING ---
local x, y, z = 0, 0, 0 -- X and Z are horizontal position, Y is vertical layer (0 is start)
-- Directions: 0=North, 1=East, 2=South, 3=West
local direction = 0

-- --- TRACKING & MOVEMENT WRAPPERS ---

-- Updates the turtle's tracked position based on movement.
local function update_position(move_name, success)
    if not success then return false end -- Stop if movement failed

    if move_name == "forward" then
        if direction == 0 then z = z - 1 -- North
        elseif direction == 1 then x = x + 1 -- East
        elseif direction == 2 then z = z + 1 -- South
        elseif direction == 3 then x = x - 1 -- West
        end
    elseif move_name == "back" then
        if direction == 0 then z = z + 1 -- North
        elseif direction == 1 then x = x - 1 -- East
        elseif direction == 2 then z = z - 1 -- South
        elseif direction == 3 then x = x + 1 -- West
        end
    elseif move_name == "up" then
        y = y + 1
    elseif move_name == "down" then
        y = y - 1
    end
    return true
end

-- Wrapper for turtle.forward()
local function go_forward()
    local success = turtle.forward()
    return update_position("forward", success)
end

-- Wrapper for turtle.back()
local function go_back()
    local success = turtle.back()
    return update_position("back", success)
end

-- Wrapper for turtle.down()
local function go_down()
    local success, reason = turtle.down()
    if success then update_position("down", true) end
    return success, reason
end

-- Wrapper for turtle.up()
local function go_up()
    local success, reason = turtle.up()
    if success then update_position("up", true) end
    return success, reason
end

-- Wrapper for turtle.turnRight()
local function turn_right()
    local success = turtle.turnRight()
    if success then direction = (direction + 1) % 4 end
    return success
end

-- Wrapper for turtle.turnLeft()
local function turn_left()
    local success = turtle.turnLeft()
    if success then direction = (direction + 3) % 4 end
    return success
end

-- --- CORE UTILITY FUNCTIONS ---

-- Loops through the turtle's inventory and drops everything down.
local function unload_inventory()
    print("Inventory full. Unloading items...")
    -- Loop through all 16 inventory slots
    for slot = 1, 16 do
        turtle.select(slot)
        local count = turtle.getItemCount(slot)

        if count > 0 then
            -- Use dropDown() since the hopper is assumed to be below the turtle
            turtle.dropDown(count)
        end
    end
    turtle.select(1) -- Select slot 1 for potential fuel check later
    print("Unload complete. Resuming...")
end

-- Attempts to pull fuel from a chest assumed to be ABOVE the starting position (0,0,0).
local function refuel_from_chest()
    print("Starting refuel sequence...")
    local success, reason = go_up()

    if not success then
        print("ERROR: Could not move up to access the fuel chest! Reason: " .. tostring(reason))
        return false
    end

    -- The fuel chest is now below the turtle (at y=1 relative to start)
    local chest = peripheral.wrap("down")

    if chest and chest.pullItems then
        print("Peripheral wrapped. Pulling fuel from chest...")

        local fuel_name_1 = "minecraft:coal"
        local fuel_name_2 = "minecraft:charcoal"
        local fuel_pulled = false

        local items = chest.list()
        for slot, item in pairs(items) do
            if item.name == fuel_name_1 or item.name == fuel_name_2 then
                -- Pull a stack (64) of the fuel into the turtle's inventory (slot 1)
                -- "up" is the name of the turtle's internal inventory side relative to the chest
                chest.pullItems("up", slot, 64, 1)
                fuel_pulled = true
                break
            end
        end

        if not fuel_pulled then
            print("WARNING: Could not find suitable fuel in the chest.")
        end

    else
        print("ERROR: No inventory peripheral found below (expected fuel chest).")
    end

    -- Move back down to the layer below the chest (which is Y=0 if called from home)
    go_down()
    print("Fuel chest access complete.")

    -- Now that fuel is in slot 1 (hopefully), refuel the turtle normally
    if turtle.getItemCount(1) > 0 then
        turtle.select(1)
        turtle.refuel()
        print("Refueled turtle successfully.")
    end

    return true
end

-- Returns the turtle to the starting column (X=0, Z=0) on the current Y layer.
local function return_home()
    print("Returning home to (" .. x .. ", " .. y .. ", " .. z .. ")")

    -- 1. Correct Z position (Z is depth, North/South)
    while direction ~= 2 do turn_right() end -- Face South (Z increases)
    while z ~= 0 do
        if z < 0 then
            if not go_forward() then return false end
        else
            if not go_back() then return false end
        end
    end

    -- 2. Correct X position (East/West)
    while direction ~= 1 do turn_right() end -- Face East (X increases)
    while x ~= 0 do
        if x < 0 then
            if not go_back() then return false end -- Move West (X decreases)
        else
            if not go_forward() then return false end -- Move East (X increases)
        end
    end

    print("Returned to starting column (0, 0, " .. y .. ").")
    return true
end

-- Checks if the inventory is getting full or if the fuel is low, and triggers homing.
local function check_status()
    local inventory_full = false
    -- Check the last few slots for items
    for slot = 13, 16 do
        if turtle.getItemCount(slot) > 0 then
            inventory_full = true
            break
        end
    end

    -- Check if refueling is needed OR if inventory is full
    if turtle.getFuelLevel() < 100 or inventory_full then
        print("Status check triggered (Fuel low or Inventory full).")

        -- 1. Save current state
        local start_x, start_z, start_y = x, z, y
        local start_direction = direction

        -- 2. Return to the starting column (0, 0, start_y)
        local success = return_home()
        if not success then
            print("CRITICAL ERROR: Failed to return home. Cannot continue.")
            return false
        end

        -- 3. Move up to Y=0 plane to access the fuel chest and hopper below
        while y < 0 do go_up() end
        while y > 0 do go_down() end -- Should only be needed if an error occurred

        -- 4. Refuel (at X=0, Z=0, Y=0)
        refuel_from_chest()

        -- 5. Unload items (into the hopper below the start spot)
        unload_inventory()

        -- 6. Return to original mining location (x, z, y)
        print("Returning to mining location: (" .. start_x .. ", " .. start_y .. ", " .. start_z .. ")")

        -- Reset direction to North (0) to simplify homing logic for X/Z pathfinding
        while direction ~= 0 do turn_right() end

        -- Correct X and Z position (simplified pathfinding back)
        while direction ~= 2 do turn_right() end -- Face South (Z increases)
        while z < start_z do go_forward() end
        while z > start_z do go_back() end

        while direction ~= 1 do turn_right() end -- Face East (X increases)
        while x < start_x do go_forward() end
        while x > start_x do go_back() end

        -- Move down to the correct Y layer (from y=0 to start_y)
        while y > start_y do go_down() end

        -- Restore original direction to continue the serpentine pattern
        while direction ~= start_direction do turn_right() end

        print("Ready to resume excavation.")
    end
    return true
end

-- --- MOVEMENT & MINING LOGIC ---

-- Digs a single row and moves the turtle to the next column's starting position.
local function dig_row(row_index)
    for i = 1, CHUNK_SIZE do
        local success, reason = turtle.dig()
        if not success and reason ~= "Blocked" then
            print("Dig failed: " .. tostring(reason))
        end

        if i % 4 == 0 then
            if not check_status() then return false end
        end

        if i < CHUNK_SIZE then
            local moved = go_forward()
            if not moved then
                print("Cannot move forward! Stopping.")
                return false
            end
        end
    end

    if not check_status() then return false end

    if row_index < CHUNK_SIZE then
        local moved_right = false

        -- Serpentine pattern: turn right-forward-right for odd rows, left-forward-left for even
        if row_index % 2 ~= 0 then
            turn_right()
            moved_right = go_forward()
            turn_right()
        else
            turn_left()
            moved_right = go_forward()
            turn_left()
        end

        if not moved_right then
            print("Cannot advance to the next column. Halting.")
            return false
        end
    end

    return true
end

-- Excavates a single 16x16 layer completely.
local function excavate_layer()
    print("Starting new layer excavation. Current Y: " .. y)
    local success = true

    for row = 1, CHUNK_SIZE do
        -- Move back to the start of the row before digging
        if row > 1 then
            for i = 1, CHUNK_SIZE - 1 do
                go_back()
            end
        end

        success = dig_row(row)
        if not success then return false end
    end

    print("Layer complete.")
    return true
end

-- --- MAIN PROGRAM ---

local function main()
    print("--- CHUNK QUARRY STARTING ---")
    print("Size: 16x16. Refueling/Unloading at (0, 0, 0) spot.")

    -- Initial status check before starting the deep work
    if not check_status() then return end

    -- Loop to continuously excavate layers downwards
    while true do
        local layer_success = excavate_layer()
        if not layer_success then
            print("Layer excavation failed. Stopping.")
            break
        end

        print("Attempting to move down...")
        local down_success, down_reason = go_down()

        if not down_success then
            print("Cannot move down: " .. tostring(down_reason))
            print("Final homing and unload...")
            -- Return home, refuel, and unload one last time
            return_home()
            while y < 0 do go_up() end -- Move back to Y=0 to access chest/hopper
            refuel_from_chest()
            unload_inventory()
            print("--- CHUNK QUARRY FINISHED ---")
            break
        end

        if not check_status() then break end
    end
end

main()
