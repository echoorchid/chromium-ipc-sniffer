mojo_protocol = Proto("MojoUser",  "Mojo C++ Binded Message")

local common = require("helpers\\common")
local mojo_interfaces_map = require("helpers\\mojo_interfaces_map")

local mojo_interface_json, err = io.open(common.script_path() .. "helpers\\mojo_interfaces.json", "rb"):read("*all")
local mojo_interfaces_info = common.json_to_table(mojo_interface_json)

-- Mojo Message fields
-- https://docs.google.com/document/d/13pv9cFh5YKuBggDBQ1-AL8VReF-IYpFOFpRfvWFrwio/edit

-- https://source.chromium.org/chromium/chromium/src/+/master:mojo/public/cpp/bindings/lib/bindings_internal.h;l=96
local num_bytes                     = ProtoField.uint32 ("mojouser.numbytes"  , "Binded Message Length"     , base.DEC)
local version                       = ProtoField.uint32 ("mojouser.version"  , "Binded Message Protocol Version"     , base.DEC)

-- https://source.chromium.org/chromium/chromium/src/+/master:mojo/public/cpp/bindings/lib/message_internal.h;l=28
local interface_id                  = ProtoField.uint32 ("mojouser.interfaceid"  , "Interface ID"     , base.HEX)
local name                          = ProtoField.uint32 ("mojouser.name"  , "Message Name (Method)"     , base.HEX)
local flags                         = ProtoField.uint32 ("mojouser.flags"  , "Flags"     , base.HEX)
local trace_id                      = ProtoField.uint32 ("mojouser.traceid"  , "Trace ID"     , base.HEX)
local request_id                    = ProtoField.uint64 ("mojouser.requestid"  , "Request ID"     , base.HEX)
local payload_pointer               = ProtoField.uint64 ("mojouser.payloadpointer"  , "Payload Pointer"     , base.DEC)
local payload_interface_ids_pointer = ProtoField.uint64 ("mojouser.payloadinterfaceids"  , "Payload Interface IDs Pointer"     , base.DEC)
local serialized_data_struct_header = ProtoField.new("Struct Header", "mojouser.structheader", ftypes.BYTES)
local method_parameters             = ProtoField.new("Nested Struct/Array Parameter", "mojouser.parameters", ftypes.BYTES)
local arguments_values              = ProtoField.new("Arguments Values", "mojouser.argumentsvalues", ftypes.BYTES)

-- Flags
local flag_expects_response         = ProtoField.bool("mojouser.expectsresponse", "Expects response", 32, {"This message expects a response", "This message does not expect a response"}, 0x1)
local flag_is_reponse               = ProtoField.bool("mojouser.isresponse", "Is response", 32, {"This is a response", "This is a request"}, 0x2)
local flag_is_sync                  = ProtoField.bool("mojouser.issync", "Is sync", 32, {"This is a blocking call", "This is an async call"}, 0x4)

-- https://source.chromium.org/chromium/chromium/src/+/master:mojo/public/cpp/bindings/interface_id.h;l=20
local flag_namespace_bit = ProtoField.bool("mojouser.namespace", "Namespace bit", 32, {"This ID was generated by the client-side of the master interface", "This ID was generated by the server-side of the master interface"}, 0x80000000)

-- Structs / Arrays packing
local struct_num_bytes              = ProtoField.uint32 ("mojouser.struct_numbytes"  , "Struct Length"     , base.DEC)
local struct_version                = ProtoField.uint32 ("mojouser.struct_version"  , "Struct Version"     , base.DEC)
local struct_fields                 = ProtoField.new("Fields", "mojouser.struct_fields", ftypes.BYTES)
-- https://source.chromium.org/chromium/chromium/src/+/master:mojo/public/cpp/bindings/lib/bindings_internal.h;l=103;
local array_num_bytes               = ProtoField.uint32 ("mojouser.array_numbytes"  , "Array Length"     , base.DEC)
local array_elements_count          = ProtoField.uint32 ("mojouser.array_elements_count"  , "Elements Count"     , base.DEC)

-- From other layers
local source_pid_type               = ProtoField.int32 ("npfs.sourcetype"       , "Source Process Type"         , base.DEC)
local dest_pid_type                 = ProtoField.int32 ("npfs.desttype"       , "Destination Process Type"         , base.DEC)

