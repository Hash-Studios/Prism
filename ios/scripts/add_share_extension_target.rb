#!/usr/bin/env ruby
# Adds the PrismShareExtension share extension to Runner.xcodeproj. Safe to run again.
require 'xcodeproj'

PROJECT = File.expand_path('../Runner.xcodeproj', __dir__)
NAME = 'PrismShareExtension'
SHARED = 'ShareInboxShared'

project = Xcodeproj::Project.open(PROJECT)
runner = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target missing' unless runner
tests = project.targets.find { |t| t.name == 'RunnerTests' }
abort 'RunnerTests target missing' unless tests

ext = project.targets.find { |t| t.name == NAME }
unless ext
  ext = project.new_target(:app_extension, NAME, :ios, '15.0', nil, :swift)
  ext.product_reference.name = "#{NAME}.appex"
end

ios_dir = File.expand_path('..', __dir__)
ext_group = project.main_group.children.find { |g| g.display_name == NAME } || project.main_group.new_group(NAME, NAME)
xcconfig = ext_group.files.find { |f| f.path == "#{NAME}.xcconfig" } || ext_group.new_reference("#{NAME}.xcconfig")

ext.build_configurations.each do |config|
  runner_config = runner.build_configurations.find { |c| c.name == config.name }
  config.build_settings.merge!(
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CODE_SIGN_ENTITLEMENTS' => "#{NAME}/#{NAME}.entitlements",
    'CODE_SIGN_STYLE' => 'Automatic',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'DEVELOPMENT_TEAM' => runner_config.build_settings['DEVELOPMENT_TEAM'],
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'INFOPLIST_FILE' => "#{NAME}/Info.plist",
    'INFOPLIST_KEY_CFBundleDisplayName' => 'Prism',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.hash.prism.ShareExtension',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_APPROACHABLE_CONCURRENCY' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2'
  )
  # Only Flutter's version numbers, not the Pods settings that Runner's xcconfig pulls in.
  config.base_configuration_reference = xcconfig
end

def group_for(project, path)
  project.main_group.children.find { |g| g.display_name == path } ||
    project.main_group.new_group(path, path)
end

def sync_sources(group, dir, targets)
  Dir.glob(File.join(dir, '*.swift')).sort.each do |file|
    name = File.basename(file)
    ref = group.files.find { |f| f.path == name } || group.new_reference(name)
    targets.each do |target|
      next if target.source_build_phase.files_references.include?(ref)
      target.source_build_phase.add_file_reference(ref)
    end
  end
end

%w[Info.plist PrismShareExtension.entitlements].each do |name|
  ext_group.files.find { |f| f.path == name } || ext_group.new_reference(name)
end
strings = ext_group.files.find { |f| f.path == 'Localizable.xcstrings' } || ext_group.new_reference('Localizable.xcstrings')
ext.resources_build_phase.add_file_reference(strings) unless ext.resources_build_phase.files_references.include?(strings)
privacy = ext_group.files.find { |f| f.path == 'PrivacyInfo.xcprivacy' } || ext_group.new_reference('PrivacyInfo.xcprivacy')
ext.resources_build_phase.add_file_reference(privacy) unless ext.resources_build_phase.files_references.include?(privacy)
sync_sources(ext_group, File.join(ios_dir, NAME), [ext])
sync_sources(group_for(project, SHARED), File.join(ios_dir, SHARED), [runner, ext])

runner_group = project.main_group.find_subpath('Runner')
{
  runner_group => ['PrismLiveActivityHostApiImpl.swift', 'PrismSharedInboxChannel.swift'],
  runner_group.find_subpath('Pigeon') => ['PrismLiveActivityApi.swift']
}.each do |group, names|
  names.each do |name|
    ref = group.files.find { |f| f.path == name } || group.new_reference(name)
    runner.source_build_phase.add_file_reference(ref) unless runner.source_build_phase.files_references.include?(ref)
  end
end

tests_group = project.main_group.find_subpath('RunnerTests')
abort 'RunnerTests group missing' unless tests_group
test_ref = tests_group.files.find { |f| f.path == 'ShareInboxTests.swift' } || tests_group.new_reference('ShareInboxTests.swift')
tests.source_build_phase.add_file_reference(test_ref) unless tests.source_build_phase.files_references.include?(test_ref)

%w[UIKit UniformTypeIdentifiers].each do |framework|
  ref = project.frameworks_group.files.find { |f| f.path == "System/Library/Frameworks/#{framework}.framework" }
  ref ||= project.frameworks_group.new_file("System/Library/Frameworks/#{framework}.framework", :sdk_root)
  ext.frameworks_build_phase.add_file_reference(ref) unless ext.frameworks_build_phase.files_references.include?(ref)
end

runner.add_dependency(ext) unless runner.dependencies.any? { |d| d.target == ext }

embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.dst_subfolder_spec = Xcodeproj::Constants::COPY_FILES_BUILD_PHASE_DESTINATIONS[:plug_ins]
end
unless embed.files_references.include?(ext.product_reference)
  build_file = embed.add_file_reference(ext.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Flutter's Thin Binary script must run after the extension is embedded, or Xcode reports a build cycle.
phases = runner.build_phases
phases.delete(embed)
thin = phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
phases.insert(thin || phases.count, embed)

project.save
puts "#{NAME} target is in #{PROJECT}"
