#!/usr/bin/env ruby
require 'xcodeproj'

# 定義專案根目錄
ROOT = File.expand_path('.', __dir__)
project_path = File.join(ROOT, 'RecordAnalyzerApp.xcodeproj')
project = Xcodeproj::Project.open(project_path)
# 找到目標
target = project.targets.find { |t| t.name == 'RecordAnalyzer' }
raise "Error: 找不到 RecordAnalyzer 目標" unless target

# 要包含的目錄列表
source_dirs = ['RecordAnalyzer/Models', 'RecordAnalyzer/Views/Components', 'RecordAnalyzer/Views', 'RecordAnalyzer/Managers', 'RecordAnalyzer/Services']

source_dirs.each do |dir|
  Dir.glob(File.join(ROOT, dir, '**', '*.swift')).each do |full_path|
    # 相對路徑
    relative_path = full_path.sub("#{ROOT}/", '')
    # 取得或新增檔案參考
    file_ref = project.main_group.find_file_by_path(relative_path) || project.main_group.new_file(relative_path)
    # 檢查是否已加入 Compile Sources
    unless target.source_build_phase.files_references.any? { |f| f.path == file_ref.path }
      target.add_file_references([file_ref])
      puts "已加入目標: #{relative_path}"
    end
  end
end

# 儲存專案檔
project.save
puts '完成：所有 Swift 檔已更新至 RecordAnalyzer 目標' 