MRAPROTO = Proto ("MRA", "MRA Protocol")

local f = MRAPROTO.fields

local commands = { 
    [0x00] = "Get System Version",
    [0x03] = "Get Audio Sense State ",
    [0x21] = "Get Current Volume",
    [0x23] = "Get Tone Control",
    [0x25] = "Get Do Not Disturb",
    [0x26] = "Set Routing Map",
    [0x27] = "Get Routing Map",
}

local results = {
    [0x00] = "Success/OK",
    [0x01] = "Data Returned",
    [0xFC] = "Invalid Command",
    [0xFE] = "Invalid Checksum",
}

f.sync1 = ProtoField.uint8 ("mra.sync1", "Sync 1", base.HEX)
f.sync2 = ProtoField.uint8 ("mra.sync2", "Sync 2", base.HEX)
f.length =  ProtoField.uint16 ("mra.length", "Length")
f.command =  ProtoField.uint8 ("mra.command", "Command", base.HEX, commands)
f.result =  ProtoField.uint8 ("mra.result", "Result", base.HEX, results)
f.data =  ProtoField.bytes ("mra.data", "Data", base.HEX)
f.checksum =  ProtoField.bytes ("mra.checksum", "Checksum", base.HEX)

f.audio_sense_1 = ProtoField.new("Audio 1", "audiosense.1", ftypes.BOOLEAN, {"On","Off"}, 8, 0x80)
f.audio_sense_2 = ProtoField.new("Audio 2", "audiosense.2", ftypes.BOOLEAN, {"On","Off"}, 8, 0x40)
f.audio_sense_3 = ProtoField.new("Audio 3", "audiosense.3", ftypes.BOOLEAN, {"On","Off"}, 8, 0x20)
f.audio_sense_4 = ProtoField.new("Audio 4", "audiosense.4", ftypes.BOOLEAN, {"On","Off"}, 8, 0x10)
f.audio_sense_5 = ProtoField.new("Audio 5", "audiosense.5", ftypes.BOOLEAN, {"On","Off"}, 8, 0x08)
f.audio_sense_6 = ProtoField.new("Audio 6", "audiosense.6", ftypes.BOOLEAN, {"On","Off"}, 8, 0x04)
f.audio_sense_paging = ProtoField.new("Paging Input", "audiosense.paging_input", ftypes.BOOLEAN, {"1","0"}, 8, 0x02)

f.audio_input = ProtoField.uint8("mra.routing_map_input","Audio Input")
f.audio_output = ProtoField.uint8("mra.routing_map_output","Audio Output")

f.zone_output = ProtoField.uint8("mra.zone_output","Zone Output")

f.major_version = ProtoField.uint8("mra.major_version", "Major Version Number")
f.minor_version = ProtoField.uint8("mra.minor_version", "Minor Version Number")
f.subversion = ProtoField.uint8("mra.subversion", "Subversion number")
f.build = ProtoField.uint8("mra.build", "Build number")



function MRAPROTO.dissector (buffer, pinfo, tree)
    local subtree = tree:add (MRAPROTO, buffer())
    local offset = 0

    local sync1 = buffer (offset, 1)
    subtree:add (f.sync1, sync1)
    offset = offset + 1

    local sync2 = buffer (offset, 1)
    subtree:add (f.sync2, sync2)
    offset = offset + 1

    local length = buffer (offset, 2)
    subtree:add (f.length, length)
    offset = offset + 2

    local command = buffer (offset, 1)
    subtree:add (f.command, command)
    offset = offset + 1
    
    local request = pinfo.dst_port == 10200
    local response = pinfo.dst_port ~= 10200
    local result = 0
    local data = false
    local data_tree = nil

    if (response) then
	local result = buffer(offset, 1)
	subtree:add(f.result, result)
        offset = offset + 1
	result = result:uint()
    end

    if (result and length:uint()>2 or not result and length:uint()>1) then
        data = buffer (offset, length:uint() - 2)
	data_tree = subtree:add (f.data, data)
        offset = offset + length:uint() - 2
    end

    if (request and length:uint() > 1) then
        data = buffer (offset, length:uint() - 1)
	data_tree = subtree:add (f.data, data)
        offset = offset + length:uint() - 2
    end

    if (response and command:uint() == 3 and result==1) then
        data_tree:add(f.audio_sense_1, data)
        data_tree:add(f.audio_sense_2, data)
        data_tree:add(f.audio_sense_3, data)
        data_tree:add(f.audio_sense_4, data)
        data_tree:add(f.audio_sense_5, data)
        data_tree:add(f.audio_sense_6, data)
        data_tree:add(f.audio_sense_paging, data)
    end

    if (response and command:uint() == 0) then
        data_tree:add(f.major_version, data:range(0,1))
        data_tree:add(f.minor_version, data:range(1,1))
        data_tree:add(f.subversion, data:range(2,1))
        data_tree:add(f.build, data:range(3,1))
    end

    if (request and command:uint() == 0x21) then
	subtree:add(f.zone_output, data:range(0,1))
--	offset = offset + 1
    end

    if (request and command:uint() == 0x26) then 
        data_tree:add(f.audio_input, data:range(0,1))
--	offset = offset + 1
        data_tree:add(f.audio_output, data:range(1,1))
    end


    local checksum = buffer (offset, 1)
    subtree:add (f.checksum, checksum)
end

tcp_table = DissectorTable.get ("tcp.port")
tcp_table:add (10200, MRAPROTO)
