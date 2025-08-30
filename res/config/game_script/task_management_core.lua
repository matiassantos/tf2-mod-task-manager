local util = require("task_management_utils")

local errorPanel
local errorMessage
local errorPayload

local function displayErrorPayload(payload)

	local window = api.gui.comp.Window.new(_('Error'), api.gui.comp.TextView.new(payload))
	window:setVisible(true,false)
	window:addHideOnCloseHandler()
end

local function err(x)
	print("An error was caught",x)
	local traceback = debug.traceback()
	print(traceback)
	errorMessage = _('An error occurred, see logs')
	errorPayload = x..traceback

	if errorPanel then
		errorPanel:setText(errorMessage)
		displayErrorPayload(errorPayload)
	end
end


local init = false
local loadCalled = false
local savedTodo = {}

local taskState = {
	debugLog = true,
	taskList = {},
	windowContainer = nil,
	todoListViewContainer = nil,
	todoTasksList = {},
	taskRowComponents = {}, -- Track UI rows for BoxLayout
	needsRefresh = false,
	isRefreshing = false,
	isFirstRun = true,
	commitChanges = true,
	showDone = false,
	showInProgress = true,
	showToDo = false,
	showActive = true,
	colorOptions = {
		{ name = "Red", color = {1, 0, 0, 1} },
		{ name = "Green", color = {0, 1, 0, 1} },
		{ name = "Blue", color = {0, 0, 1, 1} },
		{ name = "Yellow", color = {1, 1, 0, 1} },
		{ name = "Purple", color = {0.6, 0, 0.6, 1} },
		{ name = "Gray", color = {0.5, 0.5, 0.5, 1} }
	},
	referenceTypeOptions = {
		"None",
		"Industry",
		"Construction",
		"City"
	}
}

local function flagForRefresh()
	taskState.needsRefresh = true;
end

local trace = function (...)
    if taskState.debugLog then
		print("[TaskManagement]: " .. ...)
	end
end

local getToDoList = function ()
	return taskState.taskList
end

local taskStatuses = {
	pending = {
		state = 'PENDING'
	},
	inprogress = {
		state = 'IN_PROGRESS'
	},
	active = {
		state = 'ACTIVE'
	},
	done = {
		state = 'DONE'
	}

}

local function taskStatusFromString(inputString)
	trace("evaluating status"..inputString)
	if inputString == 'IN_PROGRESS' then
		return taskStatuses.inprogress.state
		elseif inputString == 'ACTIVE' then
			return taskStatuses.active.state
			elseif inputString == 'DONE' then
				return taskStatuses.done.state
	end
	return taskStatuses.pending.state
end

local function sanitizeTaskShape(task)
	local basicTaskShape = {
		title = "Untitled",
		description = "",
		color = {0.5, 0.5, 0.5, 1},
		reference = nil,
		referenceType = nil,
		label = "Untitled",
		status = taskStatuses.pending.state
	}
	if task then
		if task.title then basicTaskShape.title = tostring(task.title) end
		if task.description then basicTaskShape.description = tostring(task.description) end
		if task.color then basicTaskShape.color = task.color end
		if task.reference then basicTaskShape.reference = task.reference end
		if task.referenceType then basicTaskShape.referenceType = task.referenceType end
		if task.label then basicTaskShape.label = tostring(task.label) end
		if task.status then basicTaskShape.status = taskStatusFromString(task.status) end
	end
	return basicTaskShape
end


local function newTaskItem(taskData)
	-- taskData: {title, description, color, reference, referenceType}
	local t = {
		title = taskData.title or "Untitled",
		description = taskData.description or "",
		color = taskData.color or {0.5, 0.5, 0.5, 1},
		reference = taskData.reference,
		referenceType = taskData.referenceType,
		label = taskData.title or taskData.label or "Untitled",
		status = taskStatuses.pending.state
	}
	return sanitizeTaskShape(t)
end



local function persistingChanges()
	if taskState.commitChanges then
		trace("Commiting changes! ")
		api.cmd.sendCommand(api.cmd.make.sendScriptEvent("task_management_core.lua","persist", "", taskState.todoTasksList), util.handleCallback)
		trace("Command persist sent")
	end
end

local function addTaskRow(taskRow)
	trace("addTaskRow called")
	if taskState.todoListViewContainer then
		trace("Adding task row to todoListViewContainer")
		table.insert(taskState.taskRowComponents, taskRow)
		taskState.todoListViewContainer:addItem(taskRow)
	else
		trace("todoListViewContainer is nil in addTaskRow")
	end
