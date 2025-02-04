
local DF = _G ["DetailsFramework"]
if (not DF or not DetailsFrameworkCanLoad) then
	return
end

local _

DF.DefaultMetaFunctionsGet = {
	parent = function(object)
		return object:GetParent()
	end,
}

DF.DefaultMetaFunctionsSet = {
	parent = function(object, value)
		return object:SetParent(value)
	end,
}

DF.SetPointMixin = {
	SetPoint = function(object, achorName1, anchorObject, anchorName2, xOffset, yOffset)
		xOffset = xOffset or 0
		yOffset = yOffset or 0

		--offset always inset to inner
		if (achorName1 == "lefts") then
			object:SetAllPoints()
			object:SetPoint("topleft", anchorObject, "topleft", xOffset, -yOffset)
			object:SetPoint("bottomleft", anchorObject, "bottomleft", xOffset, yOffset)
			return

		elseif (achorName1 == "rights") then
			object:SetPoint("topright", anchorObject, "topright", xOffset, -yOffset)
			object:SetPoint("bottomright", anchorObject, "bottomright", xOffset, yOffset)
			return

		elseif (achorName1 == "tops") then
			object:SetPoint("topleft", anchorObject, "topleft", xOffset, -yOffset)
			object:SetPoint("topright", anchorObject, "topright", -xOffset, -yOffset)
			return

		elseif (achorName1 == "bottoms") then
			object:SetPoint("bottomleft", anchorObject, "bottomleft", xOffset, yOffset)
			object:SetPoint("bottomright", anchorObject, "bottomright", -xOffset, yOffset)
			return
		end

		achorName1, anchorObject, anchorName2, xOffset, yOffset = DF:CheckPoints(achorName1, anchorObject, anchorName2, xOffset, yOffset, object)
		if (not achorName1) then
			error("SetPoint: Invalid parameter.")
			return
		end
		return object.widget:SetPoint(achorName1, anchorObject, anchorName2, xOffset, yOffset)
	end,
}

