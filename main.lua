local Dispatcher = require("dispatcher")  -- luacheck:ignore
local UIManager = require("ui/uimanager")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local FFIUtil = require("ffi/util")
local T = FFIUtil.template
local InfoMessage = require("ui/widget/infomessage")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local SyncService = require("frontend/apps/cloudstorage/syncservice")
local Merge = require("merge")
local rapidjson = require("rapidjson")
local NetworkMgr = require("ui/network/manager")
local logger = require("logger")

local is_reloading_due_to_sync = false

local function export_highlights_to_markdown(annotations, book_title, output_path)
    local file = io.open(output_path, "w")
    if not file then return false end

    file:write("# " .. (book_title or "Highlights") .. "\n\n")

    -- Group by chapter
    local chapters = {}
    local chapter_order = {}
    for _, h in ipairs(annotations) do
        local ch = h.chapter or "Uncategorized"
        if not chapters[ch] then
            chapters[ch] = {}
            chapter_order[#chapter_order + 1] = ch
        end
        chapters[ch][#chapters[ch] + 1] = h
    end

    for _, ch in ipairs(chapter_order) do
        file:write("## " .. ch .. "\n\n")
        for _, h in ipairs(chapters[ch]) do
            if h.text and h.text ~= "" then
                file:write("> " .. h.text .. "\n\n")
            end
        end
    end

    file:close()
    return true
end



local function dir_exists(path)
    local ok, _, code = os.rename(path, path)
    if not ok then
        -- Código 13 = permission denied, bat folder has to exist
        return code == 13
    end
    return true
end

local function ensure_dir_exists(path)
    if not dir_exists(path) then
        local safe_path = path:gsub("%$", "\\$")
        local result = os.execute('mkdir -p "' .. safe_path .. '"')
        if not result then
            error("Failed to create directory: " .. path)
        end
    end
end

local Highlightsync = WidgetContainer:extend{
    name = "Highlightsync",
    is_doc_only = false,
}

--- Needed so the "ext" table existing in pdf annotations to be encoded
--- in JSON, as non-contiguous integer keys aren't allowed in JSON.
--- @return table new_annotations The original table, but with the `ext` sub-table's
--- number keys replaced with strings.
local function with_stringified_ext_keys(annotations)
    local new_annotations = {}
    for hash, annotation in pairs(annotations) do
        local new_annotation
        if annotation["ext"] then
            new_annotation = {}
            for k, v in pairs(annotation) do
                new_annotation[k] = v
            end
            local new_ext = {}
            for k, v in pairs(annotation["ext"]) do
                new_ext[tostring(k)] = v
            end
            new_annotation["ext"] = new_ext
        else
            new_annotation = annotation
        end
        new_annotations[hash] = new_annotation
    end
    return new_annotations
end

--- Modifies the given table so the keys in the `ext` sub-table are paresd into numbers.
local function destringify_ext_keys(annotations)
    for hash, annotation in pairs(annotations) do
        if annotation["ext"] then
            local new_ext = {}
            for k, v in pairs(annotation["ext"]) do
                new_ext[tonumber(k)] = v
            end
            annotation["ext"] = new_ext
        end
    end
end

local function read_json_file(path)
    local file = io.open(path, "r")
    if not file then
        -- file doesn't exist
        return {}
    end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        return {}
    end

    local ok, data = pcall(rapidjson.decode, content)
    if not ok or type(data) ~= "table" then
        return {}
    end

    destringify_ext_keys(data)

    return data
end

local function write_json_file(path, data)
    local file = io.open(path, "w")
    if not file then return false end

    file:write(rapidjson.encode(with_stringified_ext_keys(data)))
    file:close()
    return true
end


function Highlightsync:onDispatcherRegisterActions()

        --- for gestures
        Dispatcher:registerAction("hightlightsync_action", {
            category = "none",
            event = "SyncBookHighlights",
            title = _("Sync Highlights Now"),
            help = _("Synchronize highlights with the cloud."),
            reader = true
        })

end

Highlightsync.default_settings = {
       is_enabled = true,
}



function Highlightsync:init()
    if self.document and self.document.is_pic then
        return -- disable in PIC documents
    end

    self.is_syncing = false

    Highlightsync.settings = G_reader_settings:readSetting("highlight_sync", self.default_settings)
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function Highlightsync:onReaderReady()

    if is_reloading_due_to_sync then
        is_reloading_due_to_sync = false
        return 
    end

    if self.settings.sync_on_open and self:canSync() then
        UIManager:nextTick(function()
            self:SyncBookHighlights(false, true)
        end)
    end
end

function Highlightsync:onCloseDocument()

    if is_reloading_due_to_sync then
        return
    end


    if self.settings.sync_on_close and self:canSync() then
        -- Sincroniza e sai (sem reload, pois estamos saindo)
        self:SyncBookHighlights(false, false) 
    end
end

function Highlightsync:onResume()
    
    if self.settings.sync_on_resume then
        UIManager:nextTick(function()
            if NetworkMgr:isWifiOn() then
                self:SyncBookHighlights(false, true)
                self.settings.pending_sync = false
                G_reader_settings:saveSetting("highlight_sync", self.settings)
            end
        end)
    end

end



function Highlightsync:onSync(local_path, cached_path, income_path, reload)
    local local_highlights  = self.ui.annotation.annotations
    local cached_highlights = read_json_file(cached_path) or {}
    local income_highlights = read_json_file(income_path) or {}

    local annotations = Merge.Merge_highlights(local_highlights, income_highlights, cached_highlights)

    write_json_file(self.sync_sidecar_dir .. "/" .. self.sync_filename .. ".json", annotations)

    self.settings.last_sync = os.date("%Y-%m-%d %H:%M")
    G_reader_settings:saveSetting("highlight_sync", self.settings) -- luacheck: ignore

    if self.ui and self.ui.annotation then
        self.ui.annotation.annotations = annotations
        if reload then
            is_reloading_due_to_sync = true
            UIManager:tickAfterNext(function()
                self.ui:reloadDocument()
            end)
        end
    end

    return true
end

function Highlightsync:is_doc()
    if self.document then
        return true
    else
        return false
    end
end

function Highlightsync:canSync()
    return self.is_doc(self) and self.settings.sync_server ~= nil
end

local function sanitize_filename(str)
    if not str then return "" end
    return str:gsub("[^%w%.%-%_]", "_")
end

function Highlightsync:onSyncBookHighlights()
        self:SyncBookHighlights(false, true)   
end

function Highlightsync:SyncBookHighlights(silent, reload)
    if not self:canSync() then return end

    if self.is_syncing then
        logger.warn("Highlightsync: Duplicate sync attempt ignored.")
        return
    end

    -- enable lock
    self.is_syncing = true

    local doc_path = self.document and self.document.file
    local doc_settings = self.ui and self.ui.doc_settings
    self.sync_sidecar_dir = doc_settings:getSidecarDir(doc_path)
    ensure_dir_exists(self.sync_sidecar_dir)

    local raw_name = self.sync_sidecar_dir:match("([^/]+)/*$")
    self.sync_filename = sanitize_filename(raw_name)

    write_json_file(self.sync_sidecar_dir .. "/" .. self.sync_filename .. ".json", self.ui.annotation.annotations)

    SyncService.sync(self.settings.sync_server, self.sync_sidecar_dir .. "/" .. self.sync_filename .. ".json",
    function(local_path, cached_path, income_path)
        local success = self:onSync(local_path, cached_path, income_path, reload)
        self.is_syncing = false
        return success
    end,
    silent
    )

         
         
    
end


function Highlightsync:addToMainMenu(menu_items)

    menu_items.highlight_sync = {
        text = _("Highlight Sync"),
        sub_item_table = {
            {
                text = _("Sync Cloud"),
                callback = function(touchmenu_instance)
                    local server = self.settings.sync_server
                    local edit_cb = function()
                        local sync_settings = SyncService:new{}
                        sync_settings.onClose = function(this)
                            UIManager:close(this)
                        end
                        sync_settings.onConfirm = function(sv)
                            self.settings.sync_server = sv
                            touchmenu_instance:updateItems()
                        end
                        UIManager:show(sync_settings)
                    end
                    if not server then
                        edit_cb()
                        return
                    end
                    local dialogue
                    local delete_button = {
                        text = _("Delete"),
                        callback = function()
                            UIManager:close(dialogue)
                            UIManager:show(ConfirmBox:new{
                                text = _("Delete server info?"),
                                cancel_text = _("Cancel"),
                                cancel_callback = function()
                                end,
                                ok_text = _("Delete"),
                                ok_callback = function()
                                    self.settings.sync_server = nil
                                    touchmenu_instance:updateItems()
                                end,
                            })
                        end,
                    }
                    local edit_button = {
                        text = _("Edit"),
                        callback = function()
                            UIManager:close(dialogue)
                            edit_cb()
                        end
                    }
                    local close_button = {
                        text = _("Close"),
                        callback = function()
                            UIManager:close(dialogue)
                        end
                    }
                    local type = server.type == "dropbox" and " (DropBox)" or " (WebDAV)"
                    dialogue = ButtonDialog:new{
                        title = T(_("Cloud storage:\n%1\n\nFolder path:\n%2\n\nSet up the same cloud folder on each device to sync across your devices."),
                                     server.name.." "..type, SyncService.getReadablePath(server)),
                        buttons = {
                            {delete_button, edit_button, close_button}
                        },
                    }
                    UIManager:show(dialogue)
                end,
                enabled_func = function() return self.settings.is_enabled end,
                keep_menu_open = true,
            },
            {
                text = _("Sync Highlights"),
                callback = function()
                    self:SyncBookHighlights(false, true)
                end,
                enabled_func = function() return self.canSync(self) end
            },
            {
                text_func = function()
                    local last = self.settings.last_sync
                    return last and T(_("Last synced: %1"), last) or _("Last synced: never")
                end,
                enabled_func = function() return false end,
            },
            {
                text = _("Export Highlights to Markdown"),
                callback = function()
                    if not self:is_doc() then return end
                    local annotations = self.ui.annotation.annotations
                    if not annotations or #annotations == 0 then
                        UIManager:show(InfoMessage:new{ text = _("No highlights to export.") })
                        return
                    end
                    local doc_path = self.document.file
                    local doc_settings = self.ui.doc_settings
                    local sidecar_dir = doc_settings:getSidecarDir(doc_path)
                    ensure_dir_exists(sidecar_dir)
                    local raw_name = sidecar_dir:match("([^/]+)/*$") or "highlights"
                    local output_path = sidecar_dir .. "/" .. raw_name .. ".md"
                    local title = self.document:getProps().title or raw_name
                    if export_highlights_to_markdown(annotations, title, output_path) then
                        UIManager:show(InfoMessage:new{ text = T(_("Exported to:\n%1"), output_path) })
                    else
                        UIManager:show(InfoMessage:new{ text = _("Export failed.") })
                    end
                end,
                enabled_func = function() return self:is_doc() end,
            },
            {
                text = _("Settings"),
                sub_item_table = {  
                    {
                        text = _("Sync on Book Open"),
                        checked_func = function() return self.settings.sync_on_open end,
                        callback = function()
                            self.settings.sync_on_open = not self.settings.sync_on_open
                            G_reader_settings:saveSetting("highlight_sync", self.settings)
                        end,
                    },
                    {
                        text = _("Sync on Book Close"),
                        checked_func = function() return self.settings.sync_on_close end,
                        callback = function()
                            self.settings.sync_on_close = not self.settings.sync_on_close
                            G_reader_settings:saveSetting("highlight_sync", self.settings)
                        end,
                    },
                    {
                        text = _("Sync on Book on resume"),
                        checked_func = function() return self.settings.sync_on_resume end,
                        callback = function()
                            self.settings.sync_on_resume = not self.settings.sync_on_resume
                            G_reader_settings:saveSetting("highlight_sync", self.settings)
                        end,
                    },
                }
            }
        }
    }
end

require("insert_menu")

return Highlightsync
