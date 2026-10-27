# Switches every app and app extension target's Release configuration to manual signing
# with the profiles that tool/ios_ci_signing.py installed. CI only; the committed project keeps automatic signing.
#
# Usage: ruby tool/ios_ci_manual_signing.rb ios/Runner.xcodeproj "$RUNNER_TEMP/provisioning-profiles.json"

require 'json'
require 'xcodeproj'

project_path, manifest_path = ARGV
abort 'usage: ios_ci_manual_signing.rb <project.xcodeproj> <manifest.json>' unless project_path && manifest_path

profiles = JSON.parse(File.read(manifest_path)).fetch('profiles').to_h { |profile| [profile['bundle_id'], profile] }
signed_types = Xcodeproj::Constants::PRODUCT_TYPE_UTI.values_at(:application, :app_extension)
project = Xcodeproj::Project.open(project_path)

missing = []
project.native_targets.select { |target| signed_types.include?(target.product_type) }.each do |target|
  config = target.build_configurations.find { |candidate| candidate.name == 'Release' }
  bundle_id = config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
  profile = profiles[bundle_id]
  next missing << "#{target.name} (#{bundle_id})" unless profile

  # "iPhone Distribution" matches both iOS Distribution and Apple Distribution certificates.
  config.build_settings.merge!(
    'CODE_SIGN_STYLE' => 'Manual',
    'DEVELOPMENT_TEAM' => profile['team_id'],
    'CODE_SIGN_IDENTITY' => 'iPhone Distribution',
    'CODE_SIGN_IDENTITY[sdk=iphoneos*]' => 'iPhone Distribution',
    'PROVISIONING_PROFILE_SPECIFIER' => profile['name'],
  )
  puts "#{target.name}: manual signing with \"#{profile['name']}\" for #{bundle_id}."
end

abort "error: no provisioning profile for #{missing.join(', ')}. Add its profile secret to testflight.yml." if missing.any?
project.save