--mixin for options functions
DF.OptionsFunctions = {
	SetOption = function (self, optionName, optionValue)
		if (self.options) then
			self.options [optionName] = optionValue
		else
			self.options = {}
			self.options [optionName] = optionValue
		end

		if (self.OnOptionChanged) then
			DF:Dispatch (self.OnOptionChanged, self, optionName, optionValue)
		end
	end,

	GetOption = function (self, optionName)
		return self.options and self.options [optionName]
	end,

	GetAllOptions = function (self)
		if (self.options) then
			local optionsTable = {}
			for key, _ in pairs (self.options) do
				optionsTable [#optionsTable + 1] = key
			end
			return optionsTable
		else
			return {}
		end
	end,

	BuildOptionsTable = function (self, defaultOptions, userOptions)
		self.options = self.options or {}
		DF.table.deploy (self.options, userOptions or {})
		DF.table.deploy (self.options, defaultOptions or {})
	end
}

--payload mixin
DF.PayloadMixin = {
	ClearPayload = function(self)
		self.payload = {}
	end,

	SetPayload = function(self, ...)
		self.payload = {...}
		return self.payload
	end,

	AddPayload = function(self, ...)
		local currentPayload = self.payload or {}
		self.payload = currentPayload

		for i = 1, select("#", ...) do
			local value = select(i, ...)
			currentPayload[#currentPayload+1] = value
		end

		return self.payload
	end,

	GetPayload = function(self)
		return self.payload
	end,

	DumpPayload = function(self)
		return unpack(self.payload)
	end,

	--does not copy wow objects, just pass them to the new table, tables strings and numbers are copied entirely
	DuplicatePayload = function(self)
		local duplicatedPayload = DF.table.duplicate({}, self.payload)
		return duplicatedPayload
	end,
}

DF.ScrollBoxFunctions = {
	Refresh = function(self)
		--hide all frames and tag as not in use
		for index, frame in ipairs(self.Frames) do
			frame:Hide()
			frame._InUse = nil
		end

		local offset = 0
		if (self.IsFauxScroll) then
			self:UpdateFaux(#self.data, self.LineAmount, self.LineHeight)
			offset = self:GetOffsetFaux()
		end

		DF:CoreDispatch((self:GetName() or "ScrollBox") .. ":Refresh()", self.refresh_func, self, self.data, offset, self.LineAmount)

		for index, frame in ipairs(self.Frames) do
			if (not frame._InUse) then
				frame:Hide()
			else
				frame:Show()
			end
		end

		self:Show()

		if (self.HideScrollBar) then
			local frameName = self:GetName()
			if (frameName) then
				local scrollBar = _G[frameName .. "ScrollBar"]
				if (scrollBar) then
					scrollBar:Hide()
				end
			end
		end
		return self.Frames
	end,

	OnVerticalScroll = function(self, offset)
		self:OnVerticalScrollFaux(offset, self.LineHeight, self.Refresh)
		return true
	end,

	CreateLine = function(self, func)
		if (not func) then
			func = self.CreateLineFunc
		end
		local okay, newLine = pcall(func, self, #self.Frames+1)
		if (okay) then
			tinsert(self.Frames, newLine)
			newLine.Index = #self.Frames
			return newLine
		else
			error("Details! FrameWork: CreateLine(): " .. newLine)
		end
	end,

	GetLine = function(self, lineIndex)
		local line = self.Frames[lineIndex]
		if (line) then
			line._InUse = true
		end
		return line
	end,

	SetData = function(self, data)
		self.data = data
	end,
	GetData = function(self)
		return self.data
	end,

	GetFrames = function(self)
		return self.Frames
	end,
	GetLines = function(self) --alias of GetFrames
		return self.Frames
	end,

	GetNumFramesCreated = function(self)
		return #self.Frames
	end,

	GetNumFramesShown = function(self)
		return self.LineAmount
	end,

	SetNumFramesShown = function(self, newAmount)
		--hide frames which won't be used
		if (newAmount < #self.Frames) then
			for i = newAmount+1, #self.Frames do
				self.Frames[i]:Hide()
			end
		end
		--set the new amount
		self.LineAmount = newAmount
	end,

	SetFramesHeight = function(self, height)
		self.LineHeight = height
		self:OnSizeChanged()
		self:Refresh()
	end,

	OnSizeChanged = function(self)
		if (self.ReajustNumFrames) then
			--how many lines the scroll can show
			local amountOfFramesToShow = floor(self:GetHeight() / self.LineHeight)

			--how many lines the scroll already have
			local totalFramesCreated = self:GetNumFramesCreated()

			--how many lines are current shown
			local totalFramesShown = self:GetNumFramesShown()

			--the amount of frames increased
			if (amountOfFramesToShow > totalFramesShown) then
				for i = totalFramesShown+1, amountOfFramesToShow do
					--check if need to create a new line
					if (i > totalFramesCreated) then
						self:CreateLine(self.CreateLineFunc)
					end
				end

			--the amount of frames decreased
			elseif (amountOfFramesToShow < totalFramesShown) then
				--hide all frames above the new amount to show
				for i = totalFramesCreated, amountOfFramesToShow, -1 do
					if (self.Frames[i]) then
						self.Frames[i]:Hide()
					end
				end
			end

			--set the new amount of frames
			self:SetNumFramesShown(amountOfFramesToShow)
			--refresh lines
			self:Refresh()
		end
	end,

	--moved functions from blizzard faux scroll that are called from insecure code environment
	--this reduces the amount of taints while using the faux scroll frame
	GetOffsetFaux = function(self)
		return self.offset or 0
	end,
	OnVerticalScrollFaux = function(self, value, itemHeight, updateFunction)
		local scrollbar = self:GetChildFramesFaux();
		scrollbar:SetValue(value);
		self.offset = math.floor((value / itemHeight) + 0.5);
		if (updateFunction) then
			updateFunction(self)
		end
	end,
	GetChildFramesFaux = function(frame)
		local frameName = frame:GetName();
		if frameName then
			return _G[ frameName.."ScrollBar" ], _G[ frameName.."ScrollChildFrame" ], _G[ frameName.."ScrollBarScrollUpButton" ], _G[ frameName.."ScrollBarScrollDownButton" ];
		else
			return frame.ScrollBar, frame.ScrollChildFrame, frame.ScrollBar.ScrollUpButton, frame.ScrollBar.ScrollDownButton;
		end
	end,
	UpdateFaux = function(frame, numItems, numToDisplay, buttonHeight, button, smallWidth, bigWidth, highlightFrame, smallHighlightWidth, bigHighlightWidth, alwaysShowScrollBar)
		local scrollBar, scrollChildFrame, scrollUpButton, scrollDownButton = frame:GetChildFramesFaux();
		-- If more than one screen full of items then show the scrollbar
		local showScrollBar;
		if ( numItems > numToDisplay or alwaysShowScrollBar ) then
			frame:Show();
			showScrollBar = 1;
		else
			scrollBar:SetValue(0);
			frame:Hide();
		end
		if ( frame:IsShown() ) then
			local scrollFrameHeight = 0;
			local scrollChildHeight = 0;

			if ( numItems > 0 ) then
				scrollFrameHeight = (numItems - numToDisplay) * buttonHeight;
				scrollChildHeight = numItems * buttonHeight;
				if ( scrollFrameHeight < 0 ) then
					scrollFrameHeight = 0;
				end
				scrollChildFrame:Show();
			else
				scrollChildFrame:Hide();
			end
			local maxRange = (numItems - numToDisplay) * buttonHeight;
			if (maxRange < 0) then
				maxRange = 0;
			end
			scrollBar:SetMinMaxValues(0, maxRange);
			scrollBar:SetValueStep(buttonHeight);
			scrollBar:SetStepsPerPage(numToDisplay-1);
			scrollChildFrame:SetHeight(scrollChildHeight);

			-- Arrow button handling
			if ( scrollBar:GetValue() == 0 ) then
				scrollUpButton:Disable();
			else
				scrollUpButton:Enable();
			end
			if ((scrollBar:GetValue() - scrollFrameHeight) == 0) then
				scrollDownButton:Disable();
			else
				scrollDownButton:Enable();
			end

			-- Shrink because scrollbar is shown
			if ( highlightFrame ) then
				highlightFrame:SetWidth(smallHighlightWidth);
			end
			if ( button ) then
				for i=1, numToDisplay do
					_G[button..i]:SetWidth(smallWidth);
				end
			end
		else
			-- Widen because scrollbar is hidden
			if ( highlightFrame ) then
				highlightFrame:SetWidth(bigHighlightWidth);
			end
			if ( button ) then
				for i=1, numToDisplay do
					_G[button..i]:SetWidth(bigWidth);
				end
			end
		end
		return showScrollBar;
	end,
}

local SortMember = ""
local SortByMember = function (t1, t2)
	return t1[SortMember] > t2[SortMember]
end
local SortByMemberReverse = function (t1, t2)
	return t1[SortMember] < t2[SortMember]
end

DF.SortFunctions = {
	Sort = function(self, thisTable, memberName, isReverse)
		SortMember = memberName
		if (not isReverse) then
			table.sort(thisTable, SortByMember)
		else
			table.sort(thisTable, SortByMemberReverse)
		end
	end
}



