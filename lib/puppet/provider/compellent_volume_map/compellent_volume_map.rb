require 'puppet/provider/compellent'
require 'puppet/files/ResponseParser'
require 'puppet/files/CommonLib'

Puppet::Type.type(:compellent_volume_map).provide(:compellent_volume_map, :parent => Puppet::Provider::Compellent) do
  @doc = "Manage Compellent map/unmap volume."

  attr_accessor :hash_map
  @hash_map
  def showvolume_commandline
    command = "volume show -name '#{@resource[:name]}'"
    folder_value = @resource[:volumefolder]
    if ((folder_value != nil) && (folder_value.length > 0))
      command = command + " -folder '#{folder_value}'"
    end
    return command
  end

  def showserver_commandline
    command = "server show -name '#{@resource[:servername]}'"
    folder_value = @resource[:serverfolder]
    if ((folder_value != nil) && (folder_value.length > 0))
      command = command + " -folder '#{folder_value}'"
    end
    return command
  end

  def get_deviceid
    Puppet.debug("Fetching information about the Volume")
    libpath = CommonLib.get_path(1)
    resourcename = @resource[:name]
    Puppet.debug("executing show volume command")

    vol_show_cli = showvolume_commandline
    volumeshow_exitcodexml = "#{CommonLib.get_log_path(1)}/volumeShowExitCode_#{CommonLib.get_unique_refid}.xml"
    volumeshow_responsexml = "#{CommonLib.get_log_path(1)}/volumeShowResponse_#{CommonLib.get_unique_refid}.xml"
    transport.command_exec("#{libpath}","#{volumeshow_exitcodexml}","\"#{vol_show_cli} -xml #{volumeshow_responsexml}\"")
    
    parser_obj=ResponseParser.new('_')
    folder_value = @resource[:volumefolder]
    if ((folder_value != nil) && (folder_value.length > 0))
      parser_obj.parse_discovery(volumeshow_exitcodexml,volumeshow_responsexml,0)
      hash= parser_obj.return_response
    else
      hash = parser_obj.retrieve_empty_folder_volume_properties(volumeshow_responsexml,@resource[:name])
    end
    File.delete(volumeshow_exitcodexml,volumeshow_responsexml)
    device_id = "#{hash['volume_DeviceID']}"

    return device_id
  end

  def map_volume_commandline
    command = "volume map -server '#{@resource[:servername]}'"
    folder_value = @resource[:serverfolder]
    device_id = get_deviceid
    Puppet.debug("Device Id for Volume - #{device_id}")

    if  "#{device_id}".size != 0
      Puppet.debug("appending device ID in command")
      command = command + " -deviceid #{device_id}"
    end

    lun_value = @resource[:lun]
    if "#{lun_value}".size != 0
      command = command + " -lun '#{lun_value}'"
    end

    localport_value = @resource[:localport]
    if "#{localport_value}".size != 0
      command = command + " -localport '#{localport_value}'"
    end

    volume_boot = @resource[:boot]
    if (volume_boot == :true)
      command = command + " -boot"
    end

    volume_force = @resource[:force]
    if (volume_force == :true)
      command = command + " -force"
    end

    volume_readonly = @resource[:readonly]
    if (volume_readonly == :true)
      command = command + " -readonly"
    end

    volume_singlepath = @resource[:singlepath]
    if (volume_singlepath == :true)
      command = command + " -singlepath"
    end
    return command
  end

  def create
    Puppet.debug("Inside create method.")
    libpath = CommonLib.get_path(1)
    resourcename = @resource[:name]
    servername = @resource[:servername]
    map_volume_cli = map_volume_commandline
    Puppet.debug("Map Volume CLI - #{map_volume_cli}")
    Puppet.debug("Map volume with name '#{resourcename}'")
    device_id = get_deviceid
    if  "#{device_id}".size != 0
      mapvolume_exitcodexml = "#{CommonLib.get_log_path(1)}/mapVolumeExitCode_#{CommonLib.get_unique_refid}.xml"
      transport.command_exec("#{libpath}","#{mapvolume_exitcodexml}","\"#{map_volume_cli}\"")
      parser_obj=ResponseParser.new('_')
      parser_obj.parse_exitcode(mapvolume_exitcodexml)
      hash= parser_obj.return_response
      File.delete(mapvolume_exitcodexml)
      if "#{hash['Success']}".to_str() == "TRUE"
        Puppet.info("Successfully mapped volume '#{resourcename}' with the server '#{servername}'.")
      elsif "#{hash['Error']}".to_str.include?('Server already mapped to volume')
        Puppet.info("Server '#{servername}' already mapped to volume '#{resourcename}'")
      else
        raise Puppet::Error, "#{hash['Error']}"
      end
    else
      Puppet.info("Volume '#{resourcename}' not found to map with server '#{servername}'.")
    end

  end

  def destroy
    Puppet.debug("Inside destroy method.")
    libpath = CommonLib.get_path(1)
    resourcename = @resource[:name]
    device_id = get_deviceid
    Puppet.debug("Device Id for Volume - #{device_id}")
    if device_id != ""
    Puppet.debug("Invoking destroy command")
      unmapvolume_exitcodexml = "#{CommonLib.get_log_path(1)}/unmapVolumeExitCode_#{CommonLib.get_unique_refid}.xml"
      transport.command_exec("#{libpath}","#{unmapvolume_exitcodexml}","volume unmap -deviceid #{device_id}")
      parser_obj=ResponseParser.new('_')
      parser_obj.parse_exitcode(unmapvolume_exitcodexml)
      hash= parser_obj.return_response
      File.delete(unmapvolume_exitcodexml)
      if "#{hash['Success']}".to_str() == "TRUE"
        Puppet.info("Successfully unmapped volume '#{resourcename}' with the server.")
      else
        raise Puppet::Error, "#{hash['Error']}"
      end
	else
        Puppet.info("Volume '#{resourcename}' not found to unmap with server '#{servername}'.")  
    end

  end

  def exists?
    libpath = CommonLib.get_path(1)
    resourcename = @resource[:name]
    servername = @resource[:servername]
    show_server_cli = showserver_commandline
    servershow_exitcodexml = "#{CommonLib.get_log_path(1)}/serverShowExitCode_#{CommonLib.get_unique_refid}.xml"
    servershow_responsexml = "#{CommonLib.get_log_path(1)}/serverShowResponse_#{CommonLib.get_unique_refid}.xml"
    transport.command_exec("#{libpath}","#{servershow_exitcodexml}","\"#{show_server_cli} -xml #{servershow_responsexml}\"")
    parser_obj=ResponseParser.new('_')
    folder_value = @resource[:serverfolder]

    if ((folder_value != nil) && (folder_value.length > 0))
      # For unmap volume and server in folder case
      self.hash_map = parser_obj.retrieve_server_properties(servershow_responsexml)
      volume_name = self.hash_map['Volume']
      volume_id = self.hash_map['Volume_ID']
    else
      self.hash_map = parser_obj.retrieve_empty_folder_server_properties(servershow_responsexml,servername)
      Puppet.debug("folder is null, hash_map - #{self.hash_map}")
      volume_name = "#{self.hash_map['Volume']}"
      volume_id = self.hash_map['DeviceId']
    end

    Puppet.debug("volume_name : #{volume_name}")
    Puppet.debug("hash_map - #{self.hash_map}")
    device_id = get_deviceid
    File.delete(servershow_exitcodexml,servershow_responsexml)
    if ((volume_id != nil) && (volume_id.include? device_id))
      Puppet.info("Volume '#{resourcename}' mapped with server '#{servername}'")
      true
    else
      Puppet.info("Volume '#{resourcename}' is not mapped with server '#{servername}'")
      false
    end

  end

end

