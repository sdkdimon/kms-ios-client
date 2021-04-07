Pod::Spec.new do |s|
  s.name             = "KMSClient"
  s.version          = "1.2.0"
  s.summary          = "Kurento Media Server iOS client."
  s.homepage         = "https://github.com/sdkdimon/kms-ios-client"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Dmitry Lizin" => "sdkdimon@gmail.com" }
  s.source           = { :git => "https://github.com/sdkdimon/kms-ios-client.git", :tag => s.version }

  s.platform     = :ios
  s.ios.deployment_target = '9.0'
  s.requires_arc = true
  s.module_name = 'KMSClient'
  s.dependency 'WebSocketRocket', '0.5.2'
  s.dependency 'MantleNullValuesOmit', '0.0.4'
  s.dependency 'Mantle', '~> 2.1'
  s.dependency 'RACObjC/Core', '~> 3.0'
  s.source_files = 'KMSClient/KMSClient/**/*.{h,m}'
end
