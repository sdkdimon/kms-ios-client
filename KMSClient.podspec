Pod::Spec.new do |s|
  s.name             = "KMSClient"
  s.version          = "1.0.2"
  s.summary          = "Kurento Media Server iOS client."
  s.homepage         = "https://github.com/sdkdimon/kms-ios-client"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Dmitry Lizin" => "sdkdimon@gmail.com" }
  s.source           = { :git => "https://github.com/sdkdimon/kms-ios-client.git", :tag => s.version }

  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.module_name = 'KMSClient'
  s.dependency 'RACSRWebSocket', '1.1.1'
  s.dependency 'MTLJSONAdapterWithoutNil', '1.0'
  s.dependency 'Mantle', '2.0'
  s.dependency 'ReactiveCocoa', '2.5'
  s.dependency 'NSDictionaryMerge', '1.0'
  s.source_files = 'KMSClient/*.{h,m}'
  
  s.subspec 'ModelLayer' do |ss|
      ss.source_files = 'KMSClient/ModelLayer/*.{h,m}'
      ss.subspec 'Types' do |sss|
        sss.source_files = 'KMSClient/ModelLayer/Types/*.{h,m}'
      end 
  end  

  s.subspec 'MessageFactory' do |ss|
      ss.source_files = 'KMSClient/MessageFactory/*.{h,m}'
      ss.dependency 'KMSClient/ModelLayer'
      ss.dependency 'KMSClient/UUID'
  end
    
  s.subspec 'Log' do |ss|
      ss.source_files = 'KMSClient/Log/*.{h,m}'
  end

  s.subspec 'UUID' do |ss|
      ss.source_files = 'KMSClient/UUID/*.{h,m}'
  end

end



