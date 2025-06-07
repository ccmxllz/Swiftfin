#!/usr/bin/env ruby

require 'xcodeproj'

# 打开项目
project_path = '/Users/jiayun/soft/gitee-projects/Swiftfin/Swiftfin.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到目标
shared_target = project.targets.find { |target| target.name == 'Shared' }
swiftfin_target = project.targets.find { |target| target.name == 'Swiftfin iOS' }

puts "Found targets:"
puts "Shared: #{shared_target&.name}"
puts "Swiftfin iOS: #{swiftfin_target&.name}"

# 定义要添加的文件
shared_files = [
  'Shared/Objects/DanmakuConfiguration.swift',
  'Shared/Services/DanmakuService.swift', 
  'Shared/ViewModels/DanmakuViewModel.swift',
  'Shared/Components/DanmakuView.swift',
  'Shared/Components/DanmakuRenderer.swift'
]

swiftfin_files = [
  'Swiftfin/Views/VideoPlayer/Overlays/DanmakuOverlay.swift',
  'Swiftfin/Views/VideoPlayer/Overlays/Components/ActionButtons/DanmakuActionButton.swift',
  'Swiftfin/Views/SettingsView/VideoPlayerSettingsView/Components/Sections/DanmakuSection.swift'
]

# 添加 Shared 文件
if shared_target
  shared_files.each do |file_path|
    if File.exist?(file_path)
      # 找到对应的组
      group_path = File.dirname(file_path).split('/')[1..-1]
      group = project.main_group
      
      group_path.each do |group_name|
        existing_group = group.children.find { |child| child.display_name == group_name }
        if existing_group
          group = existing_group
        else
          group = group.new_group(group_name)
        end
      end
      
      # 检查文件是否已经存在
      file_name = File.basename(file_path)
      existing_file = group.children.find { |child| child.display_name == file_name }
      
      unless existing_file
        file_ref = group.new_reference(file_path)
        shared_target.source_build_phase.add_file_reference(file_ref)
        puts "Added #{file_path} to Shared target"
      else
        puts "File #{file_path} already exists in project"
      end
    else
      puts "File not found: #{file_path}"
    end
  end
end

# 添加 Swiftfin 文件
if swiftfin_target
  swiftfin_files.each do |file_path|
    if File.exist?(file_path)
      # 找到对应的组
      group_path = File.dirname(file_path).split('/')[1..-1]
      group = project.main_group
      
      group_path.each do |group_name|
        existing_group = group.children.find { |child| child.display_name == group_name }
        if existing_group
          group = existing_group
        else
          group = group.new_group(group_name)
        end
      end
      
      # 检查文件是否已经存在
      file_name = File.basename(file_path)
      existing_file = group.children.find { |child| child.display_name == file_name }
      
      unless existing_file
        file_ref = group.new_reference(file_path)
        swiftfin_target.source_build_phase.add_file_reference(file_ref)
        puts "Added #{file_path} to Swiftfin iOS target"
      else
        puts "File #{file_path} already exists in project"
      end
    else
      puts "File not found: #{file_path}"
    end
  end
end

# 保存项目
project.save
puts "Project saved successfully!"
