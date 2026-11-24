platform :ios, '17.0'

 target 'PetMemorial' do
  use_frameworks!
  # Keep the same tested analytics SDK versions as iosagentclaw.
  pod 'UMCommon', '7.5.11'
  pod 'UMDevice', '3.6.0'
  target 'PetMemorialTests' do
    inherit! :search_paths
  end
  target 'PetMemorialUITests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
