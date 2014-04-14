version = '2.3'

Pod::Spec.new do |s|
  s.name         = "RoundaboutKit"
  s.version      = version
  s.summary      = "A collection of asynchronous programming abstractions, utility functions, and a networking stack to assist in the creation of applications."
  s.description  = <<-DESC
                   A collection of asynchronous programming abstractions, utility functions, and a networking stack to assist in the creation of applications.
                   DESC
  s.homepage     = "https://github.com/decarbonization/RoundaboutKit"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author             = { "Kevin MacWhinnie" => "kevin@pinnaplayer.com" }
  s.social_media_url = "http://twitter.com/probablykevinm"

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'

  s.source       = { :git => "https://github.com/decarbonization/RoundaboutKit.git", :tag => version }

  s.source_files  = 'Classes', 'RoundaboutKit/*.{h,m}'
  s.prefix_header_file = "RoundaboutKit/RoundaboutKit-Prefix.pch"
  
  s.framework  = 'SystemConfiguration'
  s.ios.requires_arc = true
  s.osx.requires_arc = true
end
