--[=[
	--todo:
    - on create new script make the scroll in the left side auto scroll to the recent created script

--]=]



local addonName, scriptLibrary = ...

--load Details! Framework
local DF = _G ["DetailsFramework"]
if (not DF) then
    print ("|cFFFFAA00RuntimeEditor: framework not found, if you just installed or updated the addon, please restart your client.|r")
    return
end

--> make some default tables
    scriptLibrary.RegisteredWindows = {}
    scriptLibrary.previousStackWindowIDs = {}

--> namespace
    scriptLibrary.ImportExport = {}

    DetailsFramework:Embed(scriptLibrary)

local default_config = {
    --which button was the select selected
    last_type = 1,
    --which object was edited last logon or before a /reload
    last_object_selected = 0,

    --frame table for LibWindow
    main_frame = {},
    frame_scale = {scale = 1},

    --options of the addon
    options = {
        --auto open the window after a /reload
        auto_open = false,
        --set the frame strata to tooltip instead of the default
        always_on_top = false,
        --default frame strata
        frame_strata = "LOW",
        --frame scale
        scale = 1,
        --text size
        text_size = 11,
    },

    --store saved code objects
    saved_objects = {},

    --last opened script
    last_opened_script = false,

    --should reopen after a reload?
    auto_open = false,
}

local options_table = {
    name = "RuntimeEditor",
    type = "group",
    args = {

    }
}

local font = DF:GetBestFontForLanguage()

--> create templates
    DF:InstallTemplate ("button", "RUNTIMEEDITOR_BUTTON_TEMPLATE",
        {
            textsize = 10,
            textfont = font,
            textcolor = {1, .9, 0},
            onentercolor = {.8, .8, .8, .9}
        },
        "OPTIONS_BUTTON_TEMPLATE"
    )

    DF:InstallTemplate ("font", "RUNTIMEEDITOR_BUTTONTEXT_TEMPLATE", {
        color = "fadedorange",
        size = 10, 
        font = font
    })

    DF:InstallTemplate ("font", "CODE_SCRIPTS_NAME", {color = "orange", size = 10, font = font})
    DF:InstallTemplate ("font", "CODE_SCRIPTS_RUNON", {color = {.5, .5, .5, 0.5}, size = 9, font = font})
    DF:InstallTemplate ("font", "CODE_BUTTON", {color = {1, .8, .2}, size = 10, font = font})
    DF:InstallTemplate ("font", "CODE_BUTTON_DISABLED", {color = {1/3, .8/3, .2/3}, size = 10, font = font})

--> frame settings
    local settingsButtons = {
        width = 120,
        height = 20,
    }

    local settingsScrollBox = {
        width = 200,
        height = 570,
        lines = 18,
        lineHeight = 30.4,
        lineBackdropColor = {0, 0, 0, 0.5},
        lineBackdropColorSelected = {.6, .6, .1, 0.7},
    }

    local settingsCodeEditor = {
        width = 930,
        height = 615,
        pointX = settingsScrollBox.width + 40,
        pointY = -180,
    }

    local settingsOptionsFrame = {
        width = 1200,
        height = 858,
        scriptInfoX = 10,
        scriptInfoY = -50,
    }

    scriptLibrary.FrameSettings = {
        settingsCodeEditor = settingsCodeEditor,
        settingsButtons = settingsButtons,
        settingsScrollBox = settingsScrollBox,
        settingsOptionsFrame = settingsOptionsFrame,
    }

    scriptLibrary.FrameStack = {
        mainFrame = 0,
        scriptInfoFrame = 1,
        scriptMenuFrame = 2,

        codeEditorFrame = 3,
        importExportFrame = 3,
    }

--> create addon object
    --local addonObject = DF:CreateAddOn("ScriptLibraryAddon", "RuntimeEditorDB", default_config, options_table)

--> handle load and save data
    scriptLibrary.saved_variables = {}

    local handleSavedVariablesFrame = CreateFrame("frame")
    handleSavedVariablesFrame:RegisterEvent("ADDON_LOADED")
    handleSavedVariablesFrame:RegisterEvent("PLAYER_LOGIN")
    handleSavedVariablesFrame:RegisterEvent("PLAYER_LOGOUT")

    handleSavedVariablesFrame:SetScript("OnEvent", function(self, event, ...)
        if (event == "ADDON_LOADED") then
            local thisAddonName = ...
            if (thisAddonName == addonName) then

                ScriptLibraryDB = ScriptLibraryDB or {}
                DF.table.deploy(ScriptLibraryDB, default_config)

                --old saved variables
                if (RuntimeEditorDB and RuntimeEditorDB.profiles and RuntimeEditorDB.profiles.Default) then
                    DF.table.copy(ScriptLibraryDB, RuntimeEditorDB.profiles.Default)
                    wipe(RuntimeEditorDB)
                    RuntimeEditorDB = nil
                end

                DF.table.copy(scriptLibrary.saved_variables, ScriptLibraryDB)
                wipe(ScriptLibraryDB)
            end

        elseif (event == "PLAYER_LOGIN") then
            scriptLibrary.OnInit()

        elseif (event == "PLAYER_LOGOUT") then
            ScriptLibraryDB = scriptLibrary.saved_variables
        end
    end)

    --return a index table containing scripts saved
    --format: {{scriptObject}, {scriptObject}}
    function scriptLibrary.GetData()
        return scriptLibrary.saved_variables.saved_objects
    end

    --return a table with the addon settings
    function scriptLibrary.GetConfig()
        return scriptLibrary.saved_variables
    end