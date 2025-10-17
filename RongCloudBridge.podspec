Pod::Spec.new do |s|
  s.name             = 'RongCloudBridge'
  s.version          = '0.1.0'
  s.summary          = 'RongCloud IM KMP Bridge'
  s.description      = 'RongCloud IM KMP Bridge'
  s.homepage         = 'https://github.com/mrljdx/RongCloudBridge'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Mrljdx' => 'mrljdx@gmail.com' }
  s.source           = { :path => '.' }
#   s.source           = { :git => 'https://github.com/mrljdx/RongCloudBridge.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'
  s.source_files = '*.{h,m}'
  s.dependency 'rongcloud-im'
end