-- Extra Fields
local definition_field              = ProtoField.new("Definition", "mojouser.definition", ftypes.STRING)
local link_field                    = ProtoField.new("Definition Link", "mojouser.definitionlink", ftypes.STRING)
local method                        = ProtoField.new("Mathod Name", "mojouser.method", ftypes.STRING)

--
-- Expert Info
--
local expert_info_legacyipc = ProtoExpert.new("mojouser.legacyipc", "Legacy IPC", expert.group.COMMENTS_GROUP, expert.severity.NOTE)
local expert_info_unresolved_interface = ProtoExpert.new("mojouser.unresolved_interface", "This method ID could not be resolved", expert.group.COMMENTS_GROUP, expert.severity.WARN)


-- Prefrences
mojo_protocol.prefs.enable_deep_inspection = Pref.bool( "Enable structs deep dissection", false, "Enable dissection of nested struct/array fields (slow!)" )

mojo_protocol.fields = {
    source_pid_type, dest_pid_type,
    num_bytes, version,
    interface_id, name, flags, trace_id, request_id, payload_pointer, payload_interface_ids_pointer, 
    serialized_data_struct_header, method_parameters, arguments_values, struct_num_bytes, struct_version, struct_fields, array_num_bytes, array_elements_count,
    flag_expects_response, flag_is_reponse, flag_is_sync, flag_namespace_bit,
    definition_field, link_field, legacy_ipc_field, method,                                                     -- Meta fields
}

mojo_protocol.experts = {expert_info_legacyipc, expert_info_unresolved_interface}

-- Binded Message fields
local _numbytes = Field.new("mojouser.numbytes")
local _version = Field.new("mojouser.version")
local _interfaceid = Field.new("mojouser.interfaceid")
local _method_name = Field.new("mojouser.name")
local _struct_num_bytes = Field.new("mojouser.struct_numbytes")
local _struct_version = Field.new("mojouser.struct_version")

-- Flags fields
local _expects_response = Field.new("mojouser.expectsresponse")
local _is_response = Field.new("mojouser.isresponse")
local _is_sync = Field.new("mojouser.issync")

-- Fields from other layers
local _sourcetype = Field.new("npfs.sourcetype")
local _desttype = Field.new("npfs.desttype")

