#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gopro_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gopro_plugin'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin for GoPro camera control via BLE and Wi-Fi'
  s.description      = <<-DESC
A Flutter plugin that provides comprehensive control over GoPro cameras including BLE device discovery and connection, Wi-Fi hotspot management and HTTP API communication, camera controls (recording, shutter, modes), media file listing and download, and live camera preview streaming.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Aiunika' => 'contact@aiunika.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # Include NetworkExtension framework for WiFi configuration
  s.frameworks = 'NetworkExtension', 'SystemConfiguration'
end
