#!/usr/bin/env ruby
require 'xcodeproj'

# 定義專案根目錄
ROOT = File.expand_path('.', __dir__)
project_path = File.join(ROOT, 'RecordAnalyzerApp.xcodeproj')
project = Xcodeproj::Project.open(project_path)
# 找到目標
target = project.targets.find { |t| t.name == 'RecordAnalyzer' }
raise "Error: 找不到 RecordAnalyzer 目標" unless target

# 要加入的檔案
file_path = 'RecordAnalyzer/Managers/AudioPlayerManager.swift'
full_path = File.join(ROOT, file_path)

if File.exist?(full_path)
  # 取得或新增檔案參考
  file_ref = project.main_group.find_file_by_path(file_path) || project.main_group.new_file(file_path)
  # 檢查是否已加入 Compile Sources
  unless target.source_build_phase.files_references.any? { |f| f.path == file_ref.path }
    target.add_file_references([file_ref])
    puts "已加入目標: #{file_path}"
  else
    puts "檔案已存在於目標中: #{file_path}"
  end
else
  puts "錯誤：找不到檔案 #{file_path}"
end

# 儲存專案檔
project.save
puts '完成：AudioPlayerManager.swift 已加入 RecordAnalyzer 目標'