end

local function getCountTasksOnDisplay()
	local n = #taskState.taskRowComponents
	trace("getCountTasksOnDisplay: " .. tostring(n))
	return n
end

-- removed duplicate clearAllItemsFromListView
local function clearAllItemsFromBoxLayout(layout)
	trace("clearAllItemsFromBoxLayout called")
	if not layout then trace("clearAllItemsFromBoxLayout: layout is nil"); return end
	if not layout.removeItem then
		trace("clearAllItemsFromBoxLayout: layout missing removeItem method")
		return
	end
	for i = #taskState.taskRowComponents, 1, -1 do
		local item = taskState.taskRowComponents[i]
		if item then
			layout:removeItem(item)
			trace("Removed item from BoxLayout at index " .. tostring(i))
		end
		table.remove(taskState.taskRowComponents, i)
	end
end

local function clearTodoListView()
	trace("clearTodoListView called")
	if taskState.todoListViewContainer then
		trace("clearTodoListView: calling clearAllItemsFromBoxLayout")
		clearAllItemsFromBoxLayout(taskState.todoListViewContainer)
		trace("Clearing all items SUCCESS")
	else
		trace("todoListViewContainer is not initialized")
	end
end


local function buildTaskActionButton(task)
	if task.status == taskStatuses.done.state or task.status == taskStatuses.pending.state then
		return util.newButton("", "ui/button/small/vehicle_replace_active.tga"):onClick(function ()
			trace("Task status is " .. task.status)
			trace("Setting status of task as " .. taskStatuses.inprogress.state)
			task.status = taskStatuses.inprogress.state
			persistingChanges()
			flagForRefresh()
		end)
		elseif task.status == taskStatuses.active.state or task.status == taskStatuses.inprogress.state then
			return util.newButton("", "ui/button/small/accept.tga"):onClick(function ()
				trace("Task status is " .. task.status)
				trace("Setting status of task as " .. taskStatuses.done.state)
				task.status = taskStatuses.done.state
				persistingChanges()
				flagForRefresh()
			end)
		end
end

local function buildTaskCard(task)
	local rowLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
	local orderLabel = api.gui.comp.TextView.new(tostring(getCountTasksOnDisplay() + 1))
	-- Color icon
	local colorIcon = api.gui.comp.Component.new()
	colorIcon:setMinimumSize(api.gui.util.Size.new(16, 16))
	colorIcon:setMaximumSize(api.gui.util.Size.new(16, 16))
	colorIcon:setStyle({ backgroundColor = task.color })
	-- Title and description
	local titleLabel = api.gui.comp.TextView.new(tostring(task.title or "Untitled"))
	local descLabel = api.gui.comp.TextView.new(tostring(task.description or ""))
	-- Action button
	local actionButton = buildTaskActionButton(task)
	rowLayout:addItem(colorIcon)
	rowLayout:addItem(orderLabel)
	rowLayout:addItem(titleLabel)
	rowLayout:addItem(descLabel)
	rowLayout:addItem(actionButton)
	-- Reference tag (industry/construction/city)
	if task.reference and task.referenceType then
		local refButton = api.gui.comp.Button.new(api.gui.comp.TextView.new("[" .. task.referenceType .. "]"), false)
		refButton:onClick(function()
			if api.engine.entityExists(task.reference) then
				if api.gui.util.CameraController.focus then
					api.gui.util.CameraController.focus(task.reference)
				else
					print("Camera function not available in this context.")
				end
			else
				print("Referenced entity not found: " .. tostring(task.reference))
			end
		end)
		rowLayout:addItem(refButton)
	end
	return rowLayout
end

local function saveNewTask(taskData)
	trace("Saving new task: ".. (taskData.title or "Untitled"))
	local newTask = newTaskItem(taskData)
	trace("Saving the task")
	table.insert(taskState.todoTasksList, newTask)
	trace("Task saved")
	trace(tostring(newTask.label))
	trace("Calling Persist")
	persistingChanges()
	trace("Persist call done. moving on to adding on screen")
	local taskRowLayout = buildTaskCard(newTask)
	addTaskRow(taskRowLayout)
end

