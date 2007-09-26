module FlagModelHelper
  def sort_flags_by_attributes(flagtype)
    repoflags = Array.new
    archflags = Array.new
    otherflags = Array.new
    
    self.send("#{flagtype}flags").each_value do |flag|
      repoflags << flag if flag.architecture.nil? and not flag.repository.nil?
      archflags << flag if flag.repository.nil? and not flag.architecture.nil?
      otherflags << flag unless flag.repository.nil? or flag.architecture.nil?
    end
    
    repoflags.sort! {|a,b| a.repository <=> b.repository}
    archflags.sort! {|a,b| a.architecture <=> b.architecture}
    otherflags.sort! {|a,b| a.repository <=> b.repository}
    
    sortedflags = otherflags + archflags + repoflags
    sortedflags << self.send("#{flagtype}flags")["all::all".to_sym]
    return sortedflags
  end  

  
  # this function is using the flag-matrix, which is generated by
  # accessing the self.flagtype-array.
  # the new flag-configuration is derived from this matrix
  def replace_flags( opts )
    #get the altered flag and toggle its status
    flag = self.send("#{opts[:flag_name]}"+"flags")[opts[:flag_id].to_sym]
    flag.toggle_status
    
    sortedflags = sort_flags_by_attributes(flag.name)
    
    # don't store the global enable-flag for projects
    if self.class == Project
      sortedflags.delete_if {|flag| flag.repository.nil? and
        flag.architecture.nil? and flag.enabled? }
    end
    
    #create new flag section from the flag matrix
    flags_xml = REXML::Element.new(flag.name)
    #add only flags which are set explicit
    sortedflags.each do |flag|
      flags_xml.add_element flag.to_xml if flag.explicit_set?
    end

    if  self.has_element? flag.name.to_sym
      #split package xml after the flags (from the current type)
      second_part = self.split_data_after flag.name.to_sym

      #remove old flag section from xml
      self.delete_element(flag.name)

      #and add the new flag section
      self.add_element(flags_xml)

      #merge whole project xml
      self.merge_data second_part

    else
      #simply add the flag section

      #split package xml after the persons
      second_part = self.split_data_after :person

      #add the new flag section
      self.add_element(flags_xml)

      #merge whole project xml
      self.merge_data second_part
    end

    self.save

  end

end