--[[
  DIAMOND TUNNEL MINER (tunnel.lua) 11
  
  This script digs a straight 1x2 tunnel forward, checking for diamonds 
  and automatically returning to its starting point when fuel is low.
  
  SETUP INSTRUCTIONS:
  1. Place the Mining Turtle at the desired diamond level (Y=11 is common).
  2. Place Coal or Charcoal in slot 16 (the last slot).
  3. Run the script: tunnel
--]]

-- Configuration
local FUEL_SLOT = 16
local RETURN_FUEL_BUFFER = 30 -- Moves needed to return to the start (1 move = 1 block/turn)
local MOVE_COST_PER_PASS = 3  -- forward (1) + dig (1) + dig (1) = 3 fuel units per block mined

-- State Tracking
local tunnelLength = 0 -- Tracks the distance from the starting position
local homeSafe = true  -- Flag to ensure the turtle starts and stops cleanly

-- ====================
-- CORE MOVEMENT FUNCTIONS
-- ====================

-- Digs forward one block and moves forward, handling the two-block high tunnel.
local function moveAndDig()
    -- 1. Dig Forward (Block 1)
    if turtle.detect() then
        turtle.dig()
    end
    
    -- 2. Dig Up (Block 2)
    if turtle.detectUp() then
        turtle.digUp()
    end

    -- 3. Move Forward
    local success = turtle.forward()
    if success then
        tunnelLength = tunnelLength + 1
        return true
    else
        -- If movement failed (e.g., hit unbreakable block)
        print("Movement blocked at step " .. tunnelLength + 1 .. ". Halting.")
        return false
    end
end

-- Checks fuel and refuels if necessary and possible
local function checkAndRefuel()
    -- Check fuel level
    if turtle.getFuelLevel() < RETURN_FUEL_BUFFER then
        print("Fuel critically low. Attempting to refuel.")
        
        -- Select the fuel slot
        turtle.select(FUEL_SLOT)
        
        -- Attempt to consume one fuel item
        if turtle.refuel(1) then
            print("Refuel successful. Current fuel: " .. turtle.getFuelLevel())
            turtle.select(1) -- Select the default tool slot
            return true
        else
            print("Refuel failed: No fuel in slot " .. FUEL_SLOT .. " or turtle is full.")
            turtle.select(1) -- Select the default tool slot
            return false
        end
    end
    return true -- Fuel is okay
end

-- ====================
-- AUTOMATION LOGIC
-- ====================

local function goHome()
    print("--- Fuel is low. Returning to start point. ---")
    
    -- Turn 180 degrees
    turtle.turnLeft()
    turtle.turnLeft()
    
    -- Travel back the recorded length
    local returnCount = 0
    while returnCount < tunnelLength do
        -- Check fuel again, just in case (shouldn't be necessary if BUFFER is right)
        if turtle.getFuelLevel() < 1 then
            print("EMERGENCY STOP! Ran out of fuel while returning!")
            return false
        end

        -- Move backward (which is forward after turning 180)
        local success = turtle.forward()
        if success then
            returnCount = returnCount + 1
            print("Returning... " .. tunnelLength - returnCount .. " blocks left.")
        else
            print("Obstacle encountered during return trip. Pausing.")
            return false
        end
    end
    
    print("--- Turtle has arrived home. ---")
    homeSafe = true
    return true
end

local function runMiner()
    -- Ensure homeSafe flag is cleared
    homeSafe = false 

    -- Get the distance that requires a return
    local distanceForReturn = (turtle.getFuelLevel() - RETURN_FUEL_BUFFER) / MOVE_COST_PER_PASS
    print("Maximum tunnel length before return: " .. math.floor(distanceForReturn) .. " blocks.")
    
    -- Main mining loop
    while not homeSafe do
        -- 1. Check fuel buffer before mining the next step
        local movesLeft = turtle.getFuelLevel()
        local distanceTraveled = tunnelLength
        
        -- Calculate the fuel needed to return from the current point
        local fuelToReturn = distanceTraveled + RETURN_FUEL_BUFFER
        
        if movesLeft <= fuelToReturn then
            -- Fuel is too low; initiate return sequence
            if not goHome() then
                print("Returning home failed. Turtle is stuck!")
                return
            end
            break -- Exit the mining loop
        end
        
        -- 2. Refuel Check (Allows refueling if coal is available)
        if not checkAndRefuel() then
            -- If refuel fails, check if we need to return
            if movesLeft > fuelToReturn then
                -- Continue mining if we can still make it home
                print("Cannot refuel, but continuing until return point is met.")
            else
                -- If we can't refuel AND we can't make it home, we are stuck.
                print("FATAL: Cannot refuel and cannot return home. Stopping.")
                return
            end
        end

        -- 3. Execute Movement and Digging
        if not moveAndDig() then
            -- If moveAndDig failed due to obstacle, return home
            goHome()
            return 
        end
    end
end

-- ====================
-- START PROGRAM
-- ====================

-- Check if we have fuel (at least one coal for a clean start)
turtle.select(FUEL_SLOT)
if turtle.getItemCount(FUEL_SLOT) < 1 and turtle.getFuelLevel() < RETURN_FUEL_BUFFER then
    print("ERROR: Please put coal/charcoal in slot " .. FUEL_SLOT .. " to fuel the turtle.")
    return
end
turtle.select(1) -- Set selection back to the first slot (assuming a pickaxe is here)

print("Starting Diamond Tunnel Miner...")
runMiner()
print("Program finished.")
