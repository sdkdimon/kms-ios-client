Pod::Spec.new do |s|
  s.name             = "KMSClient"
  s.version          = "1.1.5"
  s.summary          = "Kurento Media Server iOS client."
  s.homepage         = "https://github.com/sdkdimon/kms-ios-client"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Dmitry Lizin" => "sdkdimon@gmail.com" }
  s.source           = { :git => "https://github.com/sdkdimon/kms-ios-client.git", :tag => s.version }

  s.platform     = :ios
  s.ios.deployment_target = '8.0'
  s.requires_arc = true
  s.module_name = 'KMSClient'
  s.dependency 'SocketRocket', '0.5.1'
  s.dependency 'MantleNullValuesOmit'
  s.dependency 'Mantle', '~> 2.1'
  s.dependency 'ReactiveObjC', '~> 3.0'
  s.source_files = 'KMSClient/KMSClient/*.{h,m}'

  s.subspec 'ModelLayer' do |ss|
      ss.source_files = 'KMSClient/KMSClient/ModelLayer/*.{h,m}'
      ss.subspec 'Types' do |sss|
        sss.source_files = 'KMSClient/KMSClient/ModelLayer/Types/*.{h,m}'
      end
  end

  s.subspec 'MessageFactory' do |ss|
      ss.source_files = 'KMSClient/KMSClient/MessageFactory/*.{h,m}'
      ss.dependency 'KMSClient/ModelLayer'
      ss.dependency 'KMSClient/UUID'
  end

  s.subspec 'Log' do |ss|
      ss.source_files = 'KMSClient/KMSClient/Log/*.{h,m}'
  end

  s.subspec 'UUID' do |ss|
      ss.source_files = 'KMSClient/KMSClient/UUID/*.{h,m}'
  end

end
