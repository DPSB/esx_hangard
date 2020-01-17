local GUI, PlayerData, CurrentActionData, Categories, Vehicles, LastVehicles = {}, {}, {}, {}, {}, {}
local HasAlreadyEnteredMarker, IsInShopMenu = false, false
local LastZone, CurrentGarage, CurrentAction, CurrentVehicleData, CurrentActionMsg
local closest                 = 0

ESX                           = nil
GUI.Time                      = 0

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

-- Create Blips
Citizen.CreateThread(function()
		
	for k,v in pairs(Config.Garages) do

    local blip = AddBlipForCoord(v.Marker.x, v.Marker.y, v.Marker.z)

    SetBlipSprite (blip, 473)
    SetBlipDisplay(blip, 4)
    SetBlipScale  (blip, 0.9)
    SetBlipColour (blip, 3)
    SetBlipAsShortRange(blip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Hangard")
    EndTextCommandSetBlipName(blip)
	end
end)

-- Display markers
Citizen.CreateThread(function()
	while true do
		
		Wait(0)
		
		local playerPed = GetPlayerPed(-1)
		local coords    = GetEntityCoords(playerPed)

		for k,v in pairs(Config.Garages) do

      if(GetDistanceBetweenCoords(coords, v.Marker.x, v.Marker.y, v.Marker.z, true) < Config.DrawDistance) then
        DrawMarker(Config.MarkerType, v.Marker.x, v.Marker.y, v.Marker.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
      end	
		end
	end
end)

-- Enter / Exit marker events
Citizen.CreateThread(function ()
  while true do
    Wait(0)

    local coords      = GetEntityCoords(GetPlayerPed(-1))
    local isInMarker  = false
    local currentZone = nil

    for k,v in pairs(Config.Garages) do
      if(GetDistanceBetweenCoords(coords, v.Marker.x, v.Marker.y, v.Marker.z, true) < v.Size.x) then
        isInMarker  = true
        currentZone = k
        CurrentGarage = v
      end
    end

    if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
      HasAlreadyEnteredMarker = true
      LastZone                = currentZone
      TriggerEvent('esx_hangard:hasEnteredMarker', currentZone)
    end

    if not isInMarker and HasAlreadyEnteredMarker then
      HasAlreadyEnteredMarker = false
      TriggerEvent('esx_hangard:hasExitedMarker', LastZone)
    end
  end
end)

-- Key controls
Citizen.CreateThread(function ()
  while true do
    Citizen.Wait(0)

    if CurrentAction ~= nil then

      local playerPed  = GetPlayerPed(-1)
      if IsPedInAnyVehicle(playerPed) then
        DisplayHelpText("Presse ~INPUT_CONTEXT~ pour ~g~RANGER~w~ le vehicule")
      else
        DisplayHelpText("Presse ~INPUT_CONTEXT~ pour ~b~OUVRIR~w~ votre hangard")
      end

      if IsControlPressed(0, 38) and (GetGameTimer() - GUI.Time) > 300 then
        if CurrentAction == 'parking_menu' then

          local coords      = GetEntityCoords(GetPlayerPed(-1))

          for k,v in pairs(Config.Garages) do
            if(GetDistanceBetweenCoords(coords, v.Marker.x, v.Marker.y, v.Marker.z, true) < v.Size.x) then

              if IsPedInAnyVehicle(playerPed) then

                local vehicle       = GetVehiclePedIsIn(playerPed)
                local vehicleProps  = ESX.Game.GetVehicleProperties(vehicle)
                local name          = GetDisplayNameFromVehicleModel(vehicleProps.model)
                local plate         = vehicleProps.plate

                ESX.TriggerServerCallback('esx_hangard:checkIfVehicleIsOwned', function (owned)

                  if owned ~= nil then                    
                    TriggerServerEvent("esx_hangard:updateOwnedVehicle", vehicleProps)
                    TriggerServerEvent("esx_hangard:addCarToParking", vehicleProps)

                    TaskLeaveVehicle(playerPed, vehicle, 16)
                    ESX.Game.DeleteVehicle(vehicle)
                  else
                    DisplayHelpText("Sais pas ton vehicule")
                  end
                end, vehicleProps.plate)

                --WarMenu.OpenMenu('park')

              else 

                SendNUIMessage({
                  clearme = true
                })

                ESX.TriggerServerCallback('esx_hangard:getVehiclesInGarage', function (vehicles)

                  for i=1, #vehicles, 1 do
                    SendNUIMessage({
                      addcar = true,
                      number = i,
                      model = vehicles[i].plate,
                      name = GetDisplayNameFromVehicleModel(vehicles[i].model)
                    })
                  end
                end)

                openGui()
              end
            end
          end

          --WarMenu.OpenMenu('Parking')

        end

        CurrentAction = nil
        GUI.Time      = GetGameTimer()
      end
    end
  end
end)

-- Open Gui and Focus NUI
function openGui()
  SetNuiFocus(true, true)
  SendNUIMessage({openBank = true})
end

-- Close Gui and disable NUI
function closeGui()
  SetNuiFocus(false)
  SendNUIMessage({openBank = false})
  bankOpen = false
  atmOpen = false
end

-- NUI Callback Methods
RegisterNUICallback('close', function(data, cb)
  closeGui()
  cb('ok')
end)

-- NUI Callback Methods
RegisterNUICallback('pullCar', function(data, cb)

  local playerPed  = GetPlayerPed(-1)

  ESX.TriggerServerCallback('esx_hangard:checkIfVehicleIsOwned', function (owned)

			local spawnCoords  = {
				x = CurrentGarage.Marker.x,
				y = CurrentGarage.Marker.y,
				z = CurrentGarage.Marker.z,
			}

      TriggerServerEvent("esx_hangard:removeCarFromParking", owned.plate)

      ESX.Game.SpawnVehicle(owned.model, spawnCoords, 20, function(vehicle)
        TaskWarpPedIntoVehicle(playerPed,  vehicle,  -1)
        ESX.Game.SetVehicleProperties(vehicle, owned)
      end)
  end, data.model)

  closeGui()
  cb('ok')
end)

Citizen.CreateThread(function()

	WarMenu.CreateMenu('Parking', 'Mes vehicules')
	WarMenu.SetSubTitle('Parking', 'Hangard')

	WarMenu.CreateSubMenu('stored', 'Parking', 'Vehicule ranger')
  WarMenu.CreateSubMenu('closeMenu', 'stored', 'Tu es sur ?')
  WarMenu.CreateSubMenu('park', 'Parking', 'Tu veux rentre ce vehicule ?')

	WarMenu.SetTitleBackgroundColor('Parking', 120,120,120,255)
	WarMenu.SetTitleBackgroundColor('stored', 120,120,120,255)
	WarMenu.SetTitleBackgroundColor('closeMenu', 120,120,120,255)
	
	WarMenu.SetMenuBackgroundColor('Parking', 0,0,0,220)
	WarMenu.SetMenuBackgroundColor('stored', 0,0,0,220)
	WarMenu.SetMenuBackgroundColor('closeMenu', 0,0,0,220)
	
  WarMenu.CreateSubMenu('Banger', 'stored', 'Fuckin Banger')
end)

function DisplayHelpText(str)
	BeginTextCommandDisplayHelp("STRING")
	AddTextComponentScaleform(str)
	EndTextCommandDisplayHelp(0, 0, 1, -1)
end

AddEventHandler('esx_hangard:hasEnteredMarker', function (zone)

    CurrentAction     = 'parking_menu'
end)

AddEventHandler('esx_hangard:hasExitedMarker', function (zone)
  if IsInShopMenu then
    DisplayHelpText("Closed")
    WarMenu.CloseMenu()
    IsInShopMenu = false
    CurrentGarage = nil
  end

  CurrentAction = nil
end)
