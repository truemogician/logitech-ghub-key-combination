--Extent methods for standard libraries
string.at=function(self,index)
	return self:sub(index,index)
end
string.isdigit=function(char)
	return char>="0" and char<="9"
end
string.totable=function(self)
	local result={}
	for i=1,self:len() do
		result[i]=self:at(i)
	end
	return result
end
table.reverse=function(list,i,j)
	i=i or 1
	j=j or #list
	local tmp=nil
	for index=i,i+(j-i)/2 do
		tmp=list[index]
		list[index]=list[j-index+i]
		list[j-index+i]=tmp
	end
	return list
end
table.print=function(list)
	local result=""
	for i,v in ipairs(list) do
		result=result.." "..v
	end
	print(result)
end
table.copy=function(src)
	local list={}
	for key,value in pairs(src) do
		if type(value)=="table" then
			list[key]=table.copy(value)
		else
			list[key]=value
		end
	end
	return list
end
table.tostring=function(list)
	local result=""
	for i,v in ipairs(list) do
		result=result..v
	end
	return result
end
--A collection of actions provided by G-series Lua API
Action={
	Debug={
		Print=function(self,...)
			local args={...}
			return function()
				local content=""
				for index,value in ipairs(args) do
					content=content..value
				end
				OutputLogMessage(content.."\n")
			end
		end,
		Clear=function()
			return function()
				ClearLog()
			end
		end,
	},
	KeysAndButtons={
		Press=function (self,keysAndButtons)
			return function()
				for index,value in ipairs(keysAndButtons) do
					if type(value)=="string" then
						PressKey(value)
					elseif type(value)=="number" then
						PressMouseButton(value)
					end
				end
			end
		end,
		Release=function (self,keysAndButtons)
			return function()
				for index,value in ipairs(keysAndButtons) do
					if type(value)=="string" then
						ReleaseKey(value)
					elseif type(value)=="number" then
						ReleaseMouseButton(value)
					end
				end
			end
		end,
		ClickNestedly=function (self,keysAndButtons)
			return function()
				local length=#keysAndButtons
				for i=1,length do
					local value=keysAndButtons[i]
					if type(value)=="string" then
						PressKey(value)
					elseif type(value)=="number" then
						PressMouseButton(value)
					end
				end
				for i=length,1,-1 do
					local value=keysAndButtons[i]
					if type(value)=="string" then
						ReleaseKey(value)
					elseif type(value)=="number" then
						ReleaseMouseButton(value)
					end
				end
			end
		end,
		Click=function (self,keysAndButtons)
			return function()
				for index,value in ipairs(keysAndButtons) do
					if type(value)=="string" then
						PressAndReleaseKey(value)
					elseif type(value)=="number" then
						PressAndReleaseMouseButton(value)
					end
				end
			end
		end,
	},
	Wheel={
		MoveUp=function(self,count)
			return function()
				MoveMouseWheel(count)
			end
		end,
		MoveDown=function(self,count)
			return function()
				MoveMouseWheel(-count)
			end
		end,
	},
	Cursor={
		Resolution={Width=1920,Height=1080},
		Move=function(self,x,y)
			return function()
				MoveMouseRelative(x*self.Resolution.Width/65535,y*self.Resolution.Height/65535)
			end
		end,
		MoveTo=function(self,x,y)
			return function()
				MoveMouseTo(x*self.Resolution.Width/65535,y*self.Resolution.Height/65535)
			end
		end,
	},
	Macro={
		AbortOtherMacrosBeforePlay=false,
		Play=function(self,macroName)
			return function()
				if self.AbortOtherMacrosBeforePlay then
					AbortMacro()
				end
				PlayMacro(macroName)
			end
		end
	},
}
--Event handler for combined key event
function EncodeButton(button)
	if button<10 then
		return string.char(button+48)
	else
		return string.char(button+55)
	end
end
function DecodeButton(buttonCode)
	if string.isdigit(buttonCode) then
		return string.byte(buttonCode)-48
	else
		return string.byte(buttonCode)-55
	end
end
function NextPermutation(list)
	local length=#list
	local k,l=0,0
	for i=length-1,1,-1 do
		if list[i]<list[i+1] then
			k=i
			break
		end
	end
	if k==0 then
		return false
	end
	for i=length,k+1,-1 do
		if list[k]<list[i] then
			l=i
			break
		end
	end
	local tmp=list[k]
	list[k]=list[l]
	list[l]=tmp
	table.reverse(list,k+1,length)
	return true