function mojo_protocol.dissector(buffer, pinfo, tree)
    length = buffer:len()
    if length == 0 then return end

    pinfo.cols.protocol = mojo_protocol.name

    local subtree =       tree:add(mojo_protocol, buffer(), "Mojo C++ Binded Message")

    -- Header
    local offset = 0
    subtree:add_le(num_bytes,                           buffer(offset,4));                                         offset = offset + 4
    subtree:add_le(version,                             buffer(offset,4));                                         offset = offset + 4
    interfaceIdTree = subtree:add(interface_id,         buffer(offset,4));                                                 
    interfaceIdTree:add_le(flag_namespace_bit,          buffer(offset, 4))                                         offset = offset + 4
    name_subtree = subtree:add_le(name,                 buffer(offset,4));                                         offset = offset + 4

    if _interfaceid()() == 0x00000000 then
        interfaceIdTree:append_text(" (Master Interface)")
    end

    -- Flags
    local flagsSubtree = subtree:add(flags,             buffer(offset, 4))
    flagsSubtree:add_le(flag_expects_response,          buffer(offset, 4))       
    flagsSubtree:add_le(flag_is_reponse,                buffer(offset, 4))
    flagsSubtree:add_le(flag_is_sync,                   buffer(offset, 4))                                                    
    flagsSubtree:set_len(4)                                                                                        offset  = offset + 4
    subtree:add_le(trace_id,                            buffer(offset,4));                                         offset = offset + 4
    if _version()() >= 1 then
        subtree:add_le(request_id,                      buffer(offset,8));                                         offset = offset + 8
    end
    if _version()() >= 2 then
        subtree:add_le(payload_pointer,                 buffer(offset,8));                                         offset = offset + 8
        subtree:add_le(payload_interface_ids_pointer,   buffer(offset,8));                                         offset = offset + 8
    end

    dataSubtree = subtree:add(buffer(offset), "Serialized Arguments (Payload)")

    -- Try to associate the name field with an actual interface name
    local method_name_key = "n" ..  string.format("%x", _method_name()())
    local method_name = mojo_interfaces_map[method_name_key]
    local short_method_name = method_name
    local interface_resolved = false
    local definition = ""

    if method_name ~= nil then
        -- Method name resolved

        interface_info = mojo_interfaces_info[method_name]

        if interface_info ~= nil then
            definition = interface_info["definition"]
            link = interface_info["link"]
            interface_resolved = true

            dataSubtree:add(definition_field, definition):set_text("[" .. definition .. "]")
            dataSubtree:add(link_field, link):set_text("[" .. link .. "]")

            if _is_response()() then
                arrow_location = definition:find("=>") -- note that the method definition may not contain '=>' in case we got the method hash wrong
                definition = definition:sub((arrow_location))
            end

            dataSubtree:add(method, method_name):set_hidden()
        end
    else
        -- Can't resolve method name

        method_name = string.format("0x%x", _method_name()())
        short_method_name = method_name
    end

    -- try to shorten the method name for display
    local module_path = ""
    if method_name:find('%.') then
        
        local separator_index = method_name:sub(1, method_name:match('.*()%.') - 1):match(".*()%.")
        if separator_index ~= nil then
            short_method_name = method_name:sub(separator_index + 1)
            module_path = method_name:sub(1, separator_index - 1)
        end

        -- is it a special message without a containing interface?
        if method_name:find("interface_control") then
            module_path = "mojo.interface_control"
        end
    end

    --
    -- Deserialize Mojo's archive format as much as feasible
    -- https://docs.google.com/document/d/1jNcsxOdO3Al52s6lIrMOOgY7KXB7TJ8wGGWstAHiTd8
    --

    -- Read the arguments struct
    local structs_layout_map = {}
    parametersSubtree = dataSubtree:add(buffer(offset), "Main Arguments Struct")
    parametersSubtree:add_le(struct_num_bytes, buffer(offset, 4));                              offset = offset + 4
    parametersSubtree:add_le(struct_version, buffer(offset, 4));                                offset = offset + 4
    if _struct_num_bytes()() > 8 then
        local fields_size = _struct_num_bytes()() - 8
        local fields = parametersSubtree:add(arguments_values, buffer(offset, fields_size));       

        if interface_resolved then
            structs_layout_map = read_struct_fields(fields, offset, buffer(offset), module_path, definition, _struct_num_bytes()(), true)
        end

        offset = offset + fields_size
    end
    parametersSubtree:set_len(_struct_num_bytes()())

    -- Read the nested structures/arrays
    local unknown_fields_offset = 0
    local nestedParamsTree = dataSubtree:add(buffer(offset), "Nested structures and arrays")
    while (offset < length and length - offset > 4)  do

        local struct_header_length = buffer(offset, 4):le_uint()
        local struct_version_or_array_length = buffer(offset + 4, 4):le_uint()

        if struct_header_length <= 0 then break end
        if struct_header_length >= buffer:len() then break end

        -- align struct length to 8
        if struct_header_length % 8 ~= 0 then struct_header_length = struct_header_length + (8 - struct_header_length % 8) end

        struct_tree = nestedParamsTree:add(method_parameters, buffer(offset, struct_header_length)); 
        
        local fields_data = buffer(offset + 8, struct_header_length - 8)

        structs_layout_map_2 = {}
        if structs_layout_map[offset] ~= nil then
            -- we know what the definition of this field is.

            local field_definition = structs_layout_map[offset]
            local field_type = common.split(field_definition, " ")[1]
            local field_name = common.split(field_definition, " ")[2]

            struct_tree:set_text(field_type .. " " .. field_name)

            if field_type == "string" or common.startswith(field_type, "array<") then
                -- this is an array
                local num_elements = buffer(offset+4, 4):le_uint()

                struct_tree:add_le(array_num_bytes, buffer(offset, 4));                                                         offset = offset + 4
                struct_tree:add_le(array_elements_count, buffer(offset, 4));                                                    offset = offset + 4
                fields_tree = struct_tree:add(fields_data, "Array Elements");           

                structs_layout_map_2 = read_array_memebers(fields_tree, offset, buffer(offset), module_path, field_definition, num_elements)
            else
                -- this is a struct

                struct_tree:add_le(struct_num_bytes, buffer(offset, 4));                                                        offset = offset + 4
                struct_tree:add_le(struct_version, buffer(offset, 4));                                                          offset = offset + 4
                fields_tree = struct_tree:add(fields_data, "Struct Fields");            

                structs_layout_map_2 = read_struct_fields(fields_tree, offset, buffer(offset), module_path, field_definition, struct_header_length)
            end

            structs_layout_map = common.merge_tables(structs_layout_map, structs_layout_map_2);
        else
            -- this could be either a struct or an array
            -- let's do best effort
            local num_elements_or_version = buffer(offset+4, 4):le_uint()
            if num_elements_or_version > 4 then
                -- looks like an array\string
                local num_elements = buffer(offset+4, 4):le_uint()

                struct_tree:add_le(array_num_bytes, buffer(offset, 4));                                                         offset = offset + 4
                struct_tree:add_le(array_elements_count, buffer(offset, 4));                                                    offset = offset + 4
                fields_tree = struct_tree:add(fields_data, "Array Elements");           

                fields_tree:set_text("Text: " .. truncate_text(buffer(offset, num_elements):string()) .. "")

            else
                -- assume it's a struct
                struct_tree:add_le(struct_num_bytes, buffer(offset, 4));                                                        offset = offset + 4
                struct_tree:add_le(struct_version, buffer(offset, 4));                                                          offset = offset + 4
                struct_tree:add(struct_fields, fields_data);            
            end

            if unknown_fields_offset == 0 then unknown_fields_offset = offset end
        end

        offset = offset + struct_header_length - 8

    end
    if offset < length then
        dataSubtree:add(method_parameters, buffer(offset));
    end

    --
    -- Preety-print the information
    --

    name_subtree:append_text(" [" .. method_name .. "]")
    subtree:append_text(", Interface ID: " .. string.format("0x%x", _interfaceid()()) .. ", Name: " .. string.format("0x%x", _method_name()()) .. " [" .. short_method_name .. "]")

    if _is_response()() then
        -- this is a reseponse
        pinfo.cols.info = tostring(pinfo.cols.info) .. " Response to " .. short_method_name
    else
        -- this is a request

        if method_name == "IPC.mojom.Channel.Receive" then
            -- legacy IPC
            dataSubtree:add_proto_expert_info(expert_info_legacyipc)
            Dissector.get("legacyipc"):call(buffer(unknown_fields_offset):tvb(), pinfo, tree)
            return
        end

        pinfo.cols.info = tostring(pinfo.cols.info) .. " Method " .. short_method_name

        if interface_resolved then
            -- some parenthesis cosmetics 
            if string.sub(common.split(definition, "(")[2], 1, 1) ~= ")" then
                pinfo.cols.info = tostring(pinfo.cols.info) .. "(...)"
            else
                pinfo.cols.info = tostring(pinfo.cols.info) .. "()"
            end
        end
    end

    if not interface_resolved then
        -- pinfo.cols.info = tostring(pinfo.cols.info) .. " [Unresolved Interface]"
        subtree:add_proto_expert_info(expert_info_unresolved_interface )
    end

