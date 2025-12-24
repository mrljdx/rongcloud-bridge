Pod::Spec.new do |s|
  s.name             = 'RongCloudBridge'
  s.version          = '0.1.10'
  s.summary          = 'RongCloud IM KMP Bridge'
  s.description      = 'RongCloud IM KMP Bridge'
  s.homepage         = 'https://github.com/mrljdx/rongcloud-bridge'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Mrljdx' => 'mrljdx@gmail.com' }
#   s.source           = { :path => '.' }
  s.source           = { :git => 'https://github.com/mrljdx/rongcloud-bridge.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'
  s.source_files = '*.{h,m}'
  s.dependency 'RongCloudIM'
end
