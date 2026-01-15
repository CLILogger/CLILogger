#
#  Be sure to run `pod spec lint CLILogger.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|
  spec.name         = "CLILogger"
  spec.version      = `cat .version`
  spec.summary      = "Send app log to tcp bonjour service."
  spec.description  = <<-DESC
  Like NSLogger, CLILogger display and extends the custom log message in your prefer terminal.
                   DESC
  spec.homepage     = "https://github.com/CLILogger/CLILogger"
  spec.license      = { :type => "GPL", :file => "LICENSE.txt" }

  spec.author             = { "Wei Han" => "xingheng907@hotmail.com" }
  spec.social_media_url   = "https://twitter.com/xingheng907"

  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.15"
  # spec.watchos.deployment_target = "2.0"
  # spec.tvos.deployment_target = "9.0"

  spec.source       = { :git => "https://github.com/CLILogger/CLILogger.git", :tag => "#{spec.version}" }
  spec.module_name   = 'CLILogger'
  spec.swift_version = '5.0'

  spec.source_files  = "Sources/**/*.swift"

  spec.dependency "CocoaLumberjack/Swift", ">= 3.7"
  spec.dependency "CocoaAsyncSocket", ">= 7.6"

end
