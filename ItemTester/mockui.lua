#@
-- This wrapper allows the program to run headless on any OS (in theory)
-- It can be run using a standard lua interpreter, although LuaJIT is preferable

t_insert = table.insert
m_min = math.min
m_max = math.max
m_floor = math.floor
m_abs = math.abs
s_format = string.format

-- Callbacks
callbackTable = { }
mainObject = nil
function runCallback(name, ...)
    if callbackTable[name] then
        return callbackTable[name](...)
    elseif mainObject and mainObject[name] then
        return mainObject[name](mainObject, ...)
    end
end
function SetCallback(name, func)
    callbackTable[name] = func
end
function GetCallback(name)
    return callbackTable[name]
end
function SetMainObject(obj)
    mainObject = obj
end

-- Image Handles
imageHandleClass = { }
imageHandleClass.__index = imageHandleClass
function NewImageHandle()
    return setmetatable({ }, imageHandleClass)
end
function imageHandleClass:Load(fileName, ...)
    self.valid = true
end
function imageHandleClass:Unload()
    self.valid = false
end
function imageHandleClass:IsValid()
    return self.valid
end
function imageHandleClass:SetLoadingPriority(pri) end
function imageHandleClass:ImageSize()
    return 1, 1
end

-- Rendering
function RenderInit() end
function GetScreenSize()
    return 1920, 1080
end
function SetClearColor(r, g, b, a) end
function SetDrawLayer(layer, subLayer) end
function SetViewport(x, y, width, height) end
function SetDrawColor(r, g, b, a) end
function DrawImage(imgHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom) end
function DrawImageQuad(imageHandle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4) end
function DrawString(left, top, align, height, font, text) end
function DrawStringWidth(height, font, text)
    return 1
end
function DrawStringCursorIndex(height, font, text, cursorX, cursorY)
    return 0
end
function StripEscapes(text)
    return text:gsub("^%d",""):gsub("^x%x%x%x%x%x%x","")
end
function GetAsyncCount()
    return 0
end

-- Search Handles
function NewFileSearch() end

-- General Functions
function SetWindowTitle(title) end
function GetCursorPos()
    return 0, 0
end
function SetCursorPos(x, y) end
function ShowCursor(doShow) end
function IsKeyDown(keyName) end
function Copy(text) end
function Paste() end
function Deflate(data)
    -- TODO: Might need this
    return ""
end
function Inflate(data)
    -- TODO: And this
    return ""
end
function GetTime()
    return 0
end
function GetScriptPath()
    return ""
end
function GetRuntimePath()
    return ""
end
function GetUserPath()
    return ""
end
function MakeDir(path) end
function RemoveDir(path) end
function SetWorkDir(path) end
function GetWorkDir()
    return ""
end
function LaunchSubScript(scriptText, funcList, subList, ...) end
function AbortSubScript(ssID) end
function IsSubScriptRunning(ssID) end
function LoadModule(fileName, ...)
    if not fileName:match("%.lua") then
        fileName = fileName .. ".lua"
    end
    local func, err = loadfile(fileName)
    if func then
        return func(...)
    else
        error("LoadModule() error loading '"..fileName.."': "..err)
    end
end
function PLoadModule(fileName, ...)
    if not fileName:match("%.lua") then
        fileName = fileName .. ".lua"
    end
    local func, err = loadfile(fileName)
    if func then
        return PCall(func, ...)
    else
        error("PLoadModule() error loading '"..fileName.."': "..err)
    end
end
function PCall(func, ...)
    local ret = { pcall(func, ...) }
    if ret[1] then
        table.remove(ret, 1)
        return nil, unpack(ret)
    else
        return ret[2]
    end
end
function ConPrintf(fmt, ...)
    -- Optional
    -- print(string.format(fmt, ...))
end
function ConPrintTable(tbl, noRecurse) end
function ConExecute(cmd) end
function ConClear() end
function SpawnProcess(cmdName, args) end
function OpenURL(url) end
function SetProfiling(isEnabled) end
function Restart() end
function Exit() end

l_require = require
function require(name)
    -- Hack to stop it looking for lcurl, which we don't really need
    if name == "lcurl.safe" then
        return
    end
    return l_require(name)
end


dofile("Launch.lua")

runCallback("OnInit")
runCallback("OnFrame") -- Need at least one frame for everything to initialise

if mainObject.promptMsg then
    -- Something went wrong during startup
    print(mainObject.promptMsg)
    io.read("*l")
    return
end

-- The build module; once a build is loaded, you can find all the good stuff in here
build = mainObject.main.modes["BUILD"]

-- Here's some helpful helper functions to help you get started
function newBuild()
    mainObject.main:SetMode("BUILD", false, "Help, I'm stuck in Path of Building!")
    runCallback("OnFrame")
end
function loadBuildFromXML(xmlText)
    mainObject.main:SetMode("BUILD", false, "", xmlText)
    runCallback("OnFrame")
end
function loadBuildFromJSON(getItemsJSON, getPassiveSkillsJSON)
    mainObject.main:SetMode("BUILD", false, "")
    runCallback("OnFrame")
    local charData = build.importTab:ImportItemsAndSkills(getItemsJSON)
    build.importTab:ImportPassiveTreeAndJewels(getPassiveSkillsJSON, charData)
    -- You now have a build without a correct main skill selected, or any configuration options set
    -- Good luck!
end

function loadText(fileName)
    local fileHnd, errMsg = io.open(fileName, "r")
    if not fileHnd then
        print("Failed to load file: "..fileName)
        os.exit(1)
        -- return nil, errMsg
    end
    local fileText = fileHnd:read("*a")
    fileHnd:close()
    return fileText
end

function loadTextLines(fileName)
    local fileHnd, errMsg = io.open(fileName, "r")
    if not fileHnd then
        print("Failed to load file: "..fileName)
        os.exit(1)
        -- return nil, errMsg
    end
    local output = {}
    for line in fileHnd:lines() do
        output[#output + 1] = line
    end
    fileHnd:close()
    return output
end


FakeTooltip = {
	lines = {}
}

function FakeTooltip:new()
	o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function FakeTooltip:AddLine(_, txt)
	local html = lineToHtml(txt)
	table.insert(self.lines, "<p>"..html.."</p>")
end

function FakeTooltip:AddSeparator(_, txt)
	-- Make sure we don't get two in a row
	if self.lines[#self.lines] ~= "<hr/>" then
		table.insert(self.lines, "<hr/>")
	end
end

function lineToHtml(txt)
	return txt:gsub("^%^7", ""):gsub("%^x(......)", "<span style=\"color:#%1\">"):gsub("%^7", "</span>"):gsub("%^8", "<span style=\"color:gray\">")
end
