Pod::Spec.new do |s|
  s.name             = "KMSClient"
  s.version          = "1.2.2"
  s.summary          = "Kurento Media Server iOS client."
  s.homepage         = "https://github.com/sdkdimon/kms-ios-client"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Dmitry Lizin" => "sdkdimon@gmail.com" }
  s.source           = { :git => "https://github.com/sdkdimon/kms-ios-client.git", :tag => s.version }

  s.platform     = :ios
  s.ios.deployment_target = '12.0'
  s.requires_arc = true
  s.module_name = 'KMSClient'
  s.dependency 'WebSocketRocket', '~> 0.5'
  s.dependency 'MantleNullValuesOmit', '~> 0.0'
  s.dependency 'Mantle', '~> 2.2'
  s.dependency 'RACObjC', '~> 3.3'
  s.source_files = 'KMSClient/KMSClient/**/*.{h,m}'
end
