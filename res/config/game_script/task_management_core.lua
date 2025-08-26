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
    debugLog = false,
	taskList = {},
	windowContainer = nil,
	todoListViewContainer = nil,
	todoTasksList = {},
	needsRefresh = false,
	isRefreshing = false,
	isFirstRun = true,
	commitChanges = true,
	showDone = false,
	showInProgress = true,
	showToDo = false,
	showActive = true
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
			label = "Label",
			status = taskStatuses.pending.state
	}

	if task and task.label then
		basicTaskShape.label = tostring(task.label)
	end

	if task and task.status then
		basicTaskShape.status = taskStatusFromString(task.status)
	end


	return basicTaskShape
end


local function newTaskItem(taskLabel)
	-- Sanitize the shape to be created
	return {
		label = tostring(taskLabel),
		status = taskStatuses.pending.state
	}
end



local function persistingChanges()
	if taskState.commitChanges then
		trace("Commiting changes! ")
		api.cmd.sendCommand(api.cmd.make.sendScriptEvent("task_management_core.lua","persist", "", taskState.todoTasksList), util.handleCallback)
		trace("Command persist sent")
	end
end

local function addTaskRow(taskRow)
	if taskState.todoListViewContainer then
		taskState.todoListViewContainer:addItem(taskRow)
	end
end

local function getCountTasksOnDisplay()
	if taskState.todoListViewContainer then
		return taskState.todoListViewContainer:getNumItems()
	else
		return 0
	end
end

local function clearTodoListView()
	if taskState.todoListViewContainer then
		trace("Clearing all items from todoListViewContainer")
		local numItems = taskState.todoListViewContainer:getNumItems()
		for i = numItems, 1, -1 do
			local item = taskState.todoListViewContainer:getItem(i - 1)
			if item then
				taskState.todoListViewContainer:removeItem(item)
			end
		end
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
	local taskLabel = api.gui.comp.TextView.new(tostring(task.label))
	local actionButton = buildTaskActionButton(task)
	rowLayout:addItem(actionButton)
	rowLayout:addItem(orderLabel)
	rowLayout:addItem(taskLabel)
	return rowLayout
end

local function saveNewTask(taskText)
	trace("Saving new task: ".. taskText)
	local newTask = newTaskItem(taskText)
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
		trace("Already refreshing, skipping refreshTodoListView call")
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
    local windowLayout = api.gui.layout.BoxLayout.new("VERTICAL")
    local window = api.gui.comp.Window.new(_('Task Management v1'), windowLayout)
    window:setResizable(true)
	window:setPinButtonVisible(true)
    window:addHideOnCloseHandler()
	-- Build the top navbar
	local topNavbarLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
	-- local toDoButton = util.newButton("To-Do", "ui/button/small/pause.tga")
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
	-- local inProgressButton = util.newButton("In Progress", "ui/button/small/vehicle_replace_active.tga")
	local DoneButton = api.gui.comp.CheckBox.new("Done")
	DoneButton:setSelected(taskState.showDone, false)
	DoneButton:onToggle(function ()
		taskState.showDone = DoneButton:isSelected()
		flagForRefresh()
	end)

	-- local DoneButton = util.newButton("Done", "ui/button/small/accept.tga")
	topNavbarLayout:addItem(toDoButton)
	topNavbarLayout:addItem(inProgressButton)
	-- Upcoming state to handle
	-- topNavbarLayout:addItem(activeButton)
	topNavbarLayout:addItem(DoneButton)

	windowLayout:addItem(topNavbarLayout)

	local taskListLayout = api.gui.layout.BoxLayout.new("VERTICAL")
	-- Try to build a better looking list of tasks. Component List for example
	windowLayout:addItem(taskListLayout)
	-- add input and confirm
	local bottomLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
	local taskInputField = api.gui.comp.TextInputField.new("Task")
	-- taskInputField:setFocus()
	local minInputFieldSize = api.gui.util.Size.new(300, 32)
	taskInputField:setMinimumSize(minInputFieldSize)
	local saveButton = util.newButton("To-Do", "ui/button/small/metadata_add.tga")
	saveButton:onClick(function ()
		local taskText = taskInputField:getText()
		saveNewTask(taskText)
	end)
	bottomLayout:addItem(taskInputField)
	bottomLayout:addItem(saveButton)
	windowLayout:addItem(bottomLayout)

	taskState.todoListViewContainer = taskListLayout
	taskState.windowContainer = windowLayout;

	-- If tasks need to be refreshed after loading, do it now
	if taskState.needsRefresh then
		refreshTodoListView()
		taskState.needsRefresh = false
	end

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