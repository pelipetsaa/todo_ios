#!/usr/bin/env ruby
# Optional regeneration: gem install xcodeproj. The generated project is checked in.
require 'xcodeproj'
require 'fileutils'
Dir.chdir(File.expand_path('..', __dir__))
project_path = 'ToDo.xcodeproj'
lock_path = File.join(project_path, 'project.xcworkspace/xcshareddata/swiftpm/Package.resolved')
package_lock = File.read(lock_path) if File.exist?(lock_path)
FileUtils.rm_rf(project_path) if File.exist?(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastUpgradeCheck'] = '1600'
project.root_object.known_regions = ['en', 'ru', 'Base']
project.root_object.development_region = 'en'
app = project.new_target(:application, 'ToDo', :ios, '17.0')
ui_tests = project.new_target(:ui_test_bundle, 'ToDoUITests', :ios, '17.0')
ui_tests.add_dependency(app)

source_group = project.main_group.new_group('ToDo', 'ToDo')
Dir['ToDo/**/*.swift'].sort.each do |path|
  ref = source_group.new_file(path.delete_prefix('ToDo/'))
  app.source_build_phase.add_file_reference(ref)
end
resources = source_group.new_group('Resources', 'Resources')
app.resources_build_phase.add_file_reference(resources.new_file('Assets.xcassets'))
variant = resources.new_variant_group('Localizable.strings')
['en', 'ru'].each do |locale|
  ref = variant.new_file("#{locale}.lproj/Localizable.strings")
  ref.name = locale
end
app.resources_build_phase.add_file_reference(variant)
if File.exist?('ToDo/Resources/PrivacyInfo.xcprivacy')
  app.resources_build_phase.add_file_reference(resources.new_file('PrivacyInfo.xcprivacy'))
end
config_group = project.main_group.new_group('Configuration', 'Configuration')
config_ref = config_group.new_file('Config.xcconfig')
config_group.new_file('Info.plist')
config_group.new_file('Local.xcconfig.example')
package_group = project.main_group.new_group('Packages', 'Packages')
package_group.new_file('TodoKit')
tests_group = project.main_group.new_group('ToDoUITests', 'ToDoUITests')
Dir['ToDoUITests/*.swift'].sort.each do |path|
  ui_tests.source_build_phase.add_file_reference(tests_group.new_file(File.basename(path)))
end

local_package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local_package.relative_path = 'Packages/TodoKit'
project.root_object.package_references << local_package
remote = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
remote.repositoryURL = 'https://github.com/google/GoogleSignIn-iOS'
remote.requirement = { 'kind' => 'exactVersion', 'version' => '8.0.0' }
project.root_object.package_references << remote
[['TodoDomain', local_package], ['TodoApplication', local_package], ['TodoData', local_package], ['TodoPresentation', local_package], ['GoogleSignIn', remote], ['GoogleSignInSwift', remote]].each do |name, package|
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package
  dependency.product_name = name
  app.package_product_dependencies << dependency
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  app.frameworks_build_phase.files << build_file
end

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  config.build_settings['DEBUG_INFORMATION_FORMAT'] = config.name == 'Debug' ? 'dwarf' : 'dwarf-with-dsym'
end
app.build_configurations.each do |config|
  config.base_configuration_reference = config_ref
  settings = config.build_settings
  settings.delete('PRODUCT_NAME')
  settings['INFOPLIST_FILE'] = 'Configuration/Info.plist'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['SUPPORTS_MACCATALYST'] = 'NO'
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = config.name == 'Debug' ? '$(inherited) DEBUG' : '$(inherited)'
end
ui_tests.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.pelypets.todolist.native.uitests'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['TEST_TARGET_NAME'] = 'ToDo'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['SWIFT_VERSION'] = '6.0'
end
project.save
if package_lock
  FileUtils.mkdir_p(File.dirname(lock_path))
  File.write(lock_path, package_lock)
end

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(ui_tests)
scheme.set_launch_target(app)
scheme.save_as(project_path, 'ToDo', true)
demo = Xcodeproj::XCScheme.new
demo.add_build_target(app)
demo.set_launch_target(app)
demo.launch_action.command_line_arguments = Xcodeproj::XCScheme::CommandLineArguments.new([{ argument: '--demo', enabled: true }])
demo.save_as(project_path, 'ToDo Demo', true)