end

function read_struct_fields(tree, initial_offset, buffer, module_path, struct_field_definition, struct_size, is_method)

    local offset = 0
    local structs_layout_map = {}

    local struct_definition = ""
    local struct_field_type = ""
    local struct_field_name = ""
    
    if not is_method then
        -- this is a regular struct

        struct_field_type = common.split(struct_field_definition, " ")[1]
        struct_field_name = common.split(struct_field_definition, " ")[2]

        struct_info = get_struct_info(struct_field_type, module_path)
        if struct_info ~= nil then
            struct_definition = struct_info["definition"]
            local struct_link = struct_info["link"]

            tree:add(link_field, struct_link):set_text("[" .. struct_link .. "]")
        else
            return structs_layout_map
        end

        if not mojo_protocol.prefs.enable_deep_inspection then
            -- don't really read the struct, just show the bytes
        
            if struct_size - 8 > 0 then 
                tree:append_text(": " .. truncate_text(buffer(offset, struct_size - 8):bytes():tohex()))
            end

            return structs_layout_map
        end
    else
        -- this is a method arguments struct

        struct_definition = struct_field_definition
    end

    local field_definitions = reorder_fields(fields_from_struct_definition(struct_definition), module_path)
    local fields_count = #field_definitions

    -- iterate the fields in this struct
    local context = {}
    for i, definition in ipairs(field_definitions) do
        local field_type = common.split(definition, " ")[1]
        local field_name = common.split(definition, " ")[2]

        if struct_field_name ~= "" then
            field_name = struct_field_name .. "." .. field_name
        end

        local next_field_type = i + 1 <= fields_count and common.split(field_definitions[i+1], " ")[1] or nil

        if struct_field_type:find("%.") then
            -- the default module path of a field is the module path of the parent struct
            module_path = struct_field_type:sub(1, common.find_last(struct_field_type, "%.") - 1)
        end

        local field_offset = initial_offset + offset
        field_size, referenced_type_offset, referenced_type_definition = read_field(tree, field_offset, buffer(offset), module_path, 
                                                                                    field_type, field_name, next_field_type, context)
        offset = offset + field_size

        if referenced_type_definition ~= "" then
            -- we read a pointer, so update the map
            structs_layout_map[referenced_type_offset] = referenced_type_definition
        end

        if offset >= struct_size then return structs_layout_map end
    end

    return structs_layout_map