local function filterListView()
	local resultingList = {}
	for i, task in ipairs(taskState.todoTasksList) do
		trace(tostring(task.label))
		if taskState.showInProgress and task.status == taskStatuses.inprogress.state then
			table.insert(resultingList, task)
		end
		if taskState.showDone and task.status == taskStatuses.done.state then
			table.insert(resultingList, task)
		end
		if taskState.showToDo and task.status == taskStatuses.pending.state then
			table.insert(resultingList, task)
		end
		if taskState.showActive and task.status == taskStatuses.active.state then
			table.insert(resultingList, task)
		end
	end
	return resultingList
end

local function refreshTodoListView()
	if taskState.isRefreshing then
		-- trace("Already refreshing, skipping refreshTodoListView call")
		return
	end

	if taskState.todoListViewContainer then
		taskState.isRefreshing = true
		clearTodoListView()
		local taskListToDisplay = filterListView()
		for i, task in ipairs(taskListToDisplay) do
			trace(tostring(task.label))
			local taskCardLayout = buildTaskCard(task)
			addTaskRow(taskCardLayout)
		end
		taskState.needsRefresh = false
		taskState.isRefreshing = false
		taskState.isFirstRun = false
	else
		-- If the UI is not ready yet, mark that we need to refresh later
		taskState.needsRefresh = true
	end
end


local function createViewWindow()
	trace("createViewWindow: start")
	local windowLayout = api.gui.layout.BoxLayout.new("VERTICAL")
	local window = api.gui.comp.Window.new(_('Task Management v1'), windowLayout)
	window:setResizable(true)
	window:setPinButtonVisible(true)
	window:addHideOnCloseHandler()
	-- Build the top navbar
	local topNavbarLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
	local toDoButton = api.gui.comp.CheckBox.new("To-Do")
	toDoButton:setSelected(taskState.showToDo or false, false)
	toDoButton:onToggle(function ()
		taskState.showToDo = toDoButton:isSelected()
		flagForRefresh()
	end)
	local inProgressButton = api.gui.comp.CheckBox.new("In Progress")
	inProgressButton:setSelected(taskState.showInProgress or false, false)
	inProgressButton:onToggle(function ()
		taskState.showInProgress = inProgressButton:isSelected()
		flagForRefresh()
	end)
	local activeButton = api.gui.comp.CheckBox.new("Active-Continuous Tasks(Upcoming)")
	activeButton:setSelected(taskState.showActive or false, false)
	activeButton:onToggle(function ()
		taskState.showActive = activeButton:isSelected()
		flagForRefresh()
	end)
	local DoneButton = api.gui.comp.CheckBox.new("Done")
	DoneButton:setSelected(taskState.showDone, false)
	DoneButton:onToggle(function ()
		taskState.showDone = DoneButton:isSelected()
		flagForRefresh()
	end)
	topNavbarLayout:addItem(toDoButton)
	topNavbarLayout:addItem(inProgressButton)
	-- topNavbarLayout:addItem(activeButton)
	topNavbarLayout:addItem(DoneButton)
	windowLayout:addItem(topNavbarLayout)
	-- Use BoxLayout for the task list
	local taskListLayout = api.gui.layout.BoxLayout.new("VERTICAL")
	windowLayout:addItem(taskListLayout)
	-- Input fields for new task
	local bottomLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
	local titleInput = api.gui.comp.TextInputField.new("Title")
	titleInput:setMinimumSize(api.gui.util.Size.new(120, 32))
	local descInput = api.gui.comp.TextInputField.new("Description")
	descInput:setMinimumSize(api.gui.util.Size.new(180, 32))
	-- Color dropdown
	local colorDropdown = api.gui.comp.ComboBox.new()
	for i, opt in ipairs(taskState.colorOptions) do
		colorDropdown:addItem(opt.name)
	end
	colorDropdown:setSelected(1, false)
	-- Reference type dropdown
	local refTypeDropdown = api.gui.comp.ComboBox.new()
	for i, opt in ipairs(taskState.referenceTypeOptions) do
		refTypeDropdown:addItem(opt)
	end
	refTypeDropdown:setSelected(1, false)
	local refIdInput = api.gui.comp.TextInputField.new("Reference ID (entity)")
	refIdInput:setMinimumSize(api.gui.util.Size.new(80, 32))
	local saveButton = util.newButton("Add Task", "ui/button/small/metadata_add.tga")
	saveButton:onClick(function()
		trace("saveButton:onClick called")
		local colorIdx = colorDropdown:getCurrentIndex() or 1
		local color = taskState.colorOptions[colorIdx] and taskState.colorOptions[colorIdx].color or {0.5,0.5,0.5,1}
		local refTypeIdx = refTypeDropdown:getCurrentIndex() or 1
		local refType = (refTypeIdx == 1) and nil or taskState.referenceTypeOptions[refTypeIdx]
		local refId = tonumber(refIdInput:getText())
		local taskData = {
			title = titleInput:getText(),
			description = descInput:getText(),
			color = color,
			reference = refId,
			referenceType = refType
		}
		trace("saveButton:onClick taskData: " .. tostring(taskData.title) .. ", " .. tostring(taskData.description))
		saveNewTask(taskData)
		-- Optionally clear fields
		titleInput:setText("")
		descInput:setText("")
		refIdInput:setText("")
		colorDropdown:setSelected(1, false)
		refTypeDropdown:setSelected(1, false)
	end)
	bottomLayout:addItem(titleInput)
	bottomLayout:addItem(descInput)
	bottomLayout:addItem(colorDropdown)
	bottomLayout:addItem(refTypeDropdown)
	bottomLayout:addItem(refIdInput)
	bottomLayout:addItem(saveButton)
	windowLayout:addItem(bottomLayout)
	taskState.todoListViewContainer = taskListLayout
	taskState.windowContainer = windowLayout;
	if taskState.needsRefresh then
		refreshTodoListView()
		taskState.needsRefresh = false
	end
	trace("createViewWindow: end")
	return window
