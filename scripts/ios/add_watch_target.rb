# Pridá do ios/Runner.xcodeproj aplikáciu pre Apple Watch (RejnoxWatch)
# a vloží ju do appky pre iPhone. Spúšťa sa na Macu (Codemagic) pred
# zostavením; opakované spustenie nič nezmení.
#
#   gem install xcodeproj   # na Codemagicu už býva nainštalovaný
#   ruby scripts/ios/add_watch_target.rb
#
# Voliteľne: APPLE_TEAM_ID=XXXXXXXXXX (inak sa tím doplní pri podpisovaní).

require 'xcodeproj'

ROOT = File.expand_path('../..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')
TARGET_NAME = 'RejnoxWatch'
BUNDLE_ID = 'com.rejnox.rejnox.watchkitapp'
WATCHOS_VERSION = '9.0'
SOURCES = %w[RejnoxWatchApp.swift ContentView.swift WorkoutManager.swift PhoneLink.swift].freeze

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "#{TARGET_NAME} už v projekte je, nič nemením."
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' } or abort('Chýba cieľ Runner.')

watch = project.new_target(:application, TARGET_NAME, :watchos, WATCHOS_VERSION, nil, :swift)

# Súbory zo zložky ios/RejnoxWatch.
group = project.main_group.new_group(TARGET_NAME, TARGET_NAME)
watch.add_file_references(SOURCES.map { |f| group.new_reference(f) })
watch.resources_build_phase.add_file_reference(group.new_reference('Assets.xcassets'))
group.new_reference('Info.plist')
group.new_reference("#{TARGET_NAME}.entitlements")

# Verzia hodiniek sa berie z Flutteru (FLUTTER_BUILD_NAME / NUMBER).
generated = project.files.find { |f| f.path.to_s.end_with?('Generated.xcconfig') }
abort('Chýba Flutter/Generated.xcconfig v projekte.') unless generated

watch.build_configurations.each do |config|
  config.base_configuration_reference = generated
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  s['PRODUCT_NAME'] = TARGET_NAME
  s['INFOPLIST_FILE'] = "#{TARGET_NAME}/Info.plist"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{TARGET_NAME}/#{TARGET_NAME}.entitlements"
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['SDKROOT'] = 'watchos'
  s['WATCHOS_DEPLOYMENT_TARGET'] = WATCHOS_VERSION
  s['TARGETED_DEVICE_FAMILY'] = '4'
  s['SWIFT_VERSION'] = '5.0'
  s['SKIP_INSTALL'] = 'YES'
  s['ENABLE_PREVIEWS'] = 'NO'
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  s['DEVELOPMENT_TEAM'] = ENV['APPLE_TEAM_ID'] if ENV['APPLE_TEAM_ID']
end

# iPhone appka hodinky zostaví a vloží do Rejnox.app/Watch.
runner.add_dependency(watch)
embed = runner.new_copy_files_build_phase('Embed Watch Content')
embed.dst_subfolder_spec = '16' # products directory
embed.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
file = embed.add_file_reference(watch.product_reference, true)
file.settings = { 'ATTRIBUTES' => ['RemoveHeaderMapsOnCopy'] }

# Fáza musí byť pred "Thin Binary", inak Xcode hlási cyklus (známy problém Flutteru).
runner.build_phases.delete(embed)
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
runner.build_phases.insert(thin || runner.build_phases.length, embed)

project.save
puts "Pridaný #{TARGET_NAME} (#{BUNDLE_ID}) a vložený do Runner."
