function data()
    return {
        info = {
            name = _("Task Management 0.5"),
            description = _("A simple Task Management mod"),
            authors = {
                {
                    name = "Matias Santos",
                    role = "CREATOR"
                }
            },
            version = "0.5",
            minorVersion = 0,
            severityAdd = "NONE",
            severityRemove = "NONE",
            tags = {"UI", "Finance", "Management"}
        },
        runFn = function (settings, modParams) 
			--  print("Task Management runFn got called")
        end,
        postRunFn = function(settings, params)
            -- print("Task Management post run got called")
			--print("postRunFn the game config was",game.config, " discoveredProduction was ",discoveredProduction)
		end
    }
end