end

function read_array_memebers(tree, initial_offset, buffer, module_path, array_definition, num_elements)

    local offset = 0
    local structs_layout_map = {}

    local field_type = common.split(array_definition, " ")[1]
    local field_name = common.split(array_definition, " ")[2]

    if field_type == "string" and num_elements > 0 then
        tree:set_text("Text: " .. truncate_text(buffer(offset, num_elements):string()) .. "")
        return structs_layout_map
    end

    -- this is an array of some other type

    local element_type = field_type:sub(7, common.endswith(field_type, "?") and -3 or -2)
    local type_size, type_alignment, is_pointer, is_basic_type = get_mojom_type_info(element_type, module_path)

    if element_type == "uint8" and num_elements > 0 then
        -- this looks like a buffer

        tree:set_text("Buffer: " .. truncate_text(buffer(offset, num_elements):bytes():tohex()) .. "")
        return structs_layout_map
    end

    local array_size = num_elements * type_size

    tree:set_len(array_size)

    if not mojo_protocol.prefs.enable_deep_inspection then
        -- don't really read the array, just show the bytes

        if array_size > 0 then 
            tree:append_text(": " .. truncate_text(buffer(offset, array_size):bytes():tohex()))
        end
        return structs_layout_map
    end

    local context = {}
    for i=1, num_elements do
        local element_field_name = field_name .. "[" .. (i-1) .. "]"
        local element_definition = element_type .. " " .. element_field_name
        local next_field_type = element_type

        local field_offset = initial_offset + offset
        field_size, referenced_type_offset, referenced_type_definition = read_field(tree, field_offset, buffer(offset), module_path, 
                                                                                    element_type, element_field_name, next_field_type, context)
        offset = offset + field_size

        if referenced_type_definition ~= "" then
            -- we read a pointer, so update the map
            structs_layout_map[referenced_type_offset] = referenced_type_definition
        end
    end

    return structs_layout_map
end

