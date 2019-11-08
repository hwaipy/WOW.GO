function HelloWorld() 
end

function searchFor(ids)
	for idi = 1, #ids do 
        id = ids[idi]
		for i=4,0,-1 do
			for j=GetContainerNumSlots(i)+1,1,-1 do
				if(GetContainerItemID(i, j) == id)
				then
					return i, j
				end
			end
		end
    end 	
	return -1, -1
end

local frame, events = CreateFrame("Frame"), {};
frame:SetScript("OnEvent", function(self, event, ...)
    if(event=="UNIT_SPELLCAST_SUCCEEDED")
	then
		temp = { ... }
		arg = select("1",temp)    --返回第一个参数和其之后的所有参数
      	if(arg[1] == "player" and arg[3] == 18248)
		then
			bagID, slot = searchFor({7973, 5523, 5524, 13874, 4603, 13754, 6362, 6289, 6291, 6303, 6308, 6317, 6361, 6362, 8365, 13758, 13759, 13760, 13889, 13893, 21071, })
			if(bagID >= 0)
			then
				if(not CursorHasItem())
				then
					PickupContainerItem(bagID, slot)
				end
				PickupContainerItem(4, GetContainerNumSlots(4))
			end
		end
	end
end);
--frame:RegisterEvent("BAG_UPDATE");
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");