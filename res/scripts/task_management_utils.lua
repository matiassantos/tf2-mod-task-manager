local tracelog = true
local util = {}
util.tracelog = tracelog
util.trace = function(...)
	if tracelog then 
		print("[TaskManagement]: " .. ...)
	end
end
function util.newButton(text, icon, maxSize) 
	local comp 
	local hasText = text and string.len(text)>0
	local textView = hasText and api.gui.comp.TextView.new(_(text))
	local imageView = icon and api.gui.comp.ImageView.new(icon)
	if not maxSize then maxSize = 24 end
	if imageView then 
		imageView:setMaximumSize(api.gui.util.Size.new( maxSize, maxSize ))
	end
	if textView and imageView then 
		local boxLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
		
		
		boxLayout:addItem(imageView)
		boxLayout:addItem(textView)
		comp = api.gui.comp.Component.new("TaskManagementButton")
		comp:setLayout(boxLayout)
	elseif textView then  
		comp = textView
	else 
		comp = imageView
	end 
	local button = api.gui.comp.Button.new(comp,false)
	button:addStyleClass("TaskManagementButton")
	return button
end

util.handleCallback = function (res, success)
		if not success and util.tracelog then 
			trace("command was completed, success= ",success)
			if res and res.resultProposalData then
				util.trace(res.resultProposalData.errorState)
				util.trace(res.resultProposalData.collisionInfo)
			else 
				util.trace(res)
			end
		else
		end
end

return util