function read_field(tree, initial_offset, buffer, module_path, field_type, field_name, next_field_type, context)

    local offset = 0
    local bool_bit = context["bool_bit"]; if bool_bit == nil then bool_bit = 0 end
    local referenced_type_offset = 0
    local referenced_type_definition = ""

    local type_size, type_alignment, is_pointer, is_basic_type = get_mojom_type_info(field_type, module_path)
    local missing_padding = (type_alignment - (initial_offset % type_alignment)) % type_alignment

    -- skip some missing papdding if needed
    if type_size ~= 0 then
        offset = missing_padding
    end

    -- TODO: show unions data & enums if needed
    -- TODO #2: handle maps (e.g in UkmRecorderInterface.AddEntry / OnBeginFrame)

    if is_pointer then
        -- this is a pointer to a struct, array, map, string, etc.
            
        local pointer_value = buffer(offset, 8):le_int64():tonumber()
        local struct_offset = tonumber(tostring(initial_offset + offset + pointer_value))
        local full_field_type = is_basic_type and field_type or fully_qualified_name(field_type, module_path)

        referenced_type_offset = struct_offset
        referenced_type_definition = full_field_type .. " " .. field_name

        fieldTree = tree:add_le(buffer(offset, 8), field_type .. " " .. field_name .. " (pointer):");       offset = offset + 8

        if common.endswith(field_type, "?") and pointer_value == 0 then
            fieldTree:append_text(" NULL")
        else
            fieldTree:append_text(" +" .. pointer_value)
        end

    elseif type_size ~= 0 then
        -- this is some basic type

        fieldTree = tree:add(buffer(offset, type_size), field_type .. " " .. field_name)

        field_string = mojom_bytes_to_string(field_type, module_path, buffer(offset, type_size), bool_bit)
        if field_string ~= nil then
            fieldTree:append_text(": " .. field_string)
        end

        -- special handling for booleans (since there are packed together)
        if field_type == "bool" and next_field_type == "bool" and bool_bit < 7 then
            type_size = 0
        end

        offset = offset + type_size

        if field_type == "bool" then
            bool_bit = (bool_bit + 1) % 8
        end
    end

    context["bool_bit"] = bool_bit

    return offset, referenced_type_offset, referenced_type_definition
end

function reorder_fields(field_definitions, module_path)
    -- pack the fields in the order they would appear on wire
    -- https://source.chromium.org/chromium/chromium/src/+/master:mojo/public/tools/mojom/mojom/generate/pack.py;l=136

    local ordered_field_infos = {}
    local ordered_field_defintions = {}
    local fields_count = #field_definitions
    local offset = 0
    local last_field_offset = 0
    local bool_bit = 0

    -- iterate the fields in this struct
    for i, definition in ipairs(field_definitions) do
        local field_type = common.split(definition, " ")[1]
        local field_name = common.split(definition, " ")[2]
        local type_size, type_alignment, is_pointer, is_basic_type = get_mojom_type_info(field_type, module_path)

        -- by deafult, we will insert the field at the end
        offset = last_field_offset

        local next_field_type = i + 1 <= fields_count and common.split(field_definitions[i+1], " ")[1] or nil
        local prev_field_type = i -1 >= 1 and common.split(field_definitions[i-1], " ")[1] or nil
        local prev_field_bit = bool_bit

        -- maybe there is a padding hole in which we can insert our field
        local current_field_index = #ordered_field_infos + 1
        for j, field_info in ipairs(ordered_field_infos) do
            if j + 1 > #ordered_field_infos then break end

            local next_field = ordered_field_infos[j+1]

            prev_field_type = field_info[1]
            local prev_field_offset = field_info[2]
            prev_field_bit = field_info[3]
            local prev_field_size = field_info[4]

            local next_field_type_temp = next_field[1]
            local next_field_offset = next_field[2]

            local hole_size = next_field_offset - (prev_field_offset + prev_field_size)
            if hole_size >= type_size then
                -- found a hole with a sufficient size
                -- this is true for bools too as long as the packing is not finished

                current_field_index = j + 1
                offset = prev_field_offset + prev_field_size
                next_field_type = next_field_type_temp
                break
            end
        end

        local is_boolean_packed_mode = field_type == "bool" and (prev_field_type == "bool" or next_field_type == "bool")

        if is_boolean_packed_mode and bool_bit < 7 then
            -- we want to insert a bool and we are in packing mode
            type_size = 0
        end

        -- skip some missing papdding if needed
        if type_size ~= 0 then
            local missing_padding = (type_alignment - (offset % type_alignment)) % type_alignment
            offset = offset + missing_padding
        end

        if current_field_index == #ordered_field_infos + 1 then last_field_offset = offset + type_size end

        table.insert(ordered_field_infos, current_field_index, {field_type, offset, bool_bit, type_size})
        table.insert(ordered_field_defintions, current_field_index, definition)

        if is_boolean_packed_mode then
            bool_bit = (bool_bit + 1) % 8
        end
    end

    return ordered_field_defintions
end