end
CombinedEventHandler={
	PressedButtons="",
	Event={
		List={},
		Current="",
		Register=function(self,combination,action,unorderedGroup)
			local unorderedGroupIndex
			if unorderedGroup then
				if type(unorderedGroup[1])=="number" then
					unorderedGroup={unorderedGroup}
				end
				local indexTable={}
				for i=1,#combination do
					indexTable[combination[i]]=i
				end
				for i=1,#unorderedGroup do
					for j=1,#unorderedGroup[i] do
						unorderedGroup[i][j]=indexTable[unorderedGroup[i][j]]
					end
				end
				for i=1,#unorderedGroup do
					table.sort(unorderedGroup[i])
				end
				unorderedGroupIndex=table.copy(unorderedGroup)
			end
			--Get identifier
			local identifier=table.tostring(combination)
			local initialTable=identifier:totable()
			while true do
				--Event already exists
				if self.List[identifier] then
					self.List[identifier].Action=action
				else
					--Check whether current event is a leaf event
					local isLeaf=true
					for name in pairs(self.List) do
						if name:sub(1,#identifier)==identifier then
							isLeaf=false
							break
						end
					end
					--Update prefixs if being a leaf event
					if isLeaf then
						for i=1,#identifier-1 do
							local prefix=identifier:sub(1,i)
							if self.List[prefix] then
								self.List[prefix].IsLeaf=false
							end
						end
					end
					--Add event to EventList
					self.List[identifier]={IsLeaf=isLeaf,Action=action}
				end
				if unorderedGroup==nil then
					break
				end
				local finished=true
				for i=#unorderedGroup,1,-1 do
					if NextPermutation(unorderedGroup[i]) then
						finished=false
						break
					else
						table.reverse(unorderedGroup[i])
					end
				end
				if finished then
					break
				end
				local identifierTable=table.copy(initialTable)
				for i=1,#unorderedGroup do
					for j=1,#unorderedGroup[i] do
						identifierTable[unorderedGroupIndex[i][j]]=initialTable[unorderedGroup[i][j]]
					end
				end
				identifier=table.tostring(identifierTable)
			end
		end,
		RegisterPressed=function(self,combination,pAction,unorderedGroup)
			self:Register(combination,{Pressed=pAction},unorderedGroup)
		end,
		RegisterReleased=function(self,combination,rAction,unorderedGroup)
			self:Register(combination,{Released=rAction},unorderedGroup)
		end,
		RegisterPressedAndReleassed=function(self,combination,pAction,rAction,unorderedGroup)
			self:Register(combination,{Pressed=pAction,Released=rAction},unorderedGroup)
		end,
		RegisterBind=function(self,srcCombination,dstCombination,unorderedGroup)
			local reversedDstCombination={}
			for i=1,#dstCombination do
				reversedDstCombination[i]=dstCombination[#dstCombination-i+1]
			end
			self:Register(srcCombination,{
				Pressed=Action.KeysAndButtons:Press(dstCombination),
				Released=Action.KeysAndButtons:Release(reversedDstCombination)
			},unorderedGroup)
		end,
		RegisterReleasedBind=function(self,srcCombination,dstCombination,unorderedGroup)
			self:Register(srcCombination,{
				Released=Action.KeysAndButtons:ClickNestedly(dstCombination),
			},unorderedGroup)
		end,
		RegisterReleasedMacro=function(self,srcCombination,macroName,unorderedGroup)
			self:Register(srcCombination,{
				Released=Action.Macro:Play(macroName),
			},unorderedGroup)
		end
	},
	SpecialHandlers={},
	AddSpecialHandler=function(self,handle,auxiliary)
		self.SpecialHandlers[#self.SpecialHandlers+1] = {
			Handle=handle,
			Auxiliary=auxiliary,
		}
	end,
	PressButton=function(self,button)
		for i=1,#self.SpecialHandlers do
			self.SpecialHandlers[i]:Handle("press",button,self.PressedButtons)
		end
		self.PressedButtons=self.PressedButtons..EncodeButton(button)
		local event=self.Event.List[self.PressedButtons]
		if event then
			self.Event.Current=self.PressedButtons
			if event.Action.Pressed then
				event.Action.Pressed()
			end
		end
	end,
	ReleaseButton=function(self,button)
		for i=1,#self.SpecialHandlers do
			self.SpecialHandlers[i]:Handle("release",button,self.PressedButtons)
		end
		local event=self.Event.List[self.Event.Current]
		if event and self.Event.Current:find(EncodeButton(button)) then
			if event.Action.Released then
				event.Action.Released()
			end
			self.Event.Current=""
		end
		local position=self.PressedButtons:find(EncodeButton(button))
		if position then
			self.PressedButtons=self.PressedButtons:sub(1,position-1)..self.PressedButtons:sub(position+1)
		end
	end
}
--Basic event handler provided by G-series Lua API
Event={
	Pressed="MOUSE_BUTTON_PRESSED",
	Released="MOUSE_BUTTON_RELEASED",
	Activated="PROFILE_ACTIVATED",
	Deactivated="PROFILE_DEACTIVATED",
}
EnablePrimaryMouseButtonEvents(true)
function OnEvent(event, arg)
	if event==Event.Pressed then
		CombinedEventHandler:PressButton(arg)
	elseif event==Event.Released then
		CombinedEventHandler:ReleaseButton(arg)
	elseif event==Event.Activated then
		Action.Cursor.Resolution={Width=Settings.ScreenResolution[1],Height=Settings.ScreenResolution[2]}
	end
end
--Enums for some mouse action parameters
MouseButton={
	Primary=1,
	Secondary=2,
	Middle=3,
	SideBack=4,
	SideMiddle=5,
	SideFront=6,
	AuxiliaryBack=7,
	AuxiliaryFront=8,
	Back=9,
	WheelRight=10,
	WheelLeft=11,
}
MouseFunction={
	PrimaryClick=1,
	MiddleClick=2,
	SecondaryClick=3,
	Forward=4,
	Back=5
}
function RegisterBasicFunctions()
	CombinedEventHandler.Event:RegisterBind({MouseButton.Primary},{MouseFunction.PrimaryClick})
	CombinedEventHandler.Event:RegisterBind({MouseButton.Secondary},{MouseFunction.SecondaryClick})
	CombinedEventHandler.Event:RegisterBind({MouseButton.Middle},{MouseFunction.MiddleClick})
	CombinedEventHandler.Event:RegisterBind({MouseButton.SideMiddle},{MouseFunction.Forward})
	CombinedEventHandler.Event:RegisterBind({MouseButton.SideBack},{MouseFunction.Back})
end
--Customize combined key actions here
Settings={
	ScreenResolution={1920,1080},
}
CombinedEvent=CombinedEventHandler.Event