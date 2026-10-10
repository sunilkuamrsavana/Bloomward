require "xcodeproj"

project_root = File.expand_path("..", __dir__)
project_path = File.join(project_root, "Daymark.xcodeproj")

abort("Daymark.xcodeproj already exists") if File.exist?(project_path)

project = Xcodeproj::Project.new(project_path, false, 60)
project.root_object.development_region = "en"
project.root_object.compatibility_version = "Xcode 15.0"
project.root_object.preferred_project_object_version = "60"
project.root_object.attributes["LastUpgradeCheck"] = "1500"
project.root_object.attributes["LastSwiftUpdateCheck"] = "1500"

target = project.new_target(:application, "Daymark", :ios, "17.0")
project.root_object.attributes["TargetAttributes"] ||= {}
project.root_object.attributes["TargetAttributes"][target.uuid] = {
  "CreatedOnToolsVersion" => "15.0"
}

target.frameworks_build_phase.files.each do |build_file|
  next unless build_file.display_name == "Foundation.framework"
  file_reference = build_file.file_ref
  build_file.remove_from_project
  file_reference.remove_from_project
end

daymark_group = project.main_group.new_group("Daymark", "Daymark")
app_group = daymark_group.new_group("App", "App")
ui_group = daymark_group.new_group("UI", "UI")
screens_group = ui_group.new_group("Screens", "Screens")
theme_group = ui_group.new_group("Theme", "Theme")
components_group = ui_group.new_group("Components", "Components")
resources_group = daymark_group.new_group("Resources", "Resources")

def add_swift_files(group, directory, target)
  Dir.glob(File.join(directory, "*.swift")).sort.each do |path|
    reference = group.new_file(File.basename(path))
    target.source_build_phase.add_file_reference(reference)
  end
end

add_swift_files(app_group, File.join(project_root, "Daymark/App"), target)
add_swift_files(screens_group, File.join(project_root, "Daymark/UI/Screens"), target)
add_swift_files(theme_group, File.join(project_root, "Daymark/UI/Theme"), target)
add_swift_files(components_group, File.join(project_root, "Daymark/UI/Components"), target)

package_reference = project.new(
  Xcodeproj::Project::Object::XCLocalSwiftPackageReference
)
package_reference.relative_path = "."
project.root_object.package_references << package_reference

package_product = project.new(
  Xcodeproj::Project::Object::XCSwiftPackageProductDependency
)
package_product.package = package_reference
package_product.product_name = "RoutineCore"
target.package_product_dependencies << package_product

package_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
package_build_file.product_ref = package_product
target.frameworks_build_phase.files << package_build_file

assets = resources_group.new_file("Assets.xcassets")
target.resources_build_phase.add_file_reference(assets)

preview_group = resources_group.new_group("Preview Content", "Preview Content")
preview_assets = preview_group.new_file("Preview Assets.xcassets")
target.resources_build_phase.add_file_reference(preview_assets)

project.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings["CLANG_ENABLE_MODULES"] = "YES"
  settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  settings["SDKROOT"] = "iphoneos"
  settings["SWIFT_VERSION"] = "5.0"
end

target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
  settings.delete("ASSETCATALOG_COMPILER_APPICON_NAME")
  settings["CODE_SIGN_STYLE"] = "Automatic"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["DEVELOPMENT_ASSET_PATHS"] = '"Daymark/Resources/Preview Content"'
  settings["ENABLE_PREVIEWS"] = "YES"
  settings["GENERATE_INFOPLIST_FILE"] = "YES"
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = "Daymark"
  settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
  settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
  settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  settings["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone"] = "UIInterfaceOrientationPortrait"
  settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  settings["MARKETING_VERSION"] = "0.1.0"
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.daymark"
  settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  settings["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
  settings["SUPPORTS_MACCATALYST"] = "NO"
  settings["SWIFT_EMIT_LOC_STRINGS"] = "YES"
  settings["SWIFT_STRICT_CONCURRENCY"] = "complete"
  settings["SWIFT_VERSION"] = "5.0"
  settings["TARGETED_DEVICE_FAMILY"] = "1,2"
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil, launch_target: true)
scheme.save_as(project_path, "Daymark", true)

puts project_path