function get_mojom_type_info(field_type, module_path)
    -- 
    -- https://source.chromium.org/chromium/chromium/src/+/master:mojo/public/tools/mojom/mojom/generate/pack.py;l=19
    -- GetSizeForKind
    --

    local is_pointer = false
    local is_basic_type = true
    local type_size = 0
    local type_alignment = 0

    if field_type == "uint8" or field_type == "int8" then
        type_size = 1; type_alignment = 1
    elseif field_type == "uint16" or field_type == "int16" then
        type_size = 2; type_alignment = 2
    elseif field_type == "uint32" or field_type == "int32" then
        type_size = 4; type_alignment = 4
    elseif field_type == "uint64" or field_type == "int64" then
        type_size = 8; type_alignment = 8
    elseif field_type == "float" then
        type_size = 4; type_alignment = 4
    elseif field_type == "double" then
        type_size = 8; type_alignment = 8
    elseif field_type =="bool" then
        -- bools are tricky because they are packed together to a bit field, but by default they will be considered as 1-byte
        type_size = 1; type_alignment = 1
    elseif field_type == "string" then
        -- strings are considered as pointer to arrays
        type_size = 8; type_alignment = 8
        is_pointer = true
    elseif common.startswith(field_type, "array") then
        -- a pointer
        type_size = 8; type_alignment = 8
        is_pointer = true; is_basic_type = false
    elseif common.startswith(field_type, "map") then
        type_size = 8; type_alignment = 8
        is_pointer = true; is_basic_type = false
    elseif common.startswith(field_type, "handle<") or field_type == "handle" then
        type_size = 4; type_alignment = 4
    elseif common.startswith(field_type, "pending_receiver") or common.startswith(field_type, "pending_associated_receiver") then
        type_size = 4; type_alignment = 4
    elseif common.startswith(field_type, "pending_") then
        type_size = 8; type_alignment = 4
    else
        -- this is likely a struct, enum, or a union

        struct_info = get_struct_info(field_type, module_path)

        if struct_info ~= nil then
            is_basic_type = false

            local definition = struct_info["definition"]
            if common.startswith(definition, "struct") then
                type_size = 8; type_alignment = 8
                is_pointer = true
            elseif common.startswith(definition, "union") then
                type_size = 16; type_alignment = 8
                is_pointer = false
            elseif common.startswith(definition, "enum") then
                type_size = 4; type_alignment = 4
                is_pointer = false
            end
        end
    end

    if type_size == 0 then
        -- we don't know what it is, assume pointer
        type_size = 8; type_alignment = 8; is_pointer = true; is_basic_type = false
    end

    return type_size, type_alignment, is_pointer, is_basic_type
end