end

local gui = require "gui"
local function createTaskManagerComponents()
    trace("Creating the Components")
	print("[TAsk Manananager] Create Components Invoked ! ")
    local label = gui.textView_create("gameInfo.taskmanagementmod.label", _('Task Management'))
    local taskManagementButton = gui.button_create("gameInfo.taskmanagementmod.button", label)
    local window = createViewWindow()

taskManagementButton:onClick(function ()
		local mainView = game.gui.getContentRect("mainView")
		local y = math.floor(mainView[4]/2)
		local x = math.floor(mainView[3]/2)
		window:setPosition(x,y)
		window:setVisible(true,false)
    end)
    window:setVisible(false,false)
    trace("Task Management Components Built Successfully !!")
	game.gui.boxLayout_addItem("gameInfo.layout", gui.component_create("gameInfo.taskmanagementmod", "VerticalLine").id)
    trace("Adding the vertical line to the task manager Successfully !!")
    game.gui.boxLayout_addItem("gameInfo.layout", taskManagementButton.id)
end

local function loadSaved()
	taskState.loaded = true -- upfront to avoid repeated erroring if there is a problem
	trace("Loading saved")
	if savedTodo then
		trace("have SavedToodo")
		for i, task in pairs(savedTodo) do -- the clone will restore the metatable for vec3 objects 
			trace("Restoring task" .. tostring(task))
			local sanitizeTaskShape = sanitizeTaskShape(task)
			table.insert(taskState.todoTasksList, sanitizeTaskShape)
		end
		trace("Invoking Refresh Todo List")
		refreshTodoListView()
		-- addWork(guiState.refreshTable)
		-- guiState.persistChkbox:setSelected(true, false)
	end
end

function data()
    return {
		save = function ()
			-- Convert the task list into a savable format.
			return savedTodo
		end,
        guiInit = function ()
			print("========================> Task Maangewr Invoking create Componentes")
            xpcall(createTaskManagerComponents, err)
        end,
		load = function (savedState)
			loadCalled = true
			savedTodo = savedState
		end,
		guiUpdate = function()
			-- if not init then xpcall(createComponents,err) end

			-- if taskState.isActive then 
			-- 	xpcall(updateCircle,err) 
			-- end 

			if loadCalled and not taskState.loaded then
				xpcall(loadSaved,err)
			end

			if loadCalled and taskState.needsRefresh then
				trace("triggering a list view refresh by flag")
				xpcall(refreshTodoListView, err)
			end
        end,
		handleEvent = function (src, id, name, param)

			if src == "task_management_core.lua" then

				-- if id == "dummyUpgrade" then
				-- 	dummyUpgrade(param)
				-- end 
				if id == "persist" then
					trace("persist event received")
					trace(tostring(param))
					savedTodo = param
					trace("SavedTodo = Param ")
				end
			end
        end
    }
end