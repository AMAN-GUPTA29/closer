# Adds the CloserWidget WidgetKit extension to ios/Runner.xcodeproj and wires
# entitlements/App Groups. Run on macOS (e.g. Codemagic) before building:
#
#   gem install xcodeproj
#   ruby ios/scripts/add_widget_extension.rb
#
# Idempotent: running it twice does nothing the second time.
require 'xcodeproj'

PROJECT = File.expand_path('../Runner.xcodeproj', __dir__)
WIDGET_DIR = File.expand_path('../CloserWidget', __dir__)
BUNDLE_ID = 'com.closerapp.closer'
TEAM_ID = ENV['APPLE_TEAM_ID'] # optional; Codemagic signing can also set it

project = Xcodeproj::Project.open(PROJECT)
runner = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# Privacy manifest for the app (idempotent).
runner_group = project.main_group.find_subpath('Runner', false)
unless runner_group.files.any? { |f| f.path == 'PrivacyInfo.xcprivacy' }
  ref = runner_group.new_file('PrivacyInfo.xcprivacy')
  runner.add_resources([ref])
end

if project.targets.any? { |t| t.name == 'CloserWidget' }
  project.save
  puts 'CloserWidget target already exists; Runner entitlements ensured.'
  exit 0
end

widget = project.new_target(:app_extension, 'CloserWidget', :ios, '17.0')
group = project.main_group.new_group('CloserWidget', WIDGET_DIR)
swift = group.new_file(File.join(WIDGET_DIR, 'CloserWidget.swift'))
group.new_file(File.join(WIDGET_DIR, 'Info.plist'))
group.new_file(File.join(WIDGET_DIR, 'CloserWidget.entitlements'))
widget.add_resources([group.new_file(File.join(WIDGET_DIR, 'PrivacyInfo.xcprivacy'))])
widget.add_file_references([swift])
%w[WidgetKit SwiftUI AppIntents].each do |fw|
  widget.add_system_framework(fw)
end

widget.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)' # empty name => "Multiple commands produce .appex"
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BUNDLE_ID}.CloserWidget"
  s['INFOPLIST_FILE'] = 'CloserWidget/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'CloserWidget/CloserWidget.entitlements'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  s['DEVELOPMENT_TEAM'] = TEAM_ID if TEAM_ID
end

# Embed the extension in the app.
embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' } ||
        runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.dst_subfolder_spec = '13' # PlugIns
build_file = embed.add_file_reference(widget.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# Flutter's "Thin Binary" script must run after embedding, or Xcode reports a
# dependency cycle.
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
end
runner.add_dependency(widget)

project.save
puts 'CloserWidget extension added.'