function mojom_bytes_to_string(field_type, module_path, bytes, bool_bit)
    
    -- deal with nullable (e.g "SomeType? hi, ...") arguments
    local is_nullable = common.endswith(field_type, "?")
    if is_nullable then
        field_type = field_type:sub(1, #field_type-1)
    end

    local fieldString = nil
    if field_type == "int32" then
        fieldString = "" .. bytes:le_int()
    elseif field_type == "uint32" then
        fieldString = "" .. bytes:le_uint()
    elseif field_type == "int64" then
        fieldString = "" .. bytes:le_int64()
    elseif field_type == "uint64" then
        fieldString = "" .. bytes:le_uint64()
    elseif field_type == "float" then
        fieldString = "" .. bytes:le_float()
    elseif field_type == "double" then
        fieldString = "" .. bytes:le_float()
    elseif field_type == "int16" then
        fieldString = "" .. common.numLong(bytes:string())
    elseif field_type == "uint16" then
        fieldString = "" .. common.numLong(bytes:string())
    elseif field_type == "int8" then
        fieldString = "" .. common.numLong(bytes:string())
    elseif field_type == "uint8" then
        fieldString = "" .. common.numLong(bytes:string())
    elseif field_type == "string" then
        fieldString = "\"" .. bytes:string() .. "\""
    elseif field_type == "bool" then
        local anded_value = bit32.lshift(1, bool_bit)
        local bool_value = bit32.band(common.numLong(bytes:string()), anded_value)

        if bool_value == 0 then
            fieldString = "false"
        else
            fieldString = "true"
        end

    elseif common.startswith(field_type, "pending_receiver") or common.startswith(field_type, "handle<") then
        fieldString = "Mojo handle #" .. bytes:le_int()

        if is_nullable and bytes:le_int() == -1 then
            fieldString = "NULL"
        end
    elseif common.startswith(field_type, "pending_") then
        fieldString = "Mojo handle #" .. bytes:le_int64()

        if is_nullable and bytes:le_int64() == -1 then
            fieldString = "NULL"
        end
    else
        -- maybe it is an enum or union
        local struct_info = get_struct_info(field_type, module_path)
        if struct_info ~= nil then
            local definition = struct_info["definition"]
            if common.startswith(definition, "enum") then
                fieldString = bytes:le_int() .. " (?)"
            elseif common.startswith(definition, "union") then
                fieldString = "union data"
            end
        end
    end

    return fieldString
end

function fields_from_struct_definition(struct_definition)
    
    if string.find(struct_definition, "%(") then
        -- these are actually method parameters, in the form of
        -- MethodName(Type1 name1, Type2 name2, ...) => (ReturnType1 OtherName1, ...)
        
        struct_definition = struct_definition:match("%b()"):sub(2, -2)

        -- before splitting to fields by the commans,
        -- there could be a comma in map<S,T> or even things like map<Something<T, S>, S2>
        -- so we need to first elimenate all false commas
        while true do
            local angled_string = struct_definition:match("%b<>")
            if angled_string == nil then break end

            local new_angled_string = angled_string:gsub(",", "!comma!"):gsub("<", "!angle1!"):gsub(">", "!angle2!")
            struct_definition = struct_definition:gsub(angled_string, new_angled_string)
        end

        struct_definition = struct_definition:gsub(",", ";")

        -- restore the values we replaced if needed
        struct_definition = struct_definition:gsub("!comma!", ","):gsub("!angle1!", "<"):gsub("!angle2!", ">")

    elseif struct_definition:find("{") ~= nil then
        -- regular struct definition

        struct_definition = struct_definition:sub((struct_definition:find("{")))
        struct_definition = struct_definition:gsub("{", ""):gsub("}", "")
    elseif struct_definition:find("struct ") ~= nil then
        -- this might be a [Native] definition, which we don't currently fully support.

        return {"array<uint8> native_struct_data", "array<handle>? handles"}
    end

    -- clean it up
    struct_definition = common.trim(struct_definition)

    -- split to fields by semicolom
    field_definitions = common.split(struct_definition, ";")

    for i, definition in ipairs(field_definitions) do
        field_definitions[i] = common.trim(field_definitions[i])
    end

    return field_definitions

end

function fully_qualified_name(struct_name, module_path)

    -- TODO: handle nested stuff and maps too (example: map<S, array<T, G>>)

    if common.startswith(struct_name, "array<") then
        local element_type = struct_name:sub(7, common.endswith(struct_name, "?") and -3 or -2)

        local type_size, type_alignment, is_pointer, is_basic_type = get_mojom_type_info(element_type, module_path)

        local new_element_type = element_type
        if not is_basic_type and string.find(element_type, "%.") == nil then
            new_element_type = module_path .. "." .. element_type
        end
        struct_name = struct_name:gsub(element_type, new_element_type)
    elseif common.startswith(struct_name, "map<") then
        -- TODO
        return struct_name

    elseif string.find(struct_name, "%.") == nil then
        struct_name = module_path .. "." .. struct_name
    end

    return struct_name
end

function get_struct_info(struct_name, module_path)
    -- resolve shortned names to full names
    struct_name = fully_qualified_name(struct_name, module_path)

    if common.endswith(struct_name, "?") then
        -- nullable
        struct_name = struct_name:sub(1, #struct_name-1)
    end

    return mojo_interfaces_info[struct_name]
end

function to_128bit_hex_string(buffer)
  str = string.format('%x%x%x%x', buffer(0, 4):uint(), buffer(4, 4):uint(),
                                               buffer(8, 4):uint(), buffer(12, 4):uint())

  return str
end

function to_64bit_hex_string(buffer)
  str = string.format('%x%x', buffer(0, 4):uint(), buffer(4, 4):uint())

  return str
end

function truncate_text(text)
    local max_len = 50
    if text:len() > max_len then
        text = text:sub(1, max_len) .. "..."
    end

    return